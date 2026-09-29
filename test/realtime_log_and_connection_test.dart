import 'package:flutter_test/flutter_test.dart';
import 'package:aegis/models/auth_event.dart';
import 'package:aegis/models/server_profile.dart';
import 'package:aegis/models/security_policy.dart';
import 'package:aegis/services/log_parser_service.dart';
import 'package:aegis/services/ssh_service.dart';
import 'package:aegis/providers/telemetry_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogParserService Comprehensive Tests', () {
    late LogParserService parser;

    setUp(() {
      parser = LogParserService();
    });

    test('Parses standard OpenSSH Accepted Publickey login', () {
      const line = 'Sep 29 05:32:10 server sshd[1234]: Accepted publickey for cethokaryo from 103.142.21.195 port 42810 ssh2: ED25519';
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'sshd');
      expect(event.user, 'cethokaryo');
      expect(event.clientIp, '103.142.21.195');
      expect(event.status, EventStatus.success);
      expect(event.severity, EventSeverity.info);
      expect(event.failureReason, contains('publickey'));
    });

    test('Parses 2FA Keyboard-Interactive / PAM Accepted login', () {
      const line = 'Sep 29 05:32:15 server sshd[4567]: Accepted keyboard-interactive/pam for wito_general from 182.1.200.42 port 50123 ssh2';
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'sshd');
      expect(event.user, 'wito_general');
      expect(event.clientIp, '182.1.200.42');
      expect(event.status, EventStatus.success);
    });

    test('Parses OpenSSH Failed Password for invalid user probe', () {
      const line = 'Sep 29 05:32:20 server sshd[1235]: Failed password for invalid user admin from 194.26.29.112 port 54321 ssh2';
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'sshd');
      expect(event.user, 'admin');
      expect(event.clientIp, '194.26.29.112');
      expect(event.status, EventStatus.failed);
      expect(event.severity, EventSeverity.critical);
      expect(event.riskScore, greaterThanOrEqualTo(85));
    });

    test('Parses PAM unix authentication failure in syslog', () {
      const line = 'Sep 29 05:32:25 server sshd[1238]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=91.240.118.2  user=root';
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'sshd');
      expect(event.user, 'root');
      expect(event.clientIp, '91.240.118.2');
      expect(event.status, EventStatus.failed);
      expect(event.severity, EventSeverity.critical);
    });

    test('Parses MySQL Access Denied with ISO timestamp', () {
      const line = "2026-09-29 05:32:30 120 [Note] Access denied for user 'root'@'185.220.101.5' (using password: YES)";
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'mysqld');
      expect(event.user, 'root');
      expect(event.clientIp, '185.220.101.5');
      expect(event.status, EventStatus.failed);
      expect(event.severity, EventSeverity.critical);
      expect(event.failureReason, contains('Access denied'));
    });

    test('Parses Fail2ban Ban and Unban actions', () {
      const banLine = '2026-09-29 05:32:40,123 fail2ban.actions [5678]: NOTICE [sshd] Ban 45.154.255.88';
      final banEvent = parser.parseLine(banLine, 'srv_test');

      expect(banEvent, isNotNull);
      expect(banEvent!.service, 'sshd');
      expect(banEvent.clientIp, '45.154.255.88');
      expect(banEvent.status, EventStatus.blocked);
      expect(banEvent.failureReason, contains('Blocked by Fail2ban'));

      const unbanLine = '2026-09-29 05:35:40,123 fail2ban.actions [5678]: NOTICE [sshd] Unban 45.154.255.88';
      final unbanEvent = parser.parseLine(unbanLine, 'srv_test');

      expect(unbanEvent, isNotNull);
      expect(unbanEvent!.status, EventStatus.success);
      expect(unbanEvent.failureReason, contains('Unbanned by Fail2ban'));
    });

    test('parseLines deduplicates identical log lines within batch', () {
      final lines = [
        'Sep 29 05:32:10 server sshd[1234]: Accepted publickey for cethokaryo from 103.142.21.195 port 42810 ssh2: ED25519',
        'Sep 29 05:32:10 server sshd[1234]: Accepted publickey for cethokaryo from 103.142.21.195 port 42810 ssh2: ED25519',
        "2026-09-29 05:32:30 120 [Note] Access denied for user 'root'@'185.220.101.5' (using password: YES)",
      ];

      final results = parser.parseLines(lines, 'srv_test');
      expect(results.length, 2);
    });
  });

  group('SshService Connection Pool Tests', () {
    late SshService service;

    setUp(() {
      service = SshService();
    });

    test('Initially server has isConnected false', () {
      expect(service.isConnected('srv_dummy_test'), isFalse);
    });

    test('Disconnecting un-cached server completes safely without throwing', () async {
      await expectLater(service.disconnect('srv_nonexistent'), completes);
      await expectLater(service.closeAll(), completes);
    });
  });

  group('TelemetryProvider Batch Ingestion Tests', () {
    late TelemetryProvider telemetry;
    late SecurityPolicy policy;

    setUp(() {
      telemetry = TelemetryProvider();
      policy = const SecurityPolicy(
        serverId: 'srv_test',
        trustedIps: ['127.0.0.1', '103.142.21.195'],
        maxFailedAttemptsThreshold: 3,
        timeWindowSeconds: 120,
      );
    });

    test('ingestBatchEvents successfully ingests and deduplicates real server events', () {
      final now = DateTime.now();
      final ev1 = AuthEvent(
        id: 'ev-1',
        serverId: 'srv_test',
        service: 'sshd',
        timestamp: now,
        clientIp: '198.51.100.99',
        user: 'root',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        rawLog: 'Sep 29 05:00:00 Failed password for root from 198.51.100.99',
      );

      final ev2 = AuthEvent(
        id: 'ev-2',
        serverId: 'srv_test',
        service: 'sshd',
        timestamp: now.add(const Duration(seconds: 1)),
        clientIp: '198.51.100.99',
        user: 'root',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        rawLog: 'Sep 29 05:00:01 Failed password for root from 198.51.100.99',
      );

      telemetry.ingestBatchEvents([ev1, ev2], policy);

      final matching = telemetry.allEvents.where((e) => e.clientIp == '198.51.100.99').toList();
      expect(matching.length, 2);
      expect(telemetry.getAttemptCount('198.51.100.99'), 2);

      // Re-ingest same batch -> deduplication should prevent count increase
      telemetry.ingestBatchEvents([ev1, ev2], policy);
      final matchingAfter = telemetry.allEvents.where((e) => e.clientIp == '198.51.100.99').toList();
      expect(matchingAfter.length, 2);
      expect(telemetry.getAttemptCount('198.51.100.99'), 2);
    });
  });
}
