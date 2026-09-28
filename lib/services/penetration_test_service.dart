import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/service_registry.dart';
import '../models/auth_event.dart';
import '../models/security_policy.dart';
import 'notification_service.dart';

enum PenTestScenario {
  bruteForce,
  unknownPerson,
  exploitProbe,
}

extension PenTestScenarioExtension on PenTestScenario {
  String get displayNameId {
    switch (this) {
      case PenTestScenario.bruteForce:
        return 'Serangan Brute Force (Pelanggaran Ambang Batas)';
      case PenTestScenario.unknownPerson:
        return 'Penyusupan Orang Tak Dikenal (Akses Sukses Tak Wajar)';
      case PenTestScenario.exploitProbe:
        return 'Injeksi Eksploitasi & Pemindaian Kerentanan';
    }
  }

  String get displayNameEn {
    switch (this) {
      case PenTestScenario.bruteForce:
        return 'Brute Force Attack (Threshold Breach)';
      case PenTestScenario.unknownPerson:
        return 'Unknown Person Intrusion (Anomalous Valid Login)';
      case PenTestScenario.exploitProbe:
        return 'Exploit Injection & Vulnerability Probe';
    }
  }

  IconData get icon {
    switch (this) {
      case PenTestScenario.bruteForce:
        return Icons.flash_on_rounded;
      case PenTestScenario.unknownPerson:
        return Icons.person_off_rounded;
      case PenTestScenario.exploitProbe:
        return Icons.pest_control_rounded;
    }
  }

  Color get color {
    switch (this) {
      case PenTestScenario.bruteForce:
        return const Color(0xFFFF5252);
      case PenTestScenario.unknownPerson:
        return const Color(0xFFFF9100);
      case PenTestScenario.exploitProbe:
        return const Color(0xFFE040FB);
    }
  }
}

class PenTestStep {
  final DateTime timestamp;
  final String message;
  final bool isAlert;
  final bool isSuccess;

  const PenTestStep({
    required this.timestamp,
    required this.message,
    this.isAlert = false,
    this.isSuccess = false,
  });
}

class PenTestResult {
  final ServiceDefinition service;
  final PenTestScenario scenario;
  final String clientIp;
  final String targetUser;
  final AuthEvent event;
  final List<PenTestStep> executionLogs;
  final bool alertTriggered;
  final String alertTitle;
  final String alertMessage;
  final Duration executionDuration;

  const PenTestResult({
    required this.service,
    required this.scenario,
    required this.clientIp,
    required this.targetUser,
    required this.event,
    required this.executionLogs,
    required this.alertTriggered,
    required this.alertTitle,
    required this.alertMessage,
    required this.executionDuration,
  });
}

class PenetrationTestService {
  static final PenetrationTestService _instance = PenetrationTestService._internal();
  factory PenetrationTestService() => _instance;
  PenetrationTestService._internal();

  final NotificationService _notificationService = NotificationService();

