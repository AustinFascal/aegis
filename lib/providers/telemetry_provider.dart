import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/auth_event.dart';
import '../models/server_metrics.dart';
import '../models/security_policy.dart';
import '../services/anomaly_detection_engine.dart';
import '../services/notification_service.dart';

class TelemetryProvider extends ChangeNotifier {
  final AnomalyDetectionEngine _anomalyEngine = AnomalyDetectionEngine();
  final NotificationService _notificationService = NotificationService();
  final Map<String, int> _ipAttemptCounts = {};
  final Map<String, List<String>> _ipEvidenceLogs = {};

  /// Returns total attempt frequency for the specified IP, backed by real evidence logs
  int getAttemptCount(String ip, {AuthEvent? fallbackEvent}) {
    final evidence = getEvidenceLogsForIp(ip, fallbackEvent: fallbackEvent);
    if (evidence.isNotEmpty) {
      return evidence.length;
    }
    if (_ipAttemptCounts.containsKey(ip) && _ipAttemptCounts[ip]! > 0) {
      return _ipAttemptCounts[ip]!;
    }
    if (fallbackEvent != null && fallbackEvent.clientIp == ip && fallbackEvent.attemptCount > 0) {
      return fallbackEvent.attemptCount;
    }
    final matches = _events.where((e) => e.clientIp == ip);
    if (matches.isNotEmpty) {
      return matches.first.attemptCount;
    }
    return 1;
  }

  /// Returns all log entries recorded as evidence for this IP (from latest to older)
  List<String> getEvidenceLogsForIp(String ip, {AuthEvent? fallbackEvent}) {
    final results = <String>[];
    if (_ipEvidenceLogs.containsKey(ip)) {
      results.addAll(_ipEvidenceLogs[ip]!);
    }
    for (final ev in _events.where((e) => e.clientIp == ip)) {
      if (ev.evidenceLogs.isNotEmpty) {
        for (final log in ev.evidenceLogs) {
          if (!results.contains(log)) {
            results.add(log);
          }
        }
      } else if (ev.rawLog != null && ev.rawLog!.isNotEmpty && !results.contains(ev.rawLog!)) {
        results.add(ev.rawLog!);
      }
    }
    if (fallbackEvent != null && fallbackEvent.clientIp == ip) {
      for (final log in fallbackEvent.allEvidenceLogs) {
        if (!results.contains(log)) {
          results.add(log);
        }
      }
    }
    return results;
  }

  /// Ingests external server evidence logs (e.g. from SSH grep on remote server)
  void addEvidenceLogs(String ip, List<String> logs) {
    if (logs.isEmpty) return;
    final existing = _ipEvidenceLogs[ip] ?? [];
    final updated = List<String>.from(existing);
    for (final l in logs) {
      final clean = l.trim();
      if (clean.isNotEmpty && !updated.contains(clean)) {
        updated.add(clean);
      }
    }
    _ipEvidenceLogs[ip] = updated;
    _ipAttemptCounts[ip] = updated.length;

    for (int i = 0; i < _events.length; i++) {
      if (_events[i].clientIp == ip) {
        _events[i] = _events[i].copyWith(
          attemptCount: updated.length,
          evidenceLogs: updated,
        );
      }
    }
    notifyListeners();
  }

  List<AuthEvent> _events = [];
  String _serviceFilter = 'all'; // 'all', 'mysqld', 'sshd'
  String _statusFilter = 'all'; // 'all', 'failed', 'unknown', 'success'
  String _searchQuery = '';
  bool _isLiveMonitoring = true;
  Timer? _liveSimulationTimer;

  List<AuthEvent> get allEvents {
    final list = List<AuthEvent>.from(_events);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(list);
  }
  String get serviceFilter => _serviceFilter;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  bool get isLiveMonitoring => _isLiveMonitoring;

