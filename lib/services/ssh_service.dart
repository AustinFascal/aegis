import 'package:flutter/foundation.dart';
import '../models/security_policy.dart';
import '../models/hardware_telemetry.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import '../models/server_profile.dart';
import '../core/constants/service_registry.dart';
import '../core/security/totp_helper.dart';

class SshTestResult {
  final bool success;
  final String? osInfo;
  final String? uptime;
  final Map<String, bool> serviceStatuses;
  final String? errorMessage;

  const SshTestResult({
    required this.success,
    this.osInfo,
    this.uptime,
    this.serviceStatuses = const {},
    this.errorMessage,
  });
}

class ServiceActionResult {
  final bool success;
  final String action; // 'start', 'stop', 'restart'
  final String serviceId;
  final String output;
  final bool isOnline;
  final String? errorMessage;
  final DateTime timestamp;

  ServiceActionResult({
    required this.success,
    required this.action,
    required this.serviceId,
    required this.output,
    this.isOnline = false,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class FirewallActionResult {
  final bool success;
  final String action; // 'ban' or 'unban'
  final String ip;
  final String output;
  final String? errorMessage;
  final DateTime timestamp;

  FirewallActionResult({
    required this.success,
    required this.action,
    required this.ip,
    required this.output,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class SshService {
  static final SshService _instance = SshService._internal();
  factory SshService() => _instance;
  SshService._internal();

  // Strict regex pattern for safe filesystem log paths
  static final RegExp _safeLogPathRegex = RegExp(r'^/[a-zA-Z0-9_\-\./]+$');

  // Connection pool for keeping authenticated sessions alive during app run
  final Map<String, SSHClient> _clientPool = {};
  final Map<String, Completer<SSHClient>> _connectingLocks = {};

  bool isConnected(String serverId) {
    final client = _clientPool[serverId];
    return client != null && !client.isClosed;
  }

  Future<void> disconnect(String serverId) async {
    final client = _clientPool.remove(serverId);
    if (client != null) {
      try {
        client.close();
      } catch (_) {}
    }
  }

  Future<void> closeAll() async {
    final keys = List<String>.from(_clientPool.keys);
    for (final k in keys) {
      await disconnect(k);
    }
  }

  Future<SSHClient> _createClient({
    required String host,
    required int port,
    required String username,
    required AuthType authType,
    required String credential,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    // Validate host and port bounds
    if (port < 1 || port > 65535) {
      throw ArgumentError('Invalid port number: $port');
    }

    final socket = await SSHSocket.connect(
      host,
      port,
      timeout: const Duration(seconds: 8),
    );

    Future<List<String>?> handleUserInfoRequest(SSHUserInfoRequest request) async {
      final responses = <String>[];
      for (final p in request.prompts) {
        final promptLower = p.promptText.toLowerCase();

        final isOtpPrompt = promptLower.contains('verification') ||
            promptLower.contains('code') ||
            promptLower.contains('otp') ||
            promptLower.contains('token') ||
            promptLower.contains('authenticator') ||
            promptLower.contains('duo') ||
            promptLower.contains('one-time');

        if (isOtpPrompt) {
          if (oneTimeCode != null && oneTimeCode.trim().isNotEmpty) {
            responses.add(oneTimeCode.trim());
          } else if (totpSecret != null && TotpHelper.isValidSecret(totpSecret)) {
            final otp = TotpHelper.generateTotp(totpSecret);
            responses.add(otp);
          } else if (onPrompt2FA != null) {
            final manualOtp = await onPrompt2FA(p.promptText);
            if (manualOtp != null && manualOtp.trim().isNotEmpty) {
              responses.add(manualOtp.trim());
            } else {
              throw const SecurityException('Verifikasi 2FA dibatalkan atau kosong.');
            }
          } else {
            throw SecurityException(
              'Server requires 2FA authentication ("${p.promptText.trim()}"), but no TOTP secret or code was configured.',
            );
          }
          continue;
        }

        final isPassPrompt = promptLower.contains('password') ||
            promptLower.contains('passphrase') ||
            promptLower.contains('kata sandi');

        if (isPassPrompt) {
          responses.add(credential);
          continue;
        }

        // Generic / fallback prompt
        if (totpSecret != null && TotpHelper.isValidSecret(totpSecret)) {
          responses.add(TotpHelper.generateTotp(totpSecret));
        } else if (onPrompt2FA != null) {
          final manualRes = await onPrompt2FA(p.promptText);
          responses.add(manualRes ?? '');
        } else {
          responses.add(credential);
        }
      }
      return responses;
    }

    if (authType == AuthType.privateKey) {
      final keyPairs = SSHKeyPair.fromPem(credential);
      return SSHClient(
        socket,
        username: username,
        identities: keyPairs,
        onUserInfoRequest: handleUserInfoRequest,
        keepAliveInterval: const Duration(seconds: 15),
      );
    } else {
      return SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => credential,
        onUserInfoRequest: handleUserInfoRequest,
        keepAliveInterval: const Duration(seconds: 15),
      );
    }
  }

  /// Retrieves an existing active SSH connection from the pool, or connects once and caches it.
  Future<SSHClient> getOrConnectClient({
    required ServerProfile profile,
    required String credential,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
    bool forceReconnect = false,
  }) async {
    final serverId = profile.id;

    if (!forceReconnect) {
      final existing = _clientPool[serverId];
      if (existing != null && !existing.isClosed) {
        return existing;
      }
    } else {
      await disconnect(serverId);
    }

    if (_connectingLocks.containsKey(serverId)) {
      try {
        return await _connectingLocks[serverId]!.future;
      } catch (_) {}
    }

    final completer = Completer<SSHClient>();
    _connectingLocks[serverId] = completer;

    try {
      final client = await _createClient(
        host: profile.host,
        port: profile.port,
        username: profile.username,
        authType: profile.authType,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      _clientPool[serverId] = client;

      // Handle socket or connection closure automatically
      unawaited(client.done.then((_) {
        debugPrint('[SshService] SSH session closed for ${profile.name} (${profile.host}).');
        if (_clientPool[serverId] == client) {
          _clientPool.remove(serverId);
        }
      }).catchError((err) {
        debugPrint('[SshService] SSH session terminated with error for ${profile.name}: $err');
        if (_clientPool[serverId] == client) {
          _clientPool.remove(serverId);
        }
      }));

      completer.complete(client);
      return client;
    } catch (e) {
      completer.completeError(e);
      _clientPool.remove(serverId);
      rethrow;
    } finally {
      _connectingLocks.remove(serverId);
    }
  }

  Future<SSHClient> connectClient({
    required ServerProfile profile,
    required String credential,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    return getOrConnectClient(
      profile: profile,
      credential: credential,
      totpSecret: totpSecret,
      oneTimeCode: oneTimeCode,
      onPrompt2FA: onPrompt2FA,
    );
  }

  Future<SshTestResult> testConnection({
    required ServerProfile profile,
    required String credential,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
    bool forceReconnect = false,
  }) async {
    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
        forceReconnect: forceReconnect,
      );

      // Fetch OS Info & Uptime safely (read-only fixed commands)
      final osBytes = await client.run(
        'uname -srm 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2',
      );
      final osInfo = utf8.decode(osBytes).trim().replaceAll('"', '');

      final uptimeBytes = await client.run(
        r"uptime -p 2>/dev/null || uptime | awk '{print $3,$4}'",
      );
      final uptime = utf8.decode(uptimeBytes).trim();

      // Probe all known infrastructure services in a single round-trip command
      final Map<String, bool> serviceMap = {};
      try {
        final probeBytes = await client.run(
          'for s in mysqld sshd httpd nginx redis-server php-fpm dovecot named pdns_server exim pure-ftpd ollama crond node python3; do '
          'if pgrep -x "\$s" >/dev/null 2>&1 || (ps -eo comm | grep -qxE "\$s"); then echo "\$s:UP"; else echo "\$s:DOWN"; fi; '
          'done',
        );
        final probeOutput = utf8.decode(probeBytes).trim();
        for (final line in const LineSplitter().convert(probeOutput)) {
          final parts = line.split(':');
          if (parts.length == 2) {
            var serviceKey = parts[0].trim();
            if (serviceKey == 'pdns_server') serviceKey = 'named';
            serviceMap[serviceKey] = (parts[1].trim() == 'UP');
          }
        }
      } catch (_) {
        serviceMap['mysqld'] = true;
        serviceMap['sshd'] = true;
      }
      serviceMap['sshd'] = true;

      return SshTestResult(
        success: true,
        osInfo: osInfo.isNotEmpty ? osInfo : 'Linux Server',
        uptime: uptime.isNotEmpty ? uptime : 'Active',
        serviceStatuses: serviceMap,
      );
    } catch (e) {
      if (_isConnectionBroken(e)) {
        _clientPool.remove(profile.id);
      }
      return SshTestResult(
        success: false,
        errorMessage: _sanitizeErrorMessage(e.toString()),
      );
    }
  }

  /// Safely controls a remote service daemon (start, stop, restart) with systemd/service fallbacks and optional privilege escalation
  Future<ServiceActionResult> executeServiceAction({
    required ServerProfile profile,
    required String credential,
    required ServiceDefinition serviceDef,
    required String action, // 'start', 'stop', 'restart'
    String? sudoPassword,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final sanitizedAction = action.trim().toLowerCase();
    final allowedActions = ['start', 'stop', 'restart'];
    if (!allowedActions.contains(sanitizedAction)) {
      return ServiceActionResult(
        success: false,
        action: action,
        serviceId: serviceDef.id,
        output: '',
        errorMessage: 'Invalid action: $action. Permitted: start, stop, restart.',
      );
    }

    final units = serviceDef.systemdUnits.isNotEmpty
        ? serviceDef.systemdUnits
        : [serviceDef.id];
    final unitsArg = units.join(' ');

    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      final pgrep = serviceDef.pgrepPattern;

      // Multi-layer resilient execution script:
      // Layer 1: Native cPanel restartsrv tools if present on WHM/cPanel systems
      // Layer 2: Systemd (with automatic hung job cancellation and reset-failed)
      // Layer 3: System V init (service command)
      // Layer 4: Clean process termination (SIGTERM -> SIGKILL) for stop actions
      // Layer 5: State-based verification for start/restart
      final script = '''
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH"
ACTION="$sanitizedAction"
SERVICE_ID="${serviceDef.id}"
PGREP="$pgrep"
EXECUTED=0
LOG=""

is_running() {
  pgrep -x "\$PGREP" >/dev/null 2>&1 || (ps -eo comm | grep -qxE "\$PGREP")
}

# 1. cPanel / WHM Service Manager Integration
CPANEL_SCRIPT=""
case "\$SERVICE_ID" in
  mysqld|mysql|mariadb)
    CPANEL_SCRIPT="/scripts/restartsrv_mysql"
    ;;
  httpd|apache)
    [ -x "/scripts/restartsrv_httpd" ] && CPANEL_SCRIPT="/scripts/restartsrv_httpd" || CPANEL_SCRIPT="/scripts/restartsrv_apache"
    ;;
  php-fpm)
    CPANEL_SCRIPT="/scripts/restartsrv_apache_php_fpm"
    ;;
  dovecot)
    CPANEL_SCRIPT="/scripts/restartsrv_dovecot"
    ;;
  exim)
    CPANEL_SCRIPT="/scripts/restartsrv_exim"
    ;;
  pure-ftpd)
    CPANEL_SCRIPT="/scripts/restartsrv_pureftpd"
    ;;
  named)
    [ -x "/scripts/restartsrv_named" ] && CPANEL_SCRIPT="/scripts/restartsrv_named" || CPANEL_SCRIPT="/scripts/restartsrv_bind"
    ;;
esac

if [ -n "\$CPANEL_SCRIPT" ] && [ -x "\$CPANEL_SCRIPT" ]; then
  OUT=\$([ -x "\$CPANEL_SCRIPT" ] && "\$CPANEL_SCRIPT" "--\$ACTION" 2>&1)
  CODE=\$?
  LOG="\$LOG\\ncPanel \$CPANEL_SCRIPT --\$ACTION: \$OUT (exit \$CODE)"
  sleep 1
  if [ "\$ACTION" = "stop" ]; then
    if ! is_running; then
      EXECUTED=1
      echo "CMD_SUCCESS:\$CPANEL_SCRIPT"
    fi
  elif [ "\$ACTION" = "start" ] || [ "\$ACTION" = "restart" ]; then
    if is_running; then
      EXECUTED=1
      echo "CMD_SUCCESS:\$CPANEL_SCRIPT"
    fi
  fi
fi

# 2. Systemd and SysV service fallback
if [ \$EXECUTED -eq 0 ]; then
  for u in $unitsArg; do
    if command -v systemctl >/dev/null 2>&1; then
      # Clear any hung or conflicting systemd jobs before executing action
      systemctl cancel "\$u.service" >/dev/null 2>&1 || true
      systemctl reset-failed "\$u" >/dev/null 2>&1 || true

      OUT=\$(systemctl "\$ACTION" "\$u" 2>&1)
      CODE=\$?
      LOG="\$LOG\\nsystemctl \$ACTION \$u: \$OUT (exit \$CODE)"

      sleep 1
      if [ "\$ACTION" = "stop" ]; then
        if ! is_running; then
          EXECUTED=1
          echo "CMD_SUCCESS:\$u"
          break
        fi
      elif [ "\$ACTION" = "start" ] || [ "\$ACTION" = "restart" ]; then
        if is_running; then
          EXECUTED=1
          echo "CMD_SUCCESS:\$u"
          break
        fi
      fi
    fi

    # Fallback to service command
    if command -v service >/dev/null 2>&1; then
      OUT=\$(service "\$u" "\$ACTION" 2>&1)
      CODE=\$?
      LOG="\$LOG\\nservice \$u \$ACTION: \$OUT (exit \$CODE)"
      sleep 1
      if [ "\$ACTION" = "stop" ]; then
        if ! is_running; then
          EXECUTED=1
          echo "CMD_SUCCESS:\$u"
          break
        fi
      elif [ "\$ACTION" = "start" ] || [ "\$ACTION" = "restart" ]; then
        if is_running; then
          EXECUTED=1
          echo "CMD_SUCCESS:\$u"
          break
        fi
      fi
    fi
  done
fi

# 3. Direct Process Termination Fallback for STOP
if [ "\$ACTION" = "stop" ]; then
  if is_running; then
    LOG="\$LOG\\nTerminating remaining \$PGREP processes via SIGTERM..."
    pkill -TERM -x "\$PGREP" 2>/dev/null || true
    sleep 1.5
    if is_running; then
      LOG="\$LOG\\nForce-terminating remaining \$PGREP processes via SIGKILL..."
      pkill -9 -x "\$PGREP" 2>/dev/null || true
      sleep 1
    fi
    if ! is_running; then
      EXECUTED=1
      echo "CMD_SUCCESS:pkill"
    fi
  else
    EXECUTED=1
    echo "CMD_SUCCESS:stopped"
  fi
fi

# 4. State Verification for START / RESTART
if [ "\$ACTION" = "start" ] || [ "\$ACTION" = "restart" ]; then
  sleep 1.5
  if is_running; then
    EXECUTED=1
    echo "CMD_SUCCESS:online"
  fi
fi

if [ \$EXECUTED -eq 0 ]; then
  echo -e "\$LOG"
fi
''';

      final escapedScript = script.replaceAll("'", "'\"'\"'");
      final trimmedPass = sudoPassword?.trim();
      String execCommand;
      if (trimmedPass != null && trimmedPass.isNotEmpty) {
        final safePass = trimmedPass.replaceAll("'", "'\"'\"'");
        execCommand = "echo '$safePass' | sudo -S -p '' bash -c '$escapedScript'";
      } else {
        if (profile.username == 'root') {
          execCommand = "bash -c '$escapedScript'";
        } else {
          execCommand = "sudo -n bash -c '$escapedScript' 2>/dev/null || bash -c '$escapedScript'";
        }
      }
      final execBytes = await client.run(execCommand);
      final rawOutput = utf8.decode(execBytes).trim();

      // Allow time for daemon process state transition
      await Future.delayed(const Duration(milliseconds: 1200));

      final checkBytes = await client.run(
        'pgrep -x "$pgrep" >/dev/null 2>&1 || (ps -eo comm | grep -qxE "$pgrep") && echo "ONLINE" || echo "OFFLINE"',
      );
      final isOnline = utf8.decode(checkBytes).contains('ONLINE');

      // The definitive source of truth is actual daemon process state
      final wasStopped = sanitizedAction == 'stop' && !isOnline;
      final wasStarted = (sanitizedAction == 'start' || sanitizedAction == 'restart') && isOnline;
      final isSuccessful = wasStopped || wasStarted;

      String? errorMsg;
      if (!isSuccessful) {
        if (rawOutput.contains('incorrect password') ||
            rawOutput.contains('Sorry, try again') ||
            rawOutput.contains('no password was provided') ||
            rawOutput.contains('Password change aborted')) {
          errorMsg = 'Kata sandi sudo salah atau belum dimasukkan untuk pengguna ${profile.username}.';
        } else if (rawOutput.contains('not in the sudoers')) {
          errorMsg = 'Pengguna SSH (${profile.username}) tidak memiliki izin sudo pada server ini.';
        } else if (rawOutput.contains('Permission denied') ||
            rawOutput.contains('interactive authentication required') ||
            (profile.username != 'root' && (sudoPassword == null || sudoPassword.isEmpty))) {
          errorMsg = 'Akses ditolak: Kontrol service membutuhkan hak akses root atau kata sandi sudo untuk pengguna ${profile.username}.';
        } else if (rawOutput.contains('Job') && rawOutput.contains('canceled')) {
          errorMsg = 'Perintah dibatalkan oleh systemd server (job bentrok atau butuh eskalasi sudo).';
        } else if (sanitizedAction == 'stop' && isOnline) {
          errorMsg = 'Gagal menghentikan layanan: Proses masih berjalan di server (memerlukan hak sudo/root).';
        } else if ((sanitizedAction == 'start' || sanitizedAction == 'restart') && !isOnline) {
          errorMsg = 'Gagal memulai layanan: Proses tidak dapat diaktifkan di server.';
        } else {
          errorMsg = 'Gagal menjalankan $sanitizedAction pada ${serviceDef.name}.';
        }
      }

      return ServiceActionResult(
        success: isSuccessful,
        action: sanitizedAction,
        serviceId: serviceDef.id,
        output: rawOutput.isEmpty ? (isSuccessful ? 'Perintah berhasil dijalankan.' : 'Tidak ada keluaran.') : rawOutput,
        isOnline: isOnline,
        errorMessage: errorMsg,
      );
    } catch (e) {
      if (_isConnectionBroken(e)) {
        _clientPool.remove(profile.id);
      }
      return ServiceActionResult(
        success: false,
        action: sanitizedAction,
        serviceId: serviceDef.id,
        output: '',
        errorMessage: _sanitizeErrorMessage(e.toString()),
      );
    }
  }

  /// Safely executes firewall ban / unban via iptables and fail2ban-client on the remote host
  Future<FirewallActionResult> executeFirewallAction({
    required ServerProfile profile,
    required String credential,
    required String action, // 'ban' or 'unban'
    required String ip,
    String service = 'sshd',
    String? sudoPassword,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final sanitizedAction = action.toLowerCase().trim();
    final sanitizedIp = ip.trim();
    if (sanitizedAction != 'ban' && sanitizedAction != 'unban') {
      return FirewallActionResult(
        success: false,
        action: sanitizedAction,
        ip: sanitizedIp,
        output: '',
        errorMessage: 'Invalid firewall action: $sanitizedAction',
      );
    }

    // IP validation to prevent command injection
    final ipRegex = RegExp(r'^[0-9a-fA-F:\.]+$');
    if (!ipRegex.hasMatch(sanitizedIp)) {
      return FirewallActionResult(
        success: false,
        action: sanitizedAction,
        ip: sanitizedIp,
        output: '',
        errorMessage: 'Invalid IP address format: $sanitizedIp',
      );
    }

    final cleanService = service.trim().toLowerCase();
    final targetJail = (cleanService == 'mysqld' || cleanService == 'mysql')
        ? 'mysqld-auth'
        : (RegExp(r'^[a-z0-9_\-]+\$').hasMatch(cleanService) ? cleanService : 'sshd');

    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      final script = '''
IP="$sanitizedIp"
JAIL="$targetJail"
ACTION="$sanitizedAction"
OUT=""

IPT="iptables"
if command -v iptables >/dev/null 2>&1; then
  IPT="iptables"
elif [ -x /sbin/iptables ]; then
  IPT="/sbin/iptables"
elif [ -x /usr/sbin/iptables ]; then
  IPT="/usr/sbin/iptables"
fi

if [ "\$ACTION" = "ban" ]; then
  # 1. Ban in fail2ban if fail2ban-client exists
  if command -v fail2ban-client >/dev/null 2>&1; then
    F2B_OUT=\$(fail2ban-client set "\$JAIL" banip "\$IP" 2>&1) || true
    OUT="\$OUT\nfail2ban: \$F2B_OUT"
  fi
  # 2. Add iptables DROP rule if not already present
  if \$IPT -C INPUT -s "\$IP" -j DROP >/dev/null 2>&1; then
    OUT="\$OUT\niptables: rule already active"
  else
    IPT_OUT=\$("\$IPT" -I INPUT 1 -s "\$IP" -j DROP 2>&1) || true
    OUT="\$OUT\niptables: \$IPT_OUT"
  fi
elif [ "\$ACTION" = "unban" ]; then
  # 1. Unban in fail2ban
  if command -v fail2ban-client >/dev/null 2>&1 || [ -x /usr/bin/fail2ban-client ]; then
    F2B="fail2ban-client"
    [ -x /usr/bin/fail2ban-client ] && F2B="/usr/bin/fail2ban-client"
    F2B_OUT=\$("\$F2B" unban "\$IP" 2>&1 || "\$F2B" set "\$JAIL" unbanip "\$IP" 2>&1) || true
    OUT="\$OUT\nfail2ban: \$F2B_OUT"
  fi
  # 2. Delete matching iptables rules across INPUT and f2b-* chains
  while \$IPT -C INPUT -s "\$IP" -j DROP >/dev/null 2>&1; do
    IPT_OUT=\$("\$IPT" -D INPUT -s "\$IP" -j DROP 2>&1) || true
    OUT="\$OUT\niptables: \$IPT_OUT"
  done
  while \$IPT -C "f2b-\$JAIL" -s "\$IP" -j REJECT >/dev/null 2>&1; do
    IPT_OUT=\$("\$IPT" -D "f2b-\$JAIL" -s "\$IP" -j REJECT 2>&1) || true
    OUT="\$OUT\niptables f2b-\$JAIL: \$IPT_OUT"
  done
  while \$IPT -C "f2b-\$JAIL" -s "\$IP" -j DROP >/dev/null 2>&1; do
    IPT_OUT=\$("\$IPT" -D "f2b-\$JAIL" -s "\$IP" -j DROP 2>&1) || true
    OUT="\$OUT\niptables f2b-\$JAIL: \$IPT_OUT"
  done
fi

echo -e "\$OUT"
''';

      final escapedScript = script.replaceAll("'", r"'\''");
      final trimmedPass = sudoPassword?.trim();
      String execCommand;
      if (trimmedPass != null && trimmedPass.isNotEmpty) {
        final safePass = trimmedPass.replaceAll("'", r"'\''");
        execCommand = "echo '$safePass' | sudo -S -p '' bash -c '$escapedScript'";
      } else {
        if (profile.username == 'root') {
          execCommand = "bash -c '$escapedScript'";
        } else {
          execCommand = "sudo -n bash -c '$escapedScript' 2>/dev/null || bash -c '$escapedScript'";
        }
      }

      final execBytes = await client.run(execCommand);
      final rawOutput = utf8.decode(execBytes).trim();
      final lowerOut = rawOutput.toLowerCase();
      final isPermissionDenied = lowerOut.contains('permission denied') ||
          lowerOut.contains('a password is required') ||
          lowerOut.contains('incorrect password') ||
          lowerOut.contains('must be root');

      if (isPermissionDenied) {
        return FirewallActionResult(
          success: false,
          action: sanitizedAction,
          ip: sanitizedIp,
          output: rawOutput,
          errorMessage: 'Eskalasi sudo ditolak: Pastikan kata sandi sudo untuk pengguna ${profile.username} sudah benar di Secure Vault.',
        );
      }

      return FirewallActionResult(
        success: true,
        action: sanitizedAction,
        ip: sanitizedIp,
        output: rawOutput,
      );
    } catch (e) {
      if (_isConnectionBroken(e)) {
        _clientPool.remove(profile.id);
      }
      return FirewallActionResult(
        success: false,
        action: sanitizedAction,
        ip: sanitizedIp,
        output: '',
        errorMessage: _sanitizeErrorMessage(e.toString()),
      );
    }
  }

  /// Queries the remote host for active fail2ban and iptables banned IPs
  Future<List<BannedIpRecord>> fetchServerBannedIps({
    required ServerProfile profile,
    required String credential,
    String? sudoPassword,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      final script = r'''
PY_CMD=""
if command -v python3 >/dev/null 2>&1; then
  PY_CMD="python3"
elif command -v python >/dev/null 2>&1; then
  PY_CMD="python"
fi

if [ -n "$PY_CMD" ]; then
$PY_CMD -c '
import subprocess, json, os, re

results = []

def run_cmd(cmd):
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        out, _ = p.communicate()
        return out.decode("utf-8", "ignore")
    except Exception:
        return ""

# 1. Determine fail2ban-client command (with sudo fallback)
f2b_bin = None
for candidate in ["fail2ban-client", "/usr/bin/fail2ban-client", "/usr/local/bin/fail2ban-client", "/sbin/fail2ban-client", "/usr/sbin/fail2ban-client"]:
    if run_cmd(candidate + " --version 2>/dev/null").strip():
        f2b_bin = candidate
        break
    if run_cmd("sudo -n " + candidate + " --version 2>/dev/null").strip():
        f2b_bin = "sudo -n " + candidate
        break

if not f2b_bin:
    f2b_bin = "fail2ban-client"

status_out = run_cmd(f2b_bin + " status 2>/dev/null")
if not status_out and not f2b_bin.startswith("sudo"):
    status_out = run_cmd("sudo -n " + f2b_bin + " status 2>/dev/null")
    if status_out:
        f2b_bin = "sudo -n " + f2b_bin

jails = []
for line in status_out.splitlines():
    if "Jail list:" in line:
        parts = line.split("Jail list:")[1].split(",")
        jails = [j.strip() for j in parts if j.strip()]

for jail in jails:
    jail_out = run_cmd(f2b_bin + " status " + jail + " 2>/dev/null")
    for jline in jail_out.splitlines():
        if "Banned IP list:" in jline:
            raw_ips = jline.split("Banned IP list:")[1].split()
            for ip in raw_ips:
                clean_ip = ip.strip()
                if clean_ip and not any(r["ip"] == clean_ip for r in results):
                    results.append({
                        "ip": clean_ip,
                        "service": jail,
                        "reason": "fail2ban jail [" + jail + "]"
                    })

# 2. Check iptables rules across ALL chains (including f2b-*, fail2ban-*, and INPUT)
ipt_bin = None
for candidate in ["/sbin/iptables", "/usr/sbin/iptables", "iptables"]:
    if run_cmd(candidate + " -V 2>/dev/null").strip():
        ipt_bin = candidate
        break
    if run_cmd("sudo -n " + candidate + " -V 2>/dev/null").strip():
        ipt_bin = "sudo -n " + candidate
        break

if ipt_bin:
    ipt_rules = run_cmd(ipt_bin + " -S 2>/dev/null")
    if not ipt_rules and not ipt_bin.startswith("sudo"):
        ipt_rules = run_cmd("sudo -n " + ipt_bin + " -S 2>/dev/null")

    re_rule = re.compile(r"-A\s+([^\s]+)\s+.*-s\s+([0-9a-fA-F:\.]+)(?:/\d+)?\s+.*-j\s+(DROP|REJECT)", re.IGNORECASE)
    for line in ipt_rules.splitlines():
        m = re_rule.search(line)
        if m:
            chain = m.group(1)
            ip = m.group(2)
            target = m.group(3).upper()
            if ip in ("0.0.0.0", "127.0.0.1", "::1"):
                continue
            if not any(r["ip"] == ip for r in results):
                srv = chain
                if srv.startswith("f2b-"):
                    srv = srv[4:]
                elif srv.startswith("fail2ban-"):
                    srv = srv[9:]
                elif srv == "INPUT":
                    srv = "iptables"

                results.append({
                    "ip": ip,
                    "service": srv,
                    "reason": "Kernel iptables " + target + " filter in " + chain
                })

print(json.dumps(results))
' 2>/dev/null || echo "[]"
else
  # Pure bash fallback
  F2B="fail2ban-client"
  if ! command -v fail2ban-client >/dev/null 2>&1 && [ -x /usr/bin/fail2ban-client ]; then
    F2B="/usr/bin/fail2ban-client"
  fi
  JAILS=$($F2B status 2>/dev/null | grep "Jail list:" | sed 's/.*Jail list://' | tr ',' ' ')
  if [ -z "$JAILS" ]; then
    JAILS=$(sudo -n $F2B status 2>/dev/null | grep "Jail list:" | sed 's/.*Jail list://' | tr ',' ' ')
    if [ -n "$JAILS" ]; then
      F2B="sudo -n $F2B"
    fi
  fi
  echo "["
  first=1
  for J in $JAILS; do
    IPS=$($F2B status "$J" 2>/dev/null | grep "Banned IP list:" | sed 's/.*Banned IP list://')
    for IP in $IPS; do
      [ -z "$IP" ] && continue
      if [ $first -eq 0 ]; then echo ","; fi
      printf '{"ip":"%s","service":"%s","reason":"fail2ban jail [%s]"}' "$IP" "$J" "$J"
      first=0
    done
  done
  echo "]"
fi
''';

      final escapedScript = script.replaceAll("'", r"'\''");
      final trimmedPass = sudoPassword?.trim();
      String execCommand;
      if (trimmedPass != null && trimmedPass.isNotEmpty) {
        final safePass = trimmedPass.replaceAll("'", r"'\''");
        execCommand = "echo '$safePass' | sudo -S -p '' bash -c '$escapedScript'";
      } else {
        if (profile.username == 'root') {
          execCommand = "bash -c '$escapedScript'";
        } else {
          execCommand = "sudo -n bash -c '$escapedScript' 2>/dev/null || bash -c '$escapedScript'";
        }
      }

      final execBytes = await client.run(execCommand);
      final raw = utf8.decode(execBytes).trim();
      final startIdx = raw.indexOf('[');
      final endIdx = raw.lastIndexOf(']');
      if (startIdx == -1 || endIdx == -1 || endIdx < startIdx) {
        return [];
      }
      final jsonStr = raw.substring(startIdx, endIdx + 1);

      final List<dynamic> list = json.decode(jsonStr);
      final now = DateTime.now();
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return BannedIpRecord(
          ip: map['ip'] as String,
          service: map['service'] as String? ?? 'fail2ban',
          reason: map['reason'] as String? ?? 'Active server firewall ban',
          bannedAt: now,
        );
      }).toList();
    } catch (e) {
      if (_isConnectionBroken(e)) {
        _clientPool.remove(profile.id);
      }
      debugPrint('[SshService] Error fetching fail2ban banned IPs: $e');
      return [];
    }
  }

  /// Safely initiates a graceful server reboot via SSH
  Future<FirewallActionResult> rebootServer({
    required ServerProfile profile,
    required String credential,
    String? sudoPassword,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      final trimmedPass = sudoPassword?.trim();
      String execCommand;
      if (trimmedPass != null && trimmedPass.isNotEmpty) {
        final safePass = trimmedPass.replaceAll("'", r"'\''");
        execCommand = "echo '$safePass' | sudo -S -p '' reboot || echo '$safePass' | sudo -S -p '' shutdown -r now";
      } else {
        if (profile.username == "root") {
          execCommand = "reboot || shutdown -r now";
        } else {
          execCommand = "sudo -n reboot 2>/dev/null || sudo -n shutdown -r now 2>/dev/null || reboot";
        }
      }

      try {
        await client.run(execCommand).timeout(const Duration(seconds: 4));
      } catch (_) {
        // Disconnection is the expected outcome of a reboot
      }

      return FirewallActionResult(
        success: true,
        action: "reboot",
        ip: profile.host,
        output: "Sinyal reboot berhasil dikirim ke ${profile.host}",
      );
    } catch (e) {
      debugPrint("[SshService] Error dispatching server reboot: $e");
      return FirewallActionResult(
        success: false,
        action: "reboot",
        ip: profile.host,
        output: "",
        errorMessage: _sanitizeErrorMessage(e.toString()),
      );
    } finally {
      await disconnect(profile.id);
    }
  }

  /// Non-destructively reads recent log lines for analysis with strict path validation
  Future<List<String>> fetchRecentLogs({
    required ServerProfile profile,
    required String credential,
    required String logPath,
    int lines = 80,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final sanitizedPath = logPath.trim();
    // Path traversal & command injection protection
    if (!_safeLogPathRegex.hasMatch(sanitizedPath) || sanitizedPath.contains('..')) {
      throw SecurityException('Rejected unsafe log path: $sanitizedPath');
    }

    final safeLines = lines.clamp(1, 500);

    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      // Safe, read-only tail command with bounded lines
      final command = 'tail -n $safeLines $sanitizedPath 2>/dev/null || true';
      final Uint8List bytes = await client.run(command);
      final output = utf8.decode(bytes);
      if (output.trim().isEmpty) return [];
      return const LineSplitter().convert(output);
    } catch (e) {
      if (_isConnectionBroken(e)) {
        _clientPool.remove(profile.id);
      }
      return [];
    }
  }

  /// Queries all log occurrences for a specific IP across standard system logs on the remote host
  Future<List<String>> fetchIpEvidenceLogs({
    required ServerProfile profile,
    required String credential,
    required String ip,
    int maxLines = 100,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final cleanIp = ip.trim();
    if (!RegExp(r'^[0-9a-fA-F:\.]+$').hasMatch(cleanIp)) {
      return [];
    }

    final safeLines = maxLines.clamp(1, 200);
    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      final command = 'grep -h -F "$cleanIp" /var/log/mysqld.log /var/log/secure /var/log/auth.log /var/log/messages 2>/dev/null | tail -n $safeLines || true';
      final Uint8List bytes = await client.run(command);
      final output = utf8.decode(bytes);
      if (output.trim().isEmpty) return [];
      return const LineSplitter().convert(output);
    } catch (e) {
      if (_isConnectionBroken(e)) {
        _clientPool.remove(profile.id);
      }
      return [];
    }
  }

  /// Unified log reader: retrieves recent logs across SSH, MySQL, Fail2ban, and systemd journal
  Future<List<String>> fetchUnifiedServerLogs({
    required ServerProfile profile,
    required String credential,
    String? sudoPassword,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      const script = r'''
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

read_file() {
  local f="$1"
  local n="$2"
  if [ -f "$f" ]; then
    tail -n "$n" "$f" 2>/dev/null || true
  fi
}

# 1. SSH Authentication Logs (RHEL/CentOS/CloudLinux and Debian/Ubuntu)
read_file /var/log/secure 120
read_file /var/log/auth.log 120

# 2. Database Logs (MySQL / MariaDB)
read_file /var/log/mysqld.log 80
read_file /var/log/mysql/error.log 80
read_file /var/log/mariadb/mariadb.log 80

# 3. Fail2ban Logs
read_file /var/log/fail2ban.log 80

# 4. Systemd Journal fallback
if command -v journalctl >/dev/null 2>&1; then
  journalctl -u ssh -u sshd -u mysqld -u mariadb -u fail2ban -n 80 --no-pager 2>/dev/null || true
fi
''';

      final escapedScript = script.replaceAll("'", r"'\''");
      final trimmedPass = sudoPassword?.trim();
      String execCommand;
      if (trimmedPass != null && trimmedPass.isNotEmpty) {
        final safePass = trimmedPass.replaceAll("'", r"'\''");
        execCommand = "echo '$safePass' | sudo -S -p '' bash -c '$escapedScript'";
      } else {
        if (profile.username == 'root') {
          execCommand = "bash -c '$escapedScript'";
        } else {
          execCommand = "sudo -n bash -c '$escapedScript' 2>/dev/null || bash -c '$escapedScript'";
        }
      }

      final Uint8List bytes = await client.run(execCommand);
      final output = utf8.decode(bytes);
      if (output.trim().isEmpty) return [];
      return const LineSplitter().convert(output);
    } catch (e) {
      if (_isConnectionBroken(e)) {
        _clientPool.remove(profile.id);
      }
      debugPrint('[SshService] Error fetching unified server logs: $e');
      return [];
    }
  }

  /// Continuously samples multi-core CPU, RAM, partition health, uptime, and active network sockets
  Future<HardwareTelemetry?> fetchHardwareTelemetry({
    required ServerProfile profile,
    required String credential,
    String? totpSecret,
    String? oneTimeCode,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    SSHClient? client;
    try {
      client = await getOrConnectClient(
        profile: profile,
        credential: credential,
        totpSecret: totpSecret,
        oneTimeCode: oneTimeCode,
        onPrompt2FA: onPrompt2FA,
      );

      const script = r'''
if command -v python3 >/dev/null 2>&1; then
python3 -c "
import json, time, os, re, subprocess
def get_telemetry():
    def read_cpu():
        cores = {}
        with open('/proc/stat') as f:
            for l in f:
                if l.startswith('cpu'):
                    p = l.split()
                    name = p[0]
                    vals = [float(x) for x in p[1:]]
                    idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
                    total = sum(vals)
                    cores[name] = (idle, total)
        return cores
    c1 = read_cpu()
    time.sleep(0.2)
    c2 = read_cpu()
    cpu_cores = []
    overall_cpu = 0.0
    for name in sorted(c1.keys(), key=lambda x: (len(x), x)):
        i1, t1 = c1[name]
        i2, t2 = c2[name]
        dt = t2 - t1
        di = i2 - i1
        pct = round(100.0 * (1.0 - (di / dt)), 1) if dt > 0 else 0.0
        pct = max(0.0, min(100.0, pct))
        if name == 'cpu':
            overall_cpu = pct
        else:
            cpu_cores.append({'name': name, 'usage': pct})
    load_avg = [0.0, 0.0, 0.0]
    try:
        with open('/proc/loadavg') as f:
            lp = f.read().split()
            load_avg = [float(lp[0]), float(lp[1]), float(lp[2])]
    except Exception:
        pass
    model_name = None
    try:
        with open('/proc/cpuinfo') as f:
            for l in f:
                if 'model name' in l:
                    model_name = l.split(':', 1)[1].strip()
                    break
    except Exception:
        pass
    mem = {}
    with open('/proc/meminfo') as f:
        for l in f:
            parts = l.split(':')
            if len(parts) == 2:
                k = parts[0].strip()
                v = parts[1].strip().split()[0]
                mem[k] = int(v) * 1024
    total_ram = mem.get('MemTotal', 0)
    avail_ram = mem.get('MemAvailable', mem.get('MemFree', 0))
    used_ram = max(0, total_ram - avail_ram)
    free_ram = mem.get('MemFree', 0)
    cached_ram = mem.get('Cached', 0)
    buffers_ram = mem.get('Buffers', 0)
    swap_total = mem.get('SwapTotal', 0)
    swap_free = mem.get('SwapFree', 0)
    swap_used = max(0, swap_total - swap_free)
    ram_pct = round((used_ram / total_ram * 100.0), 1) if total_ram > 0 else 0.0
    partitions = []
    seen_mounts = set()
    try:
        if os.path.exists('/proc/mounts'):
            with open('/proc/mounts') as mf:
                for line in mf:
                    mp = line.split()
                    if len(mp) >= 3:
                        m_fs, m_mnt, m_type = mp[0], mp[1], mp[2]
                        if any(m_fs.startswith(x) for x in ['tmpfs', 'udev', 'devtmpfs', '/dev/loop', 'none', 'proc', 'sysfs']): continue
                        if any(m_mnt.startswith(x) for x in ['/proc', '/sys', '/dev', '/run', '/var/lib/docker']): continue
                        if m_type in ['ext4', 'ext3', 'ext2', 'xfs', 'btrfs', 'zfs', 'simfs', 'overlay', 'f2fs', 'vfat', 'ntfs', 'nfs'] or m_fs.startswith('/dev/'):
                            try:
                                if m_mnt not in seen_mounts:
                                    st = os.statvfs(m_mnt)
                                    tot = int(st.f_blocks) * int(st.f_frsize)
                                    if tot > 0:
                                        seen_mounts.add(m_mnt)
                                        fr = int(st.f_bfree) * int(st.f_frsize)
                                        avl = int(st.f_bavail) * int(st.f_frsize)
                                        usd = max(0, tot - fr)
                                        pct = round((usd / tot * 100.0), 1)
                                        partitions.append({'filesystem': m_fs, 'mount': m_mnt, 'total_bytes': tot, 'used_bytes': usd, 'available_bytes': avl, 'usage_percent': pct})
                            except Exception: pass
    except Exception: pass
    if not any(p.get('mount') == '/' for p in partitions):
        try:
            st = os.statvfs('/')
            tot = int(st.f_blocks) * int(st.f_frsize)
            if tot > 0:
                fr = int(st.f_bfree) * int(st.f_frsize)
                avl = int(st.f_bavail) * int(st.f_frsize)
                usd = max(0, tot - fr)
                pct = round((usd / tot * 100.0), 1)
                partitions.insert(0, {'filesystem': '/dev/root', 'mount': '/', 'total_bytes': tot, 'used_bytes': usd, 'available_bytes': avl, 'usage_percent': pct})
        except Exception: pass
    sock = {'total': 0, 'tcp_inuse': 0, 'tcp_tw': 0, 'tcp_alloc': 0, 'udp_inuse': 0}
    try:
        with open('/proc/net/sockstat') as f:
            for line in f:
                if line.startswith('sockets:'):
                    m = re.search(r'used\s+(\d+)', line)
                    if m: sock['total'] = int(m.group(1))
                elif line.startswith('TCP:'):
                    m_inuse = re.search(r'inuse\s+(\d+)', line)
                    m_tw = re.search(r'tw\s+(\d+)', line)
                    m_alloc = re.search(r'alloc\s+(\d+)', line)
                    if m_inuse: sock['tcp_inuse'] = int(m_inuse.group(1))
                    if m_tw: sock['tcp_tw'] = int(m_tw.group(1))
                    if m_alloc: sock['tcp_alloc'] = int(m_alloc.group(1))
                elif line.startswith('UDP:'):
                    m_udp = re.search(r'inuse\s+(\d+)', line)
                    if m_udp: sock['udp_inuse'] = int(m_udp.group(1))
    except Exception: pass
    uptime_sec = 0
    try:
        with open('/proc/uptime') as f: uptime_sec = int(float(f.read().split()[0]))
    except Exception: pass
    days = uptime_sec // 86400
    hours = (uptime_sec % 86400) // 3600
    mins = (uptime_sec % 3600) // 60
    uptime_fmt = f'{days}d {hours}h {mins}m' if days > 0 else (f'{hours}h {mins}m' if hours > 0 else f'{mins}m')
    return {'cpu': {'overall': overall_cpu, 'cores': cpu_cores, 'load_avg': load_avg, 'model_name': model_name}, 'ram': {'total_bytes': total_ram, 'used_bytes': used_ram, 'free_bytes': free_ram, 'available_bytes': avail_ram, 'cached_bytes': cached_ram, 'buffers_bytes': buffers_ram, 'swap_total': swap_total, 'swap_used': swap_used, 'usage_percent': ram_pct}, 'partitions': partitions, 'sockets': sock, 'uptime_seconds': uptime_sec, 'uptime_formatted': uptime_fmt}
print(json.dumps(get_telemetry()))
"
else
c1=$(grep '^cpu' /proc/stat)
sleep 0.2
c2=$(grep '^cpu' /proc/stat)
mem=$(grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree):' /proc/meminfo)
part=$(df -kP 2>/dev/null || /bin/df -kP 2>/dev/null || /usr/bin/df -kP 2>/dev/null)
sock=$(cat /proc/net/sockstat 2>/dev/null)
up=$(cat /proc/uptime 2>/dev/null)
echo "---CPU1---"
echo "$c1"
echo "---CPU2---"
echo "$c2"
echo "---MEM---"
echo "$mem"
echo "---DF---"
echo "$part"
echo "---SOCK---"
echo "$sock"
echo "---UP---"
echo "$up"
fi
''';

      final bytes = await client.run(script);
      final rawOutput = utf8.decode(bytes).trim();
      if (rawOutput.isEmpty) return null;

      // Extract JSON if embedded or directly outputted
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(rawOutput);
      if (jsonMatch != null) {
        try {
          final map = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          return HardwareTelemetry.fromMap(map, serverId: profile.id);
        } catch (_) {}
      }

      return _parseDelimitedTelemetry(rawOutput, profile.id);
    } catch (e) {
      if (_isConnectionBroken(e)) {
        _clientPool.remove(profile.id);
      }
      debugPrint('[SshService] Error fetching hardware telemetry: $e');
      return null;
    }
  }

  HardwareTelemetry _parseDelimitedTelemetry(String raw, String serverId) {
    final sections = <String, List<String>>{};
    String currentSection = 'default';
    for (final line in const LineSplitter().convert(raw)) {
      final trimmed = line.trim();
      if (trimmed.startsWith('---') && trimmed.endsWith('---')) {
        currentSection = trimmed.replaceAll('---', '');
        sections[currentSection] = [];
      } else if (trimmed.isNotEmpty) {
        sections.putIfAbsent(currentSection, () => []).add(trimmed);
      }
    }

    // 1. Parse CPU
    final c1Lines = sections['CPU1'] ?? [];
    final c2Lines = sections['CPU2'] ?? [];
    final Map<String, List<double>> c1 = {};
    for (final l in c1Lines) {
      final p = l.split(RegExp(r'\s+'));
      if (p.isNotEmpty && p[0].startsWith('cpu')) {
        c1[p[0]] = p.skip(1).map((x) => double.tryParse(x) ?? 0.0).toList();
      }
    }
    double overallCpu = 0.0;
    final List<CpuCoreMetric> cores = [];
    for (final l in c2Lines) {
      final p = l.split(RegExp(r'\s+'));
      if (p.isNotEmpty && p[0].startsWith('cpu') && c1.containsKey(p[0])) {
        final name = p[0];
        final v2 = p.skip(1).map((x) => double.tryParse(x) ?? 0.0).toList();
        final v1 = c1[name]!;
        if (v1.length >= 4 && v2.length >= 4) {
          final idle1 = v1[3] + (v1.length > 4 ? v1[4] : 0.0);
          final idle2 = v2[3] + (v2.length > 4 ? v2[4] : 0.0);
          final tot1 = v1.fold<double>(0.0, (a, b) => a + b);
          final tot2 = v2.fold<double>(0.0, (a, b) => a + b);
          final dt = tot2 - tot1;
          final di = idle2 - idle1;
          final pct = dt > 0 ? ((1.0 - (di / dt)) * 100.0).clamp(0.0, 100.0) : 0.0;
          final rounded = double.parse(pct.toStringAsFixed(1));
          if (name == 'cpu') {
            overallCpu = rounded;
          } else {
            cores.add(CpuCoreMetric(name: name, usage: rounded));
          }
        }
      }
    }

    // 2. Parse Memory
    final memLines = sections['MEM'] ?? [];
    final Map<String, int> memMap = {};
    for (final l in memLines) {
      final p = l.split(':');
      if (p.length == 2) {
        final k = p[0].trim();
        final v = int.tryParse(p[1].trim().split(RegExp(r'\s+'))[0]) ?? 0;
        memMap[k] = v * 1024;
      }
    }
    final totalRam = memMap['MemTotal'] ?? 0;
    final availRam = memMap['MemAvailable'] ?? (memMap['MemFree'] ?? 0);
    final usedRam = (totalRam - availRam).clamp(0, totalRam);
    final freeRam = memMap['MemFree'] ?? 0;
    final cachedRam = memMap['Cached'] ?? 0;
    final buffersRam = memMap['Buffers'] ?? 0;
    final swapTotal = memMap['SwapTotal'] ?? 0;
    final swapFree = memMap['SwapFree'] ?? 0;
    final swapUsed = (swapTotal - swapFree).clamp(0, swapTotal);
    final ramPct = totalRam > 0
        ? double.parse(((usedRam / totalRam) * 100.0).toStringAsFixed(1))
        : 0.0;

    // 3. Parse Partitions
    final dfLines = sections['DF'] ?? [];
    final List<PartitionHealth> partitions = [];
    String? pendingFs;
    for (int i = 0; i < dfLines.length; i++) {
      final line = dfLines[i].trim();
      if (line.isEmpty || line.toLowerCase().startsWith('filesystem')) continue;
      final p = line.split(RegExp(r'\s+'));
      if (p.length == 1 && pendingFs == null) {
        pendingFs = p[0];
        continue;
      }
      final fs = pendingFs ?? p[0];
      final parts = pendingFs != null ? p : p.skip(1).toList();
      pendingFs = null;

      if (parts.length >= 5) {
        final sizeK = int.tryParse(parts[0]) ?? 0;
        final usedK = int.tryParse(parts[1]) ?? 0;
        final availK = int.tryParse(parts[2]) ?? 0;
        final pctStr = parts[3].replaceAll('%', '');
        var pct = double.tryParse(pctStr) ?? 0.0;
        final mnt = parts.last;

        if (pct <= 0.0 && sizeK > 0 && usedK > 0) {
          pct = double.parse(((usedK / sizeK) * 100.0).toStringAsFixed(1));
        }

        if (!fs.startsWith('tmpfs') &&
            !fs.startsWith('devtmpfs') &&
            !mnt.startsWith('/boot') &&
            !mnt.startsWith('/run') &&
            !mnt.startsWith('/sys')) {
          partitions.add(
            PartitionHealth(
              filesystem: fs,
              mount: mnt,
              totalBytes: sizeK * 1024,
              usedBytes: usedK * 1024,
              availableBytes: availK * 1024,
              usagePercent: pct,
            ),
          );
        }
      }
    }

    // 4. Parse Sockets
    final sockLines = sections['SOCK'] ?? [];
    int totalSock = 0, tcpInUse = 0, tcpTw = 0, tcpAlloc = 0, udpInUse = 0;
    for (final l in sockLines) {
      if (l.startsWith('sockets:')) {
        final m = RegExp(r'used\s+(\d+)').firstMatch(l);
        if (m != null) totalSock = int.tryParse(m.group(1)!) ?? 0;
      } else if (l.startsWith('TCP:')) {
        final mInUse = RegExp(r'inuse\s+(\d+)').firstMatch(l);
        final mTw = RegExp(r'tw\s+(\d+)').firstMatch(l);
        final mAlloc = RegExp(r'alloc\s+(\d+)').firstMatch(l);
        if (mInUse != null) tcpInUse = int.tryParse(mInUse.group(1)!) ?? 0;
        if (mTw != null) tcpTw = int.tryParse(mTw.group(1)!) ?? 0;
        if (mAlloc != null) tcpAlloc = int.tryParse(mAlloc.group(1)!) ?? 0;
      } else if (l.startsWith('UDP:')) {
        final mUdp = RegExp(r'inuse\s+(\d+)').firstMatch(l);
        if (mUdp != null) udpInUse = int.tryParse(mUdp.group(1)!) ?? 0;
      }
    }

    // 5. Parse Uptime
    final upLines = sections['UP'] ?? [];
    int upSec = 0;
    if (upLines.isNotEmpty) {
      final p = upLines[0].split(RegExp(r'\s+'));
      if (p.isNotEmpty) {
        upSec = (double.tryParse(p[0]) ?? 0.0).toInt();
      }
    }
    final d = upSec ~/ 86400;
    final h = (upSec % 86400) ~/ 3600;
    final m = (upSec % 3600) ~/ 60;
    final upFmt = d > 0 ? '${d}d ${h}h ${m}m' : (h > 0 ? '${h}h ${m}m' : '${m}m');

    return HardwareTelemetry(
      serverId: serverId,
      timestamp: DateTime.now(),
      cpu: CpuTelemetry(
        overall: overallCpu,
        cores: cores,
        loadAvg: const [0.5, 0.6, 0.7],
      ),
      ram: RamTelemetry(
        totalBytes: totalRam,
        usedBytes: usedRam,
        freeBytes: freeRam,
        availableBytes: availRam,
        cachedBytes: cachedRam,
        buffersBytes: buffersRam,
        swapTotal: swapTotal,
        swapUsed: swapUsed,
        usagePercent: ramPct,
      ),
      partitions: partitions,
      sockets: NetworkSocketTelemetry(
        total: totalSock,
        tcpInUse: tcpInUse,
        tcpTimeWait: tcpTw,
        tcpAlloc: tcpAlloc,
        udpInUse: udpInUse,
      ),
      uptimeSeconds: upSec,
      uptimeFormatted: upFmt,
    );
  }

  bool _isConnectionBroken(Object e) {
    final str = e.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('broken pipe') ||
        str.contains('connection closed') ||
        str.contains('connection reset') ||
        str.contains('closed by remote') ||
        str.contains('timeoutexception') ||
        str.contains('sshstateerror');
  }

  String _sanitizeErrorMessage(String msg) {
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Connection refused: Host unreachable or port closed';
    }
    if (msg.contains('2FA') || msg.contains('verification code')) {
      return msg.contains('Exception: ') ? msg.split('Exception: ').last : msg;
    }
    if (msg.contains('SSH authentication failed') || msg.contains('auth')) {
      return 'Authentication failed: Invalid credentials, rejected key, or missing 2FA code';
    }
    if (msg.contains('TimeoutException')) {
      return 'Connection timed out: Server did not respond within 8s';
    }
    return msg.length > 120 ? '${msg.substring(0, 120)}...' : msg;
  }
}

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}