  static const List<Map<String, String>> threatOrigins = [
    {
      'ip': '185.220.101.99',
      'city': 'Moscow',
      'country': 'RU',
      'flag': '🇷🇺',
      'asn': 'AS208294 (Tor Exit Gateway)',
      'category': 'Tor Exit Node',
    },
    {
      'ip': '195.123.245.61',
      'city': 'Saint Petersburg',
      'country': 'RU',
      'flag': '🇷🇺',
      'asn': 'AS62240 (Mirai C2 Cluster)',
      'category': 'Botnet C2 Node',
    },
    {
      'ip': '194.26.29.112',
      'city': 'Amsterdam',
      'country': 'NL',
      'flag': '🇳🇱',
      'asn': 'AS49981 (HostRoyale Scanner)',
      'category': 'Vulnerability Scanner',
    },
    {
      'ip': '45.154.255.88',
      'city': 'Kyiv',
      'country': 'UA',
      'flag': '🇺🇦',
      'asn': 'AS197695 (Autonomous SSH Probe)',
      'category': 'Brute Force Bot',
    },
    {
      'ip': '198.51.100.77',
      'city': 'Ashburn',
      'country': 'US',
      'flag': '🇺🇸',
      'asn': 'AS14618 (Automated Exploit Bot)',
      'category': 'Exploit Scanner',
    },
    {
      'ip': '23.95.224.15',
      'city': 'Los Angeles',
      'country': 'US',
      'flag': '🇺🇸',
      'asn': 'AS36352 (Masscan Fleet Node)',
      'category': 'Port Scanner',
    },
    {
      'ip': '91.240.118.2',
      'city': 'Frankfurt',
      'country': 'DE',
      'flag': '🇩🇪',
      'asn': 'AS39351 (High-Velocity Spray)',
      'category': 'Credential Spray',
    },
    {
      'ip': '103.203.57.18',
      'city': 'Beijing',
      'country': 'CN',
      'flag': '🇨🇳',
      'asn': 'AS4134 (Chinanet Backbone)',
      'category': 'APT Reconnaissance',
    },
    {
      'ip': '222.186.42.137',
      'city': 'Shenzhen',
      'country': 'CN',
      'flag': '🇨🇳',
      'asn': 'AS4837 (Distributed IoT Fuzzer)',
      'category': 'IoT Botnet',
    },
    {
      'ip': '177.54.148.90',
      'city': 'São Paulo',
      'country': 'BR',
      'flag': '🇧🇷',
      'asn': 'AS28573 (Latin-Am Proxy Network)',
      'category': 'Proxy Infiltration',
    },
    {
      'ip': '128.199.202.14',
      'city': 'Singapore',
      'country': 'SG',
      'flag': '🇸🇬',
      'asn': 'AS14061 (DigitalOcean Relay)',
      'category': 'Cloud Probe',
    },
    {
      'ip': '211.233.77.42',
      'city': 'Seoul',
      'country': 'KR',
      'flag': '🇰🇷',
      'asn': 'AS9318 (Automated Exploit Rig)',
      'category': 'Malware Distribution',
    },
    {
      'ip': '89.46.223.104',
      'city': 'London',
      'country': 'GB',
      'flag': '🇬🇧',
      'asn': 'AS20860 (Hostinger Scraping Daemon)',
      'category': 'Web Scraping Probe',
    },
    {
      'ip': '51.15.241.9',
      'city': 'Paris',
      'country': 'FR',
      'flag': '🇫🇷',
      'asn': 'AS12876 (Scaleway Fuzzer Node)',
      'category': 'Cloud Fuzzer',
    },
    {
      'ip': '103.111.54.89',
      'city': 'Mumbai',
      'country': 'IN',
      'flag': '🇮🇳',
      'asn': 'AS133661 (Dictionary SSH Cluster)',
      'category': 'Dictionary Attack',
    },
    {
      'ip': '118.69.135.22',
      'city': 'Hanoi',
      'country': 'VN',
      'flag': '🇻🇳',
      'asn': 'AS18403 (VNPT Multi-Proxy Chain)',
      'category': 'Anomalous Proxy',
    },
    {
      'ip': '133.130.121.84',
      'city': 'Tokyo',
      'country': 'JP',
      'flag': '🇯🇵',
      'asn': 'AS9370 (Sakura Internet Scanner)',
      'category': 'Cloud Port Scan',
    },
    {
      'ip': '139.99.144.52',
      'city': 'Sydney',
      'country': 'AU',
      'flag': '🇦🇺',
      'asn': 'AS16276 (OVH APAC Probe)',
      'category': 'Host Recon',
    },
    {
      'ip': '103.142.21.250',
      'city': 'Jakarta',
      'country': 'ID',
      'flag': '🇮🇩',
      'asn': 'AS136052 (Untrusted Domestic IP)',
      'category': 'Domestic Unknown Login',
    },
    {
      'ip': '175.45.176.15',
      'city': 'Pyongyang',
      'country': 'KP',
      'flag': '🇰🇵',
      'asn': 'AS131279 (Star-KP Advanced Threat)',
      'category': 'State-Sponsored Actor',
    },
    {
      'ip': '5.200.14.88',
      'city': 'Tehran',
      'country': 'IR',
      'flag': '🇮🇷',
      'asn': 'AS58224 (High-Risk Infiltration)',
      'category': 'Adversary Recon',
    },
  ];

  static Map<String, String> resolveOrigin(String ip) {
    return threatOrigins.firstWhere(
      (o) => o['ip'] == ip,
      orElse: () => {
        'ip': ip,
        'city': 'Custom Threat Origin',
        'country': 'XX',
        'flag': '🌐',
        'asn': 'AS99999 (Operator Custom Pen-Test IP)',
        'category': 'Custom Target IP',
      },
    );
  }