  List<AuthEvent> get filteredEvents {
    final list = _events.where((event) {
      // 1. Service filter
      if (_serviceFilter != 'all' && !event.service.toLowerCase().contains(_serviceFilter.toLowerCase())) {
        return false;
      }
      // 2. Status filter
      if (_statusFilter == 'failed' && event.status != EventStatus.failed) {
        return false;
      }
      if (_statusFilter == 'unknown' && !event.isUnknownPerson) {
        return false;
      }
      if (_statusFilter == 'success' && event.status != EventStatus.success) {
        return false;
      }
      // 3. Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchIp = event.clientIp.toLowerCase().contains(query);
        final matchUser = event.user.toLowerCase().contains(query);
        final matchReason =
            (event.failureReason ?? '').toLowerCase().contains(query);
        if (!matchIp && !matchUser && !matchReason) {
          return false;
        }
      }
      return true;
    }).toList();
    // Sort descending: from latest to older
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  ServerMetrics get metrics => _computeMetricsForEvents(_events);

  ServerMetrics getMetricsForServer(String? serverId) {
    if (serverId == null || serverId.isEmpty) {
      return const ServerMetrics(
        totalAttempts24h: 0,
        failedAttempts24h: 0,
        unknownPersonAttempts24h: 0,
        blockedCount: 0,
        integrityScore: 100,
        serviceDistribution: {},
        targetedUsers: {},
        hourlyTrend: [],
      );
    }
    final serverEvents = _events.where((e) => e.serverId == serverId).toList();
    return _computeMetricsForEvents(serverEvents);
  }

  ServerMetrics _computeMetricsForEvents(List<AuthEvent> sourceEvents) {
    final now = DateTime.now();
    // Rolling 24-hour window: strictly events occurring in the previous 24 hours back from now
    final windowStart24h = now.subtract(const Duration(hours: 24));

    final events24h = sourceEvents.where((e) {
      return !e.timestamp.isBefore(windowStart24h) && !e.timestamp.isAfter(now);
    }).toList();

    int total = events24h.length;
    int failed = 0;
    int unknown = 0;
    int blocked = 0;
    final Map<String, int> services = {};
    final Map<String, int> users = {};

    for (final e in events24h) {
      if (e.status == EventStatus.failed) failed++;
      if (e.isUnknownPerson) unknown++;
      if (e.status == EventStatus.blocked) blocked++;

      services[e.service] = (services[e.service] ?? 0) + 1;
      users[e.user] = (users[e.user] ?? 0) + 1;
    }

    // Chronological rolling 24-hour hourly trend:
    final currentHourStart = DateTime(now.year, now.month, now.day, now.hour);
    final List<TimeSeriesPoint> trend = [];

    for (int i = 0; i < 24; i++) {
      final bucketStart = currentHourStart.subtract(Duration(hours: 23 - i));
      final bucketEnd = bucketStart.add(const Duration(hours: 1));

      final bucketEvents = events24h.where((e) {
        return (e.timestamp.isAfter(bucketStart) || e.timestamp.isAtSameMomentAs(bucketStart)) &&
               e.timestamp.isBefore(bucketEnd);
      }).toList();

      final hourLabel = '${bucketStart.hour.toString().padLeft(2, '0')}:00';

      trend.add(
        TimeSeriesPoint(
          hour: i,
          clockHour: bucketStart.hour,
          label: hourLabel,
          timestamp: bucketStart,
          successCount: bucketEvents.where((x) => x.status == EventStatus.success).length,
          failedCount: bucketEvents.where((x) => x.status == EventStatus.failed).length,
          blockedCount: bucketEvents.where((x) => x.status == EventStatus.blocked).length,
        ),
      );
    }

    // Integrity score calculation based strictly on the rolling 24-hour window
    int score = 100;
    score -= (failed * 2);
    score -= (unknown * 15);
    if (score < 10) score = 10;

    return ServerMetrics(
      totalAttempts24h: total,
      failedAttempts24h: failed,
      unknownPersonAttempts24h: unknown,
      blockedCount: blocked,
      integrityScore: score,
      serviceDistribution: services,
      targetedUsers: users,
      hourlyTrend: trend,
    );
  }

  void clearEventsForServer(String serverId) {
    _events.removeWhere((e) => e.serverId == serverId);
    final remainingIps = _events.map((e) => e.clientIp).toSet();
    _ipAttemptCounts.removeWhere((ip, _) => !remainingIps.contains(ip));
    _ipEvidenceLogs.removeWhere((ip, _) => !remainingIps.contains(ip));
    notifyListeners();
  }

  void clearAll() {
    _events.clear();
    _ipAttemptCounts.clear();
    _ipEvidenceLogs.clear();
    _liveSimulationTimer?.cancel();
    notifyListeners();
  }

