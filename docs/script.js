/**
 * AEGIS - Interactive Landing Page Logic
 * Features:
 *  - Interactive VT100 SSH Terminal with commands & 4 Cyber Themes
 *  - Interactive SFTP File Manager & In-App Config Editor
 *  - Incident Forensics & Live AbuseIPDB Attack Visualizer
 *  - 17-Rule CIS Benchmark Scanner & Automated Bash Playbook Generator
 *  - Clipboard Copiers, Smooth Scrolling & Mobile Navigation
 */

document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  initCopyButtons();
  initSandboxTabs();
  initTerminal();
  initSftpExplorer();
  initCisScanner();
  initFaqAccordion();
  initTelemetryTicker();
});

/* ==========================================================================
   1. Navigation & Mobile Menu
   ========================================================================== */
function initNavigation() {
  const mobileToggle = document.getElementById('mobileToggle');
  const navMenu = document.getElementById('navMenu');

  if (mobileToggle && navMenu) {
    mobileToggle.addEventListener('click', () => {
      navMenu.classList.toggle('open');
      const isOpen = navMenu.classList.contains('open');
      mobileToggle.setAttribute('aria-expanded', isOpen);
    });

    // Close menu when a link is clicked
    navMenu.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', () => {
        navMenu.classList.remove('open');
      });
    });
  }

  // Header blur / elevation on scroll
  const header = document.querySelector('.site-header');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 40) {
      header.style.borderBottomColor = 'rgba(0, 229, 255, 0.2)';
      header.style.boxShadow = '0 10px 30px rgba(0, 0, 0, 0.5)';
    } else {
      header.style.borderBottomColor = 'rgba(34, 49, 78, 0.7)';
      header.style.boxShadow = 'none';
    }
  });
}

/* ==========================================================================
   2. Clipboard Copy Utility
   ========================================================================== */
function initCopyButtons() {
  document.querySelectorAll('[data-copy]').forEach(button => {
    button.addEventListener('click', (e) => {
      e.preventDefault();
      const textToCopy = button.getAttribute('data-copy');
      if (!textToCopy) return;

      navigator.clipboard.writeText(textToCopy).then(() => {
        const originalText = button.innerHTML;
        button.innerHTML = '✓ Copied!';
        button.style.borderColor = 'var(--emerald)';
        button.style.color = 'var(--emerald)';

        setTimeout(() => {
          button.innerHTML = originalText;
          button.style.borderColor = '';
          button.style.color = '';
        }, 2000);
      }).catch(err => {
        console.error('Clipboard copy failed:', err);
      });
    });
  });
}

/* ==========================================================================
   3. Interactive Command Center Sandbox Tabs
   ========================================================================== */
function initSandboxTabs() {
  const tabButtons = document.querySelectorAll('.tab-btn');
  const tabPanels = document.querySelectorAll('.sandbox-tab-content');

  tabButtons.forEach(button => {
    button.addEventListener('click', () => {
      const targetId = button.getAttribute('data-tab');

      tabButtons.forEach(btn => btn.classList.remove('active'));
      tabPanels.forEach(panel => panel.classList.remove('active'));

      button.classList.add('active');
      const targetPanel = document.getElementById(targetId);
      if (targetPanel) {
        targetPanel.classList.add('active');
      }
    });
  });
}

/* ==========================================================================
   4. Interactive Terminal Simulation
   ========================================================================== */