  /// Simulates and executes an end-to-end cyber penetration test against [service].
  /// Emits incremental progress steps to [onStep].
  /// Dispatches system notifications, sound, vibration, and creates the resulting [AuthEvent].
  Future<PenTestResult> executePenTest({
    required ServiceDefinition service,
    required PenTestScenario scenario,
    required SecurityPolicy policy,
    required String serverId,
    String? customIp,
    Function(PenTestStep step, double progress)? onStep,
  }) async {
    final startTime = DateTime.now();
    final random = Random();
    final origin = customIp != null
        ? resolveOrigin(customIp)
        : threatOrigins[random.nextInt(threatOrigins.length)];

    final attackerIp = origin['ip']!;
    final city = origin['city']!;
    final country = origin['country']!;
    final asn = origin['asn']!;
    final List<PenTestStep> executionLogs = [];

    void logStep(String msg, {bool isAlert = false, bool isSuccess = false, double progress = 0.0}) {
      final step = PenTestStep(
        timestamp: DateTime.now(),
        message: msg,
        isAlert: isAlert,
        isSuccess: isSuccess,
      );
      executionLogs.add(step);
      onStep?.call(step, progress);
    }

    // Step 1: Probe initiation & socket reachability
    logStep(
      '[RECON] Initializing penetration probe against ${service.name} (${service.portDisplay})...',
      progress: 0.10,
    );
    await Future.delayed(const Duration(milliseconds: 150));

    logStep(
      '[AGENT] Spoofing attacker origin: $attackerIp ($city, $country) • $asn',
      progress: 0.25,
    );
    await Future.delayed(const Duration(milliseconds: 200));

    // Determine target username & specific service logs
    final targetUser = _getTargetUserForService(service.id, scenario);
    final evidenceLogs = _generateEvidenceLogs(
      serviceId: service.id,
      scenario: scenario,
      attackerIp: attackerIp,
      user: targetUser,
      threshold: policy.maxFailedAttemptsThreshold,
    );

    // Step 2: Infiltration attempts
    for (int i = 0; i < evidenceLogs.length; i++) {
      final attemptNum = i + 1;
      logStep(
        '[PAYLOAD #$attemptNum/${evidenceLogs.length}] Sent to ${service.id}: ${evidenceLogs[i]}',
        progress: 0.30 + (i / evidenceLogs.length) * 0.40,
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Step 3: Anomaly Sentinel Evaluation
    final isBruteForce = scenario == PenTestScenario.bruteForce;
    final isUnknown = scenario == PenTestScenario.unknownPerson;
    final isExploit = scenario == PenTestScenario.exploitProbe;

    final rawLog = evidenceLogs.first;
    final eventStatus = isUnknown ? EventStatus.success : EventStatus.failed;
    final severity = (isBruteForce || isUnknown || isExploit)
        ? EventSeverity.critical
        : EventSeverity.warning;
    final riskScore = isUnknown ? 98 : (isBruteForce ? 95 : 90);

    String alertTitle;
    String alertBody;
    String failureReason;

    if (isUnknown) {
      alertTitle = '🚨 CRITICAL: Unknown Person Access';
      alertBody =
          'User "$targetUser" logged in to ${service.name} from untrusted IP $attackerIp ($city, $country)!';
      failureReason = 'UNKNOWN PERSON: Verified login from untrusted IP';
    } else if (isBruteForce) {
      alertTitle = '⚠️ BRUTE FORCE ATTACK DETECTED';
      alertBody =
          'IP $attackerIp breached threshold on ${service.name} (${evidenceLogs.length} attempts in ${policy.timeWindowSeconds}s)';
      failureReason =
          'BRUTE FORCE DETECTED: ${evidenceLogs.length} failed attempts in ${policy.timeWindowSeconds}s';
    } else {
      alertTitle = '🚨 EXPLOIT PROBE DETECTED';
      alertBody =
          'Malicious payload targeting ${service.name} intercepted from $attackerIp ($city, $country)';
      failureReason = 'SECURITY INJECTION: Malicious exploit payload signature';
    }

    logStep(
      '[SENTINEL] Evaluating sliding window telemetry (${policy.timeWindowSeconds}s interval)...',
      progress: 0.80,
    );
    await Future.delayed(const Duration(milliseconds: 150));

    logStep(
      '[ALARM] ANOMALY CONFIRMED: $alertTitle (Risk Score: $riskScore/100)',
      isAlert: true,
      progress: 0.90,
    );

    // Step 4: Dispatch real system notification & heads-up alert
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _notificationService.showSecurityAlert(
      id: notificationId,
      title: alertTitle,
      body: alertBody,
      payload: attackerIp,
      isCritical: true,
    );

    logStep(
      '[DISPATCH] Heads-up notification & sound alert triggered to system tray.',
      isSuccess: true,
      progress: 1.0,
    );

    final event = AuthEvent(
      id: const Uuid().v4(),
      serverId: serverId,
      service: service.id,
      timestamp: DateTime.now(),
      clientIp: attackerIp,
      user: targetUser,
      status: eventStatus,
      severity: severity,
      riskScore: riskScore,
      isUnknownPerson: isUnknown,
      failureReason: failureReason,
      country: country,
      city: city,
      asn: asn,
      rawLog: rawLog,
      attemptCount: evidenceLogs.length,
      evidenceLogs: evidenceLogs,
    );

    return PenTestResult(
      service: service,
      scenario: scenario,
      clientIp: attackerIp,
      targetUser: targetUser,
      event: event,
      executionLogs: executionLogs,
      alertTriggered: true,
      alertTitle: alertTitle,
      alertMessage: alertBody,
      executionDuration: DateTime.now().difference(startTime),
    );
  }

  String _getTargetUserForService(String serviceId, PenTestScenario scenario) {
    switch (serviceId.toLowerCase()) {
      case 'mysqld':
      case 'mysql':
      case 'mariadb':
        return scenario == PenTestScenario.unknownPerson ? 'root' : 'admin';
      case 'sshd':
      case 'ssh':
        return 'root';
      case 'httpd':
      case 'apache':
      case 'nginx':
        return scenario == PenTestScenario.unknownPerson ? 'sysadmin' : 'www-data';
      case 'redis-server':
      case 'redis':
        return 'default';
      case 'dovecot':
        return 'postmaster';
      case 'exim':
        return 'mailer-daemon';
      case 'pure-ftpd':
        return 'ftpadmin';
      default:
        return 'root';
    }
  }

  List<String> _generateEvidenceLogs({
    required String serviceId,
    required PenTestScenario scenario,
    required String attackerIp,
    required String user,
    required int threshold,
  }) {
    final count = scenario == PenTestScenario.bruteForce
        ? max(threshold + 2, 5)
        : (scenario == PenTestScenario.unknownPerson ? 1 : 3);

    final logs = <String>[];
    final sId = serviceId.toLowerCase();

    for (int i = 0; i < count; i++) {
      final port = 49152 + i * 2;
      String log;

      if (scenario == PenTestScenario.unknownPerson) {
        if (sId.contains('ssh')) {
          log =
              'Accepted publickey for $user from $attackerIp port $port ssh2: RSA SHA256:9f8a... (UNRECOGNIZED IP)';
        } else if (sId.contains('mysql') || sId.contains('mariadb')) {
          log = '145 Connect $user@$attackerIp on aegis_db using TCP/IP (ANOMALOUS REMOTE ACCESS)';
        } else if (sId.contains('nginx') || sId.contains('httpd')) {
          log =
              "POST /api/v1/auth/session HTTP/1.1 200 OK - user '$user' authenticated from untrusted IP $attackerIp";
        } else {
          log = "Connection authenticated for '$user' from $attackerIp:$port (UNKNOWN PERSON)";
        }
      } else if (scenario == PenTestScenario.exploitProbe) {
        if (sId.contains('mysql') || sId.contains('mariadb')) {
          log =
              "Query 'SELECT * FROM users WHERE id=1 UNION SELECT null,username,password FROM admin--' rejected: WAF Rule 942100 (SQLi) from $attackerIp";
        } else if (sId.contains('nginx') || sId.contains('httpd')) {
          log =
              'GET /../../../../etc/shadow HTTP/1.1 403 Forbidden - path traversal signature from $attackerIp';
        } else if (sId.contains('ssh')) {
          log =
              'Bad protocol version identification from $attackerIp port $port (Malicious SSH Fuzzer Payload)';
        } else {
          log = 'Buffer overflow probe blocked on port $port from $attackerIp (Signature CVE-2024-EXPLOIT)';
        }
      } else {
        // Brute Force
        if (sId.contains('ssh')) {
          log = 'Failed password for invalid user $user from $attackerIp port $port ssh2';
        } else if (sId.contains('mysql') || sId.contains('mariadb')) {
          log = "Access denied for user '$user'@'$attackerIp' (using password: YES)";
        } else if (sId.contains('nginx') || sId.contains('httpd')) {
          log = "POST /login HTTP/1.1 401 Unauthorized - invalid password for '$user', client: $attackerIp";
        } else if (sId.contains('redis')) {
          log = 'ERR AUTH <password> failed for client $attackerIp:$port - invalid password';
        } else if (sId.contains('dovecot')) {
          log = 'auth-worker: sql($user,$attackerIp): Password mismatch (attempt ${i + 1})';
        } else if (sId.contains('pure-ftpd')) {
          log = '(?@$attackerIp) [WARNING] Authentication failed for user [$user]';
        } else {
          log = "Failed authentication attempt for '$user' from $attackerIp on $serviceId";
        }
      }
      logs.add(log);
    }

    return logs;
  }
}