  TelemetryProvider() {
    _seedHistoricalEvents();
    _startLiveMonitoringLoop();
  }

  void setServiceFilter(String filter) {
    _serviceFilter = filter;
    notifyListeners();
  }

  void setStatusFilter(String filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> refreshTelemetry() async {
    await Future.delayed(const Duration(milliseconds: 500));
    notifyListeners();
  }

  void toggleLiveMonitoring() {
    _isLiveMonitoring = !_isLiveMonitoring;
    if (_isLiveMonitoring) {
      _startLiveMonitoringLoop();
    } else {
      _liveSimulationTimer?.cancel();
    }
    notifyListeners();
  }

  void ingestEvent(AuthEvent rawEvent, SecurityPolicy policy) {
    final result = _anomalyEngine.evaluate(
      event: rawEvent,
      policy: policy,
    );

    final clientIp = rawEvent.clientIp;
    final existingLogs = _ipEvidenceLogs[clientIp] ?? [];
    final updatedEvidence = List<String>.from(existingLogs);
    if (rawEvent.rawLog != null && rawEvent.rawLog!.isNotEmpty && !updatedEvidence.contains(rawEvent.rawLog)) {
      updatedEvidence.insert(0, rawEvent.rawLog!);
    }
    for (final l in rawEvent.evidenceLogs) {
      if (!updatedEvidence.contains(l)) {
        updatedEvidence.add(l);
      }
    }
    _ipEvidenceLogs[clientIp] = updatedEvidence;

    final currentCount = updatedEvidence.isNotEmpty
        ? updatedEvidence.length
        : ((_ipAttemptCounts[clientIp] ?? (rawEvent.attemptCount > 1 ? rawEvent.attemptCount : 0)) + 1);
    _ipAttemptCounts[clientIp] = currentCount;

    final eventWithCount = result.event.copyWith(
      attemptCount: currentCount,
      evidenceLogs: updatedEvidence,
    );

    _events.insert(0, eventWithCount);
    _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Synchronize all instances of clientIp in memory with new attempt count and evidence
    for (int i = 0; i < _events.length; i++) {
      if (_events[i].clientIp == clientIp) {
        _events[i] = _events[i].copyWith(
          attemptCount: currentCount,
          evidenceLogs: updatedEvidence,
        );
      }
    }

    // Keep memory footprint bounded (max 500 events)
    if (_events.length > 500) {
      _events.removeLast();
    }

    if (result.shouldAlert) {
      _notificationService.showSecurityAlert(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: result.alertTitle,
        body: result.alertMessage,
        payload: result.event.clientIp,
        isCritical: result.event.severity == EventSeverity.critical,
      );
    }

    notifyListeners();
  }

  void _seedHistoricalEvents() {
    final now = DateTime.now();
    const uuid = Uuid();

    // 1. Root brute-force probe on MySQL: 14 attempts with authentic evidence logs
    final logs185 = List.generate(14, (i) {
      final sec = (32 * 60 + 1) - (i * 11);
      final m = (sec ~/ 60).toString().padLeft(2, '0');
      final s = (sec % 60).toString().padLeft(2, '0');
      final connId = 120 - i;
      return "2026-09-26 18:$m:$s $connId [Note] Access denied for user 'root'@'185.220.101.5' (using password: YES)";
    });

    // 2. Admin probe on MySQL: 8 attempts with authentic evidence logs
    final logs194 = List.generate(8, (i) {
      final sec = (27 * 60 + 14) - (i * 14);
      final m = (sec ~/ 60).toString().padLeft(2, '0');
      final s = (sec % 60).toString().padLeft(2, '0');
      final connId = 119 - i;
      return "2026-09-26 18:$m:$s $connId [Note] Access denied for user 'admin'@'194.26.29.112' (using password: YES)";
    });

    // 3. Authorized SSH public key: 2 logins
    final logs103 = [
      'Sep 26 18:16:42 server sshd[15402]: Accepted publickey for cethokaryo from 103.142.21.195 port 42810 ssh2: ED25519',
      'Sep 26 18:10:15 server sshd[15380]: Accepted publickey for cethokaryo from 103.142.21.195 port 42790 ssh2: ED25519',
    ];

    // 4. Unknown person login: 1 breach attempt
    final logs182 = [
      '2026-09-26 17:59:02 118 [Note] Connect cethokaryo_app@182.1.200.42 on db_klinik',
    ];

    // 5. Invalid user probe on SSH: 12 attempts with authentic evidence logs
    final logs45 = List.generate(12, (i) {
      final sec = (22 * 60 + 18) - (i * 9);
      final m = (sec ~/ 60).toString().padLeft(2, '0');
      final s = (sec % 60).toString().padLeft(2, '0');
      final pid = 14101 - i;
      final port = 54100 + i;
      return "Sep 26 17:$m:$s server sshd[$pid]: Failed password for invalid user support from 45.154.255.88 port $port ssh2";
    });

    // 6. WAF SQLi probe on HTTP: 5 attempts with authentic evidence logs
    final logs198 = [
      r"198.51.100.77 - - [27/Sep/2026:05:42:10 +0700] POST /api/v1/auth?id=1 OR 1=1 403 218",
      r"198.51.100.77 - - [27/Sep/2026:05:42:04 +0700] POST /api/v1/auth?user=admin'-- 403 218",
      r"198.51.100.77 - - [27/Sep/2026:05:41:58 +0700] GET /api/v1/login?user=root' UNION SELECT null,null-- 403 218",
      r"198.51.100.77 - - [27/Sep/2026:05:41:49 +0700] POST /api/v1/token HTTP/1.1 403 218",
      r"198.51.100.77 - - [27/Sep/2026:05:41:35 +0700] GET /admin/config.php HTTP/1.1 403 218",
    ];

    // 7. Reverse proxy upstream traffic on Nginx: 3 logs
    final logs203 = [
      '203.0.113.44 - - [27/Sep/2026:05:05:22 +0700] "GET /api/gateway HTTP/2.0" 200 4096',
      '203.0.113.44 - - [27/Sep/2026:05:04:18 +0700] "GET /api/health HTTP/2.0" 200 512',
      '203.0.113.44 - - [27/Sep/2026:05:03:02 +0700] "POST /api/metrics HTTP/2.0" 200 1024',
    ];

    // 8. Dovecot IMAP password mismatch: 7 attempts with authentic evidence logs
    final logs91 = List.generate(7, (i) {
      final sec = (50 * 60 + 18) - (i * 18);
      final m = (sec ~/ 60).toString().padLeft(2, '0');
      final s = (sec % 60).toString().padLeft(2, '0');
      return "Sep 27 04:$m:$s server dovecot: imap-login: Disconnected (auth failed, 1 attempts): user=<admin@cethokaryo.id>, rip=91.240.118.2";
    });

    // 9. Pure-FTPd anonymous auth failure: 11 attempts with authentic evidence logs
    final logs193 = List.generate(11, (i) {
      final sec = (15 * 60 + 32) - (i * 7);
      final m = (sec ~/ 60).toString().padLeft(2, '0');
      final s = (sec % 60).toString().padLeft(2, '0');
      return "Sep 27 04:$m:$s server pure-ftpd: (?@193.106.191.8) [WARNING] Authentication failed for user [anonymous]";
    });

    // 10. Localhost socket connection
    final logs127 = [
      '${now.subtract(const Duration(hours: 2)).toIso8601String().substring(0, 19).replaceAll("T", " ")} 125 [Note] Connect cethokaryo@localhost on db_main',
    ];

    _events = [
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'mysqld',
        timestamp: DateTime(2026, 9, 26, 18, 32, 1),
        clientIp: '185.220.101.5',
        user: 'root',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 92,
        attemptCount: logs185.length,
        evidenceLogs: logs185,
        failureReason: 'Access denied for user \'root\'@\'185.220.101.5\' (using password: YES)',
        country: 'RU',
        city: 'Moscow',
        rawLog: logs185.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'mysqld',
        timestamp: DateTime(2026, 9, 26, 18, 27, 14),
        clientIp: '194.26.29.112',
        user: 'admin',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 88,
        attemptCount: logs194.length,
        evidenceLogs: logs194,
        failureReason: 'Access denied for user \'admin\'@\'194.26.29.112\' (using password: YES)',
        country: 'NL',
        city: 'Amsterdam',
        rawLog: logs194.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'sshd',
        timestamp: DateTime(2026, 9, 26, 18, 16, 42),
        clientIp: '103.142.21.195',
        user: 'cethokaryo',
        status: EventStatus.success,
        severity: EventSeverity.info,
        riskScore: 5,
        attemptCount: logs103.length,
        evidenceLogs: logs103,
        isUnknownPerson: false,
        failureReason: 'Accepted publickey (ED25519)',
        country: 'ID',
        city: 'Jakarta',
        rawLog: logs103.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'mysqld',
        timestamp: DateTime(2026, 9, 26, 17, 59, 2),
        clientIp: '182.1.200.42',
        user: 'cethokaryo_app',
        status: EventStatus.success,
        severity: EventSeverity.critical,
        riskScore: 98,
        attemptCount: logs182.length,
        evidenceLogs: logs182,
        isUnknownPerson: true,
        failureReason: 'UNKNOWN PERSON: Login from untrusted IP',
        country: 'SG',
        city: 'Singapore',
        rawLog: logs182.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'sshd',
        timestamp: DateTime(2026, 9, 26, 17, 22, 18),
        clientIp: '45.154.255.88',
        user: 'support',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 90,
        attemptCount: logs45.length,
        evidenceLogs: logs45,
        failureReason: 'Failed password for invalid user support',
        country: 'DE',
        city: 'Frankfurt',
        rawLog: logs45.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'httpd',
        timestamp: DateTime(2026, 9, 27, 5, 42, 10),
        clientIp: '198.51.100.77',
        user: 'guest',
        status: EventStatus.failed,
        severity: EventSeverity.warning,
        riskScore: 72,
        attemptCount: logs198.length,
        evidenceLogs: logs198,
        failureReason: '403 Forbidden: WAF detected SQLi attempt on /api/v1/auth',
        country: 'US',
        city: 'Ashburn',
        rawLog: logs198.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'nginx',
        timestamp: DateTime(2026, 9, 27, 5, 5, 22),
        clientIp: '203.0.113.44',
        user: 'system',
        status: EventStatus.success,
        severity: EventSeverity.info,
        riskScore: 8,
        attemptCount: logs203.length,
        evidenceLogs: logs203,
        failureReason: 'HTTP 200 OK reverse proxy upstream /api/gateway',
        country: 'ID',
        city: 'Surabaya',
        rawLog: logs203.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'dovecot',
        timestamp: DateTime(2026, 9, 27, 4, 50, 18),
        clientIp: '91.240.118.2',
        user: 'admin@cethokaryo.id',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 85,
        attemptCount: logs91.length,
        evidenceLogs: logs91,
        failureReason: 'IMAP authentication failed (password mismatch)',
        country: 'RO',
        city: 'Bucharest',
        rawLog: logs91.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'pure-ftpd',
        timestamp: DateTime(2026, 9, 27, 4, 15, 32),
        clientIp: '193.106.191.8',
        user: 'anonymous',
        status: EventStatus.failed,
        severity: EventSeverity.warning,
        riskScore: 65,
        attemptCount: logs193.length,
        evidenceLogs: logs193,
        failureReason: 'FTP Anonymous login rejected',
        country: 'PL',
        city: 'Warsaw',
        rawLog: logs193.first,
      ),
      AuthEvent(
        id: uuid.v4(),
        serverId: 'srv_rumahweb_01',
        service: 'mysqld',
        timestamp: now.subtract(const Duration(hours: 2)),
        clientIp: '127.0.0.1',
        user: 'cethokaryo',
        status: EventStatus.success,
        severity: EventSeverity.info,
        riskScore: 0,
        attemptCount: logs127.length,
        evidenceLogs: logs127,
        isUnknownPerson: false,
        failureReason: 'Local socket connection on db_main',
        country: 'ID',
        city: 'Localhost',
        rawLog: logs127.first,
      ),
    ];

    // Ensure all seed events are strictly sorted descending (latest to older)
    _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final e in _events) {
      _ipAttemptCounts[e.clientIp] = e.evidenceLogs.isNotEmpty ? e.evidenceLogs.length : e.attemptCount;
      _ipEvidenceLogs[e.clientIp] = List<String>.from(e.evidenceLogs);
    }
  }

  void _startLiveMonitoringLoop() {
    _liveSimulationTimer?.cancel();
    // Refresh rolling 24-hour window and simulate telemetry tail every 30 seconds
    _liveSimulationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isLiveMonitoring) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _liveSimulationTimer?.cancel();
    super.dispose();
  }
}