function initTerminal() {
  const termBody = document.getElementById('terminalBody');
  const termInput = document.getElementById('terminalInput');
  const quickButtons = document.querySelectorAll('.quick-cmd-btn');
  const themePills = document.querySelectorAll('.theme-pill');

  if (!termBody || !termInput) return;

  const terminalThemes = {
    oled: { text: '#00E5FF', bg: '#05070C' },
    matrix: { text: '#00FF66', bg: '#030D05' },
    monokai: { text: '#FFD866', bg: '#101010' },
    nord: { text: '#88C0D0', bg: '#0A0F18' }
  };

  themePills.forEach(pill => {
    pill.addEventListener('click', () => {
      const theme = pill.getAttribute('data-theme');
      if (terminalThemes[theme]) {
        termBody.style.color = terminalThemes[theme].text;
        termBody.closest('.terminal-window').style.backgroundColor = terminalThemes[theme].bg;
      }
    });
  });

  const commands = {
    help: () => [
      `<span class="term-prompt">Aegis VT100 Engine Available Commands:</span>`,
      `  • <span class="term-success">htop</span>                Hardware & process resource telemetry`,
      `  • <span class="term-success">aegis status</span>        Zero-Trust daemon & agent handshake status`,
      `  • <span class="term-success">fail2ban</span>            Query Fail2ban active jails and banned IPs`,
      `  • <span class="term-success">cis-audit</span>           Execute 17-point Linux CIS security audit`,
      `  • <span class="term-success">auth-log</span>            Tail real-time SSH authentication stream`,
      `  • <span class="term-success">df -h</span>               Check partition disk allocation`,
      `  • <span class="term-success">docker ps</span>           Display running isolated containers`,
      `  • <span class="term-success">clear</span>               Clear screen buffer`
    ],
    htop: () => [
      `<span class="term-success">1  [|||||||||||||||||||         42.8%]</span>   Tasks: 94, 212 thr; 1 running`,
      `<span class="term-success">2  [||||||||||||               28.4%]</span>   Load average: 0.45 0.38 0.32`,
      `<span class="term-cyan">Mem[|||||||||||||||||   3.42G/15.6G]</span>   Uptime: 48 days, 14:22:08`,
      `<span class="term-amber">Swp[|                    128M/4.00G]</span>   Zero-Trust Cryptographic Engine: ACTIVE`,
      ``,
      `<span class="term-dim">  PID USER      PRI  NI  VIRT   RES   SHR S CPU% MEM%   TIME+  COMMAND</span>`,
      ` 1402 aegis      20   0  524M  112M 42.1M S  2.4  0.7  14:02.1 /usr/bin/python3 /opt/aegis-agent/aegis_agent.py`,
      `  892 root       20   0  180M 32.4M 12.8M S  1.1  0.2  08:12.4 /usr/sbin/sshd -D [crypto: ed25519-chacha20]`,
      ` 1104 mysql      20   0 1.82G  420M 64.2M S  0.8  2.6  36:44.9 /usr/sbin/mariadbd --bind-address=127.0.0.1`,
      ` 2341 nginx      20   0  140M 24.1M  9.8M S  0.4  0.1  02:19.5 nginx: worker process (TLS 1.3 Strict)`
    ],
    'aegis status': () => [
      `<span class="term-success">● aegis-agent.service - Aegis Zero-Trust Telemetry Daemon</span>`,
      `     Loaded: loaded (/etc/systemd/system/aegis-agent.service; enabled; vendor preset: enabled)`,
      `     Active: <span class="term-success">active (running)</span> since Sun 2026-09-28 04:12:00 UTC; 9h ago`,
      `   Main PID: 1402 (aegis_agent.py)`,
      `      Tasks: 4 (limit: 4915)`,
      `     Memory: 112.4M`,
      `        CPU: 14m 2.184s`,
      `   CGroup: /system.slice/aegis-agent.service`,
      `           └─1402 /usr/bin/python3 /opt/aegis-agent/aegis_agent.py`,
      ``,
      `<span class="term-cyan">[AEGIS-CORE] Direct DartSSH2 tunnel validated.</span>`,
      `<span class="term-cyan">[AEGIS-CORE] FCM Push Dispatcher hooked to /var/log/auth.log.</span>`,
      `<span class="term-success">[AEGIS-CORE] Zero-Trust Enclave status: HEALTHY (0 egress leaks).</span>`
    ],
    fail2ban: () => [
      `Status for the jail: sshd`,
      `|- Filter`,
      `|  |- Currently failed: 3`,
      `|  |- Total failed:     284`,
      `|  \`- File list:        /var/log/auth.log`,
      `\`- Actions`,
      `   |- Currently banned: <span class="term-danger">4</span>`,
      `   |- Total banned:     112`,
      `   \`- Banned IP list:   <span class="term-danger">185.220.101.4 45.154.255.89 194.26.29.112 103.145.12.8</span>`,
      `<span class="term-success">[AEGIS] AbuseIPDB v2 scored 185.220.101.4: 100% Malicious (Tor Exit Node). Ban synced.</span>`
    ],
    'cis-audit': () => [
      `<span class="term-cyan">[+] Initiating CIS Linux Benchmark Assessment (17 Control Baseline)...</span>`,
      `[1/5] SSHD Hardening: Root Login Disabled [<span class="term-success">PASS</span>] | Password Auth Disabled [<span class="term-success">PASS</span>]`,
      `[2/5] Kernel Parameters: ASLR Enabled [<span class="term-success">PASS</span>] | TCP SYN Cookies [<span class="term-success">PASS</span>]`,
      `[3/5] Network Exposure: Telnet/FTP Closed [<span class="term-success">PASS</span>] | MySQL Loopback Only [<span class="term-success">PASS</span>]`,
      `[4/5] Identity Hardening: Zero Empty Hashes [<span class="term-success">PASS</span>] | Strict UID 0 Roots [<span class="term-success">PASS</span>]`,
      `[5/5] Filesystem Integrity: /etc/shadow 0640 [<span class="term-success">PASS</span>] | sshd_config 0600 [<span class="term-success">PASS</span>]`,
      ``,
      `<span class="term-success">>>> COMPLIANCE SCORE: 96% | RATING: A+ (CIS Benchmark Compliant)</span>`,
      `<span class="term-dim">Generated 1-Tap Playbook: /opt/aegis-agent/remediate_cis.sh</span>`
    ],
    'auth-log': () => [
      `<span class="term-dim">Sep 28 13:48:12 srv-prod sshd[18492]:</span> <span class="term-danger">Failed password for invalid user admin from 194.26.29.112 port 54228 ssh2</span>`,
      `<span class="term-dim">Sep 28 13:48:14 srv-prod sshd[18492]:</span> <span class="term-danger">Failed password for invalid user admin from 194.26.29.112 port 54228 ssh2</span>`,
      `<span class="term-dim">Sep 28 13:48:15 srv-prod fail2ban.actions[892]:</span> <span class="term-warn">NOTICE [sshd] Ban 194.26.29.112</span>`,
      `<span class="term-dim">Sep 28 13:48:15 srv-prod aegis-fcm[18501]:</span> <span class="term-cyan">Dispatched FCM critical push alert to Aegis Mobile & Linux desktop</span>`,
      `<span class="term-dim">Sep 28 13:50:01 srv-prod sshd[18600]:</span> <span class="term-success">Accepted publickey for austin from 10.8.0.2 port 48190 ssh2: ED25519 SHA256:d8K...</span>`
    ],
    'df -h': () => [
      `Filesystem      Size  Used Avail Use% Mounted on`,
      `udev            7.8G     0  7.8G   0% /dev`,
      `tmpfs           1.6G  2.4M  1.6G   1% /run`,
      `/dev/nvme0n1p2  150G   42G  101G  30% /`,
      `/dev/nvme0n1p1  512M  8.2M  504M   2% /boot/efi`,
      `/dev/sda1       1.0T  320G  680G  32% /mnt/storage-vault`
    ],
    'docker ps': () => [
      `CONTAINER ID   IMAGE                 COMMAND                  CREATED        STATUS        PORTS                                NAMES`,
      `d78a9c14ef10   redis:7-alpine        "docker-entrypoint.s…"   2 weeks ago    Up 48 hours   127.0.0.1:6379->6379/tcp             aegis-cache`,
      `91b2c4518290   prom/prometheus       "/bin/prometheus --c…"   3 weeks ago    Up 48 hours   127.0.0.1:9090->9090/tcp             aegis-prom`
    ],
    clear: () => {
      termBody.innerHTML = '';
      return [];
    }
  };

  function executeCommand(rawCmd) {
    const cmd = rawCmd.trim();
    if (!cmd) return;

    // Echo input
    const promptLine = document.createElement('div');
    promptLine.className = 'term-line';
    promptLine.innerHTML = `<span class="term-prompt">austin@srv-prod-01:~$</span> <span class="term-cmd">${escapeHtml(cmd)}</span>`;
    termBody.appendChild(promptLine);

    if (commands[cmd]) {
      const outputLines = commands[cmd]();
      outputLines.forEach(line => {
        const outDiv = document.createElement('div');
        outDiv.className = 'term-line';
        outDiv.innerHTML = line;
        termBody.appendChild(outDiv);
      });
    } else {
      const errDiv = document.createElement('div');
      errDiv.className = 'term-line term-warn';
      errDiv.textContent = `bash: command not found: ${cmd}. Type 'help' for available commands.`;
      termBody.appendChild(errDiv);
    }

    termBody.scrollTop = termBody.scrollHeight;
  }

  termInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      const val = termInput.value;
      termInput.value = '';
      executeCommand(val);
    }
  });

  quickButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const cmd = btn.getAttribute('data-cmd');
      if (cmd) {
        executeCommand(cmd);
      }
    });
  });
}

