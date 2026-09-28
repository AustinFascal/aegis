#!/usr/bin/env python3
"""
AEGIS Server Telemetry Agent (aegis-agent)
Automated Enterprise Guardian for Infrastructure Systems
=========================================================
Non-destructive, lightweight log watcher and anomaly telemetry daemon.
Tails mysqld, sshd, and web access logs, identifies unknown person logins
or unauthorized brute-force attempts, and dispatches real-time alerts.
"""

import os
import sys
import time
import glob
import json
import re
import signal
import base64
import tempfile
import subprocess
import urllib.request
import urllib.parse
import urllib.error
from collections import defaultdict

# Ensure real-time line buffering on stdout
try:
    sys.stdout.reconfigure(line_buffering=True)
except (AttributeError, TypeError):
    pass

CONFIG_FILE = os.environ.get("AEGIS_CONFIG", "config.json")

def load_config():
    default_cfg = {
        "server_id": "srv_rumahweb_01",
        "server_name": "RumahWeb VPS (CethoKaryo)",
        "mysql_log": "/var/log/mysqld.log",
        "ssh_log": "/var/log/secure",
        "access_logs_dir": "/home/cethokaryo/access-logs",
        "trusted_ips": ["127.0.0.1", "::1", "103.142.21.195", "182.1.200.*"],
        "max_failed_attempts": 3,
        "time_window_seconds": 120,
        "fcm_server_key": "",
        "fcm_topic": "aegis_alerts",
        "alert_webhook": ""
    }
    if not os.path.exists(CONFIG_FILE):
        return default_cfg
    try:
        with open(CONFIG_FILE, "r") as f:
            cfg = json.load(f)
            default_cfg.update(cfg)
            return default_cfg
    except Exception as e:
        print(f"[-] Config load error: {e}", file=sys.stderr)
        return default_cfg

# Regex Patterns
RE_MYSQL_DENIED = re.compile(
    r"Access denied for user '(?P<user>[^']+)'@'(?P<ip>[^']+)'(?:\s*\(using password:\s*(?P<pwd>[^\)]+)\))?",
    re.IGNORECASE
)
RE_MYSQL_CONNECT = re.compile(
    r"Connect\s+(?P<user>[^@]+)@(?P<ip>\S+)\s+(?:as\s+\S+\s+)?on\s+(?P<db>\S*)",
    re.IGNORECASE
)
RE_SSH_ACCEPTED = re.compile(
    r"sshd\[\d+\]:\s+Accepted\s+(?P<method>publickey|password)\s+for\s+(?P<user>\S+)\s+from\s+(?P<ip>\S+)\s+port\s+(?P<port>\d+)"
)
RE_SSH_FAILED = re.compile(
    r"sshd\[\d+\]:\s+Failed\s+password\s+(?:for\s+invalid\s+user\s+|for\s+)(?P<user>\S+)\s+from\s+(?P<ip>\S+)\s+port\s+(?P<port>\d+)"
)
RE_WEB_ACCESS = re.compile(
    r"(?P<ip>\S+)\s+\S+\s+(?P<user>\S+)\s+\[(?P<time>[^\]]+)\]\s+\"(?P<method>\S+)\s+(?P<uri>\S+)\s+[^\"]+\"\s+(?P<status>\d{3})\s+(?P<bytes>\S+)"
)

failed_tracker = defaultdict(list)

def is_ip_trusted(ip, trusted_list):
    if ip in trusted_list:
        return True
    for pattern in trusted_list:
        if pattern.endswith(".*") and ip.startswith(pattern[:-2]):
            return True
    return False

_cached_fcm_token = {"token": None, "expires_at": 0, "project_id": None}

