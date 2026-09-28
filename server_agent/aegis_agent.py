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
import urllib.request
import urllib.error
from collections import defaultdict

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

def dispatch_alert(title, body, payload, config):
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] 🚨 ALERT: {title} - {body}")
    
    # 1. FCM Push Dispatch if configured
    if config.get("fcm_server_key"):
        try:
            url = "https://fcm.googleapis.com/fcm/send"
            headers = {
                "Authorization": f"key={config['fcm_server_key']}",
                "Content-Type": "application/json"
            }
            data = {
                "to": f"/topics/{config.get('fcm_topic', 'aegis_alerts')}",
                "priority": "high",
                "notification": {
                    "title": title,
                    "body": body,
                    "sound": "default"
                },
                "data": payload
            }
            req = urllib.request.Request(url, data=json.dumps(data).encode("utf-8"), headers=headers)
            with urllib.request.urlopen(req, timeout=5) as response:
                pass
        except Exception as e:
            print(f"[-] FCM dispatch error: {e}", file=sys.stderr)

    # 2. Webhook Dispatch if configured
    if config.get("alert_webhook"):
        try:
            req = urllib.request.Request(
                config["alert_webhook"],
                data=json.dumps({"title": title, "body": body, "payload": payload}).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=5) as response:
                pass
        except Exception as e:
            print(f"[-] Webhook error: {e}", file=sys.stderr)

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

def main():
    print("==================================================")
    print("🛡️  AEGIS Telemetry Agent Starting...")
    print("==================================================")
    config = load_config()
    print(f"[+] Loaded config for server: {config.get('server_name')} ({config.get('server_id')})")
    print(f"[+] Trusted Whitelist: {config.get('trusted_ips')}")
    print("[+] Watching services in read-only non-destructive mode...")

if __name__ == "__main__":
    main()