/* ==========================================================================
   5. Interactive SFTP File Explorer & Editor
   ========================================================================== */
function initSftpExplorer() {
  const fileItems = document.querySelectorAll('.sftp-file-item');
  const codeArea = document.getElementById('editorCodeArea');
  const filenameDisplay = document.getElementById('editorFilename');
  const filepathDisplay = document.getElementById('editorFilepath');
  const saveBtn = document.getElementById('saveEditorBtn');

  if (!codeArea) return;

  const mockFiles = {
    'nginx.conf': {
      path: '/etc/nginx/nginx.conf',
      content: `# Aegis Hardened Nginx Reverse Proxy Configuration
user nginx;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    # Zero-Trust TLS 1.3 Profile
    ssl_protocols TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256';

    # Rate Limiting against DoS
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

    # Security Headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    server {
        listen 443 ssl http2;
        server_name telemetry.aegis.internal;
        # ...
    }
}`
    },
    'aegis_agent.py': {
      path: '/opt/aegis-agent/aegis_agent.py',
      content: `#!/usr/bin/env python3
"""
AEGIS Zero-Trust Log Surveillance & Anomaly Detection Agent
Monitors SSH auth logs, MariaDB, and Nginx in real time.
"""
import os, sys, time, json, re

def tail_file(filepath):
    """Zero-allocation non-blocking file tailer."""
    with open(filepath, 'r') as f:
        f.seek(0, os.SEEK_END)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.1)
                continue
            yield line

def classify_event(line):
    if "Failed password" in line:
        ip = re.search(r'from (\\d+\\.\\d+\\.\\d+\\.\\d+)', line)
        return {"type": "BRUTE_FORCE_ATTEMPT", "ip": ip.group(1) if ip else "UNKNOWN"}
    return None

if __name__ == "__main__":
    print("[AEGIS-AGENT] Surveillance Daemon v1.0 started.")`
    },
    'mysqld.cnf': {
      path: '/etc/mysql/mysql.conf.d/mysqld.cnf',
      content: `[mysqld]
# Aegis Database Hardening Profile
user            = mysql
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
port            = 3306
basedir         = /usr
datadir         = /var/lib/mysql

# Strict CIS Requirement: Bind ONLY to loopback
bind-address    = 127.0.0.1

# Enforce secure authentication plugins
default_authentication_plugin = caching_sha2_password
local_infile    = 0
skip_symbolic_links = 1`
    },
    'remediate_cis.sh': {
      path: '/opt/aegis-agent/remediate_cis.sh',
      content: `#!/usr/bin/env bash
# Aegis Automated CIS Remediation Script
# Generated automatically from Aegis Security Audit
set -euo pipefail

echo "[+] Enforcing OpenSSH hardening..."
sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
chmod 0600 /etc/ssh/sshd_config

echo "[+] Enforcing Linux Kernel sysctl ASLR & SYN flood protection..."
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w kernel.randomize_va_space=2

echo "[+] Fixing file permissions on /etc/shadow..."
chmod 0640 /etc/shadow

systemctl reload sshd
echo "[SUCCESS] Server is now 100% compliant with CIS Linux Baseline."`
    }
  };

  fileItems.forEach(item => {
    item.addEventListener('click', () => {
      fileItems.forEach(i => i.classList.remove('active'));
      item.classList.add('active');

      const fname = item.getAttribute('data-filename');
      if (mockFiles[fname]) {
        filenameDisplay.textContent = fname;
        filepathDisplay.textContent = mockFiles[fname].path;
        codeArea.textContent = mockFiles[fname].content;
      }
    });
  });

  if (saveBtn) {
    saveBtn.addEventListener('click', () => {
      saveBtn.textContent = 'Saving over SFTP...';
      saveBtn.style.color = 'var(--cyan)';
      setTimeout(() => {
        saveBtn.textContent = '✓ Saved remotely';
        saveBtn.style.color = 'var(--emerald)';
        setTimeout(() => {
          saveBtn.textContent = 'Save Remote';
          saveBtn.style.color = '';
        }, 2000);
      }, 600);
    });
  }
}