def get_fcm_v1_token(service_account_path):
    """Generates an OAuth2 access token for Google FCM v1 using Service Account JSON."""
    now = int(time.time())
    if _cached_fcm_token["token"] and _cached_fcm_token["expires_at"] > now + 60:
        return _cached_fcm_token["token"], _cached_fcm_token["project_id"]

    if not os.path.exists(service_account_path):
        return None, None

    try:
        with open(service_account_path, "r") as f:
            sa = json.load(f)

        project_id = sa.get("project_id")
        client_email = sa.get("client_email")
        private_key = sa.get("private_key")

        if not (project_id and client_email and private_key):
            return None, None

        header = {"alg": "RS256", "typ": "JWT"}
        claims = {
            "iss": client_email,
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": "https://oauth2.googleapis.com/token",
            "exp": now + 3600,
            "iat": now
        }

        def b64url(data):
            return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")

        signing_input = b64url(json.dumps(header).encode("utf-8")) + "." + b64url(json.dumps(claims).encode("utf-8"))

        with tempfile.NamedTemporaryFile("w", delete=False) as key_file:
            key_file.write(private_key)
            key_file_path = key_file.name

        try:
            proc = subprocess.Popen(
                ["openssl", "dgst", "-sha256", "-sign", key_file_path],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            signature, err = proc.communicate(input=signing_input.encode("utf-8"))
            if proc.returncode != 0:
                print(f"[-] OpenSSL signing failed: {err.decode('utf-8', errors='replace')}", file=sys.stderr, flush=True)
                return None, None
            jwt = signing_input + "." + b64url(signature)
        finally:
            if os.path.exists(key_file_path):
                os.remove(key_file_path)

        token_data = urllib.parse.urlencode({
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": jwt
        }).encode("utf-8")

        req = urllib.request.Request(
            "https://oauth2.googleapis.com/token",
            data=token_data,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            res = json.loads(resp.read().decode("utf-8"))
            token = res.get("access_token")
            expires_in = res.get("expires_in", 3600)
            _cached_fcm_token["token"] = token
            _cached_fcm_token["expires_at"] = now + expires_in
            _cached_fcm_token["project_id"] = project_id
            return token, project_id
    except Exception as e:
        print(f"[-] Failed to obtain FCM v1 token: {e}", file=sys.stderr, flush=True)
        return None, None

_alert_cooldown = {}

def dispatch_alert(title, body, payload, config):
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] 🚨 ALERT: {title} - {body}", flush=True)
    
    # Cooldown: avoid flooding network HTTP dispatches if a bot attacks 30 times in 1 second
    ip = payload.get("ip", "")
    service = payload.get("service", "")
    cooldown_key = f"{service}:{ip}"
    now = time.time()
    if cooldown_key in _alert_cooldown and (now - _alert_cooldown[cooldown_key] < 10):
        return
    _alert_cooldown[cooldown_key] = now

    # 1. FCM v1 Modern HTTP API Dispatch
    sa_file = config.get("service_account_file") or ("service_account.json" if os.path.exists("service_account.json") else None)
    if sa_file and os.path.exists(sa_file):
        try:
            token, proj_id = get_fcm_v1_token(sa_file)
            if token and proj_id:
                topic = config.get("fcm_topic", "aegis_alerts")
                fcm_url = f"https://fcm.googleapis.com/v1/projects/{proj_id}/messages:send"
                headers = {
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json; UTF-8"
                }
                msg_body = {
                    "message": {
                        "topic": topic,
                        "notification": {
                            "title": title,
                            "body": body
                        },
                        "data": {
                            "title": str(title),
                            "body": str(body),
                            "ip": str(payload.get("ip", "")),
                            "service": str(payload.get("service", "")),
                            "severity": str(payload.get("severity", "high")),
                            "server_id": str(config.get("server_id", "srv_rumahweb_01")),
                            "user": str(payload.get("user", "")),
                            "raw_log": str(body),
                            "timestamp": str(int(time.time()))
                        }
                    }
                }
                req = urllib.request.Request(fcm_url, data=json.dumps(msg_body).encode("utf-8"), headers=headers)
                with urllib.request.urlopen(req, timeout=3):
                    pass
        except Exception as e:
            print(f"[-] FCM v1 dispatch error: {e}", file=sys.stderr, flush=True)

    # 2. Webhook Dispatch (Discord, Slack, or generic webhook)
    webhook_url = config.get("alert_webhook")
    if webhook_url:
        try:
            if "discord.com" in webhook_url:
                wh_data = {
                    "content": f"🚨 **{title}**\n{body}\n`IP: {payload.get('ip', 'N/A')} | Service: {payload.get('service', 'N/A')}`"
                }
            elif "slack.com" in webhook_url:
                wh_data = {
                    "text": f"🚨 *{title}*\n{body}\n`IP: {payload.get('ip', 'N/A')}`"
                }
            else:
                wh_data = {"title": title, "body": body, "payload": payload}

            req = urllib.request.Request(
                webhook_url,
                data=json.dumps(wh_data).encode("utf-8"),
                headers={"Content-Type": "application/json", "User-Agent": "AEGIS-Agent/1.0"}
            )
            with urllib.request.urlopen(req, timeout=5):
                pass
        except Exception as e:
            print(f"[-] Webhook error: {e}", file=sys.stderr, flush=True)

    # 3. Telegram Bot Dispatch
    tg_token = config.get("telegram_bot_token")
    tg_chat_id = config.get("telegram_chat_id")
    if tg_token and tg_chat_id:
        try:
            tg_text = f"🛡️ *AEGIS ALERT*\n\n*{title}*\n{body}\n\n📍 *IP:* `{payload.get('ip', 'N/A')}`\n🔧 *Service:* `{payload.get('service', 'N/A')}`"
            tg_url = f"https://api.telegram.org/bot{tg_token}/sendMessage"
            tg_post = urllib.parse.urlencode({
                "chat_id": tg_chat_id,
                "text": tg_text,
                "parse_mode": "Markdown"
            }).encode("utf-8")
            req = urllib.request.Request(tg_url, data=tg_post)
            with urllib.request.urlopen(req, timeout=5):
                pass
        except Exception as e:
            print(f"[-] Telegram dispatch error: {e}", file=sys.stderr, flush=True)

def process_line(service, line, config):
    now = time.time()
    trusted = config.get("trusted_ips", [])
    window = config.get("time_window_seconds", 120)
    threshold = config.get("max_failed_attempts", 3)

    if service == "mysqld":
        m_denied = RE_MYSQL_DENIED.search(line)
        if m_denied:
            user = m_denied.group("user")
            ip = m_denied.group("ip")
            failed_tracker[ip].append(now)
            failed_tracker[ip] = [t for t in failed_tracker[ip] if now - t <= window]
            count = len(failed_tracker[ip])

            if count >= threshold:
                dispatch_alert(
                    "⚠️ BRUTE FORCE ATTACK on MySQL",
                    f"IP {ip} has failed {count} times targeting '{user}'!",
                    {"service": "mysqld", "ip": ip, "user": user, "severity": "critical"},
                    config
                )
            elif user in ("root", "admin"):
                dispatch_alert(
                    "🚨 CRITICAL: MySQL Root Probe",
                    f"Unauthorized access denied for '{user}' from IP {ip}",
                    {"service": "mysqld", "ip": ip, "user": user, "severity": "critical"},
                    config
                )

        m_conn = RE_MYSQL_CONNECT.search(line)
        if m_conn:
            user = m_conn.group("user")
            ip = m_conn.group("ip")
            if not is_ip_trusted(ip, trusted):
                dispatch_alert(
                    "🚨 UNKNOWN PERSON LOGIN (MySQL)",
                    f"User '{user}' connected to MySQL from untrusted IP {ip}!",
                    {"service": "mysqld", "ip": ip, "user": user, "severity": "critical"},
                    config
                )

    elif service == "sshd":
        m_failed = RE_SSH_FAILED.search(line)
        if m_failed:
            user = m_failed.group("user")
            ip = m_failed.group("ip")
            failed_tracker[ip].append(now)
            failed_tracker[ip] = [t for t in failed_tracker[ip] if now - t <= window]
            count = len(failed_tracker[ip])

            if count >= threshold:
                dispatch_alert(
                    "⚠️ BRUTE FORCE SSH ATTACK",
                    f"IP {ip} failed {count} SSH logins targeting '{user}'!",
                    {"service": "sshd", "ip": ip, "user": user, "severity": "critical"},
                    config
                )

        m_ok = RE_SSH_ACCEPTED.search(line)
        if m_ok:
            user = m_ok.group("user")
            ip = m_ok.group("ip")
            if not is_ip_trusted(ip, trusted):
                dispatch_alert(
                    "🚨 UNKNOWN PERSON LOGIN (SSH)",
                    f"User '{user}' logged in via SSH from untrusted IP {ip}!",
                    {"service": "sshd", "ip": ip, "user": user, "severity": "critical"},
                    config
                )

    elif service == "web":
        m_web = RE_WEB_ACCESS.search(line)
        if m_web:
            ip = m_web.group("ip")
            status = int(m_web.group("status"))
            uri = m_web.group("uri").lower()

            # Detect malicious probes (e.g. phpmyadmin, env files, wp-login brute force)
            if any(p in uri for p in [".env", "wp-login.php", "phpmyadmin", "shell.php"]):
                dispatch_alert(
                    "🚨 MALICIOUS WEB PROBE",
                    f"IP {ip} scanned sensitive URI: {uri} (HTTP {status})",
                    {"service": "web", "ip": ip, "uri": uri, "severity": "warning"},
                    config
                )

running = True

def handle_signal(sig, frame):
    global running
    print(f"\n[+] Stopping AEGIS Telemetry Agent gracefully (signal {sig})...", flush=True)
    running = False
    sys.exit(0)

signal.signal(signal.SIGINT, handle_signal)
signal.signal(signal.SIGTERM, handle_signal)

class FileTailer:
    """Tails a log file or directory of log files with rotation & truncation detection."""
    def __init__(self, filepath, service, is_glob=False):
        self.filepath = filepath
        self.service = service
        self.is_glob = is_glob
        self.file_handles = {}  # path -> {"file": obj, "inode": inode}

    def open_file(self, path, seek_to_end=True):
        try:
            f = open(path, "r", encoding="utf-8", errors="replace")
            # Seek to end on initial startup to only process newly appended lines;
            # on rotation, read from start so no lines are missed.
            if seek_to_end:
                f.seek(0, os.SEEK_END)
            else:
                f.seek(0, os.SEEK_SET)
            inode = os.fstat(f.fileno()).st_ino
            self.file_handles[path] = {"file": f, "inode": inode}
            print(f"[+] Watching {self.service} log: {path}", flush=True)
        except Exception as e:
            print(f"[-] Cannot open {path} for {self.service}: {e}", file=sys.stderr, flush=True)

    def get_target_files(self):
        if self.is_glob:
            if os.path.isdir(self.filepath):
                return glob.glob(os.path.join(self.filepath, "*"))
            return glob.glob(self.filepath)
        elif os.path.exists(self.filepath):
            return [self.filepath]
        return []

    def check_rotation(self, path):
        if path not in self.file_handles:
            return
        entry = self.file_handles[path]
        try:
            current_stat = os.stat(path)
            # Inode changed (file rotated via move/create)
            if current_stat.st_ino != entry["inode"]:
                entry["file"].close()
                del self.file_handles[path]
                self.open_file(path, seek_to_end=False)
            # File truncated (logrotate copytruncate)
            elif current_stat.st_size < entry["file"].tell():
                entry["file"].seek(0, os.SEEK_SET)
        except OSError:
            try:
                entry["file"].close()
            except Exception:
                pass
            if path in self.file_handles:
                del self.file_handles[path]

    def read_lines(self):
        lines = []
        targets = self.get_target_files()

        # Check newly appeared files
        for target in targets:
            if target not in self.file_handles and os.path.isfile(target):
                self.open_file(target, seek_to_end=True)

        # Read available lines from open handles
        for path in list(self.file_handles.keys()):
            self.check_rotation(path)
            if path not in self.file_handles:
                continue
            f = self.file_handles[path]["file"]
            while True:
                line = f.readline()
                if not line:
                    break
                line = line.rstrip("\r\n")
                if line.strip():
                    lines.append((self.service, line))
        return lines

    def close(self):
        for entry in self.file_handles.values():
            try:
                entry["file"].close()
            except Exception:
                pass
        self.file_handles.clear()

def main():
    print("==================================================", flush=True)
    print("🛡️  AEGIS Telemetry Agent Starting...", flush=True)
    print("==================================================", flush=True)
    config = load_config()
    print(f"[+] Loaded config for server: {config.get('server_name')} ({config.get('server_id')})", flush=True)
    print(f"[+] Trusted Whitelist: {config.get('trusted_ips')}", flush=True)
    print("[+] Watching services in read-only non-destructive mode...", flush=True)

    watchers = []
    if config.get("ssh_log"):
        watchers.append(FileTailer(config["ssh_log"], "sshd"))
    if config.get("mysql_log"):
        watchers.append(FileTailer(config["mysql_log"], "mysqld"))
    if config.get("access_logs_dir"):
        watchers.append(FileTailer(config["access_logs_dir"], "web", is_glob=True))

    for w in watchers:
        for target in w.get_target_files():
            if os.path.isfile(target):
                w.open_file(target)

    print("[+] AEGIS Telemetry Agent is active and monitoring in background.", flush=True)

    while running:
        had_activity = False
        for w in watchers:
            new_lines = w.read_lines()
            if new_lines:
                had_activity = True
                for service, line in new_lines:
                    try:
                        process_line(service, line, config)
                    except Exception as err:
                        print(f"[-] Error processing line: {err}", file=sys.stderr, flush=True)
        if not had_activity:
            time.sleep(0.5)

    for w in watchers:
        w.close()
    print("[+] AEGIS Telemetry Agent stopped.", flush=True)

if __name__ == "__main__":
    main()