/* ==========================================================================
   6. CIS Compliance Scanner Simulator
   ========================================================================== */
function initCisScanner() {
  const runBtn = document.getElementById('runCisAuditBtn');
  const gradeCircle = document.getElementById('cisGradeCircle');
  const scorePercent = document.getElementById('cisScorePercent');
  const rules = document.querySelectorAll('.cis-rule-card');

  if (!runBtn) return;

  runBtn.addEventListener('click', () => {
    runBtn.disabled = true;
    runBtn.textContent = 'Scanning 17 CIS Benchmarks...';
    gradeCircle.textContent = '...';
    scorePercent.textContent = 'Scanning...';

    // Reset status badges
    rules.forEach(rule => {
      const badge = rule.querySelector('.audit-score-badge');
      if (badge) {
        badge.className = 'audit-score-badge';
        badge.textContent = 'WAITING';
        badge.style.background = 'rgba(255, 255, 255, 0.05)';
        badge.style.color = '#94A3B8';
      }
    });

    let index = 0;
    const interval = setInterval(() => {
      if (index < rules.length) {
        const rule = rules[index];
        const badge = rule.querySelector('.audit-score-badge');
        const isPass = !rule.hasAttribute('data-fail');

        if (badge) {
          if (isPass) {
            badge.className = 'audit-score-badge badge-emerald';
            badge.textContent = 'PASS';
          } else {
            badge.className = 'audit-score-badge badge-amber';
            badge.textContent = 'WARNING';
          }
        }
        index++;
      } else {
        clearInterval(interval);
        gradeCircle.textContent = 'A+';
        scorePercent.textContent = '96% Compliance Score';
        runBtn.disabled = false;
        runBtn.textContent = '✓ Re-Run CIS Audit';
      }
    }, 180);
  });
}

/* ==========================================================================
   7. FAQ Accordion
   ========================================================================== */
function initFaqAccordion() {
  const faqItems = document.querySelectorAll('.faq-item');

  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question');
    question.addEventListener('click', () => {
      const isOpen = item.classList.contains('active');

      // Close all others
      faqItems.forEach(i => i.classList.remove('active'));

      if (!isOpen) {
        item.classList.add('active');
      }
    });
  });
}

/* ==========================================================================
   8. Live Telemetry Metric Ticker
   ========================================================================== */
function initTelemetryTicker() {
  const cpuVal = document.getElementById('dynCpuVal');
  const ramVal = document.getElementById('dynRamVal');
  const netVal = document.getElementById('dynNetVal');
  const cpuFill = document.getElementById('dynCpuFill');
  const ramFill = document.getElementById('dynRamFill');

  if (!cpuVal || !ramVal) return;

  setInterval(() => {
    // Subtle realistic random fluctuations
    const cpu = Math.floor(22 + Math.random() * 14);
    const ram = (5.8 + Math.random() * 0.5).toFixed(1);
    const net = (1.1 + Math.random() * 0.3).toFixed(2);

    cpuVal.textContent = `${cpu}%`;
    ramVal.textContent = `${ram} GB`;
    if (netVal) netVal.textContent = `${net} Gbps`;

    if (cpuFill) cpuFill.style.width = `${cpu}%`;
    if (ramFill) ramFill.style.width = `${(ram / 16) * 100}%`;
  }, 3000);
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
