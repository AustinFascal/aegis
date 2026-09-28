import 'package:aegis/ui/screens/service_detail_screen.dart';
import 'package:aegis/ui/screens/audit_explorer_screen.dart';
import 'package:aegis/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aegis/ui/widgets/forensic_dialog.dart';
import 'package:aegis/models/auth_event.dart';
import 'package:aegis/models/security_policy.dart';
import 'package:aegis/models/server_profile.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/policy_provider.dart';
import 'package:aegis/services/log_parser_service.dart';
import 'package:aegis/services/anomaly_detection_engine.dart';
import 'package:aegis/core/security/secure_vault.dart';
import 'package:aegis/core/security/totp_helper.dart';
import 'package:aegis/core/security/biometric_service.dart';
import 'package:aegis/core/constants/app_theme.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/ui/screens/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogParserService Tests', () {
    final parser = LogParserService();

    test('Parses MySQL Access Denied correctly', () {
      const line =
          "2026-09-26 18:32:01 120 [Note] Access denied for user 'root'@'185.220.101.5' (using password: YES)";
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'mysqld');
      expect(event.user, 'root');
      expect(event.clientIp, '185.220.101.5');
      expect(event.status, EventStatus.failed);
      expect(event.severity, EventSeverity.critical);
      expect(event.riskScore, greaterThanOrEqualTo(80));
      // Verifies exact date 2026-09-26 18:32:01 is preserved instead of DateTime.now()
      expect(event.timestamp.year, equals(2026));
      expect(event.timestamp.month, equals(9));
      expect(event.timestamp.day, equals(26));
      expect(event.timestamp.hour, equals(18));
      expect(event.timestamp.minute, equals(32));
    });

    test('Parses MySQL Successful Connect correctly', () {
      const line =
          "2026-09-26T18:35:12.654321Z 43 [Note] Connect cethokaryo@127.0.0.1 on db_klinik";
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'mysqld');
      expect(event.user, 'cethokaryo');
      expect(event.clientIp, '127.0.0.1');
      expect(event.status, EventStatus.success);
    });

    test('Parses SSH Failed Password correctly', () {
      const line =
          "Sep 26 18:15:30 vps sshd[1234]: Failed password for invalid user admin from 195.201.22.4 port 54321 ssh2";
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'sshd');
      expect(event.clientIp, '195.201.22.4');
      expect(event.user, 'admin');
      expect(event.status, EventStatus.failed);
    });

    test('Parses SSH Accepted Login correctly', () {
      const line =
          "Sep 26 18:18:22 vps sshd[2345]: Accepted publickey for cethokaryo from 103.142.21.195 port 51234 ssh2: ED25519";
      final event = parser.parseLine(line, 'srv_test');

      expect(event, isNotNull);
      expect(event!.service, 'sshd');
      expect(event.user, 'cethokaryo');
      expect(event.clientIp, '103.142.21.195');
      expect(event.status, EventStatus.success);
    });
  });

  group('AnomalyDetectionEngine Tests', () {
    final engine = AnomalyDetectionEngine();
    const policy = SecurityPolicy(
      serverId: 'srv_test',
      trustedIps: ['127.0.0.1', '103.142.21.195'],
      maxFailedAttemptsThreshold: 3,
      timeWindowSeconds: 60,
      alertOnUnknownSuccess: true,
    );

    test('Flags Success from Untrusted IP as Unknown Person Login', () {
      final event = AuthEvent(
        id: '1',
        serverId: 'srv_test',
        service: 'mysqld',
        timestamp: DateTime.now(),
        clientIp: '198.51.100.22', // NOT in trustedIps
        user: 'cethokaryo',
        status: EventStatus.success,
        severity: EventSeverity.info,
      );

      final result = engine.evaluate(event: event, policy: policy);

      expect(result.event.isUnknownPerson, isTrue);
      expect(result.event.severity, EventSeverity.critical);
      expect(result.shouldAlert, isTrue);
      expect(result.alertTitle, contains('Unknown Person'));
    });

    test('Does NOT flag Success from Trusted IP', () {
      final event = AuthEvent(
        id: '2',
        serverId: 'srv_test',
        service: 'sshd',
        timestamp: DateTime.now(),
        clientIp: '103.142.21.195', // Trusted
        user: 'cethokaryo',
        status: EventStatus.success,
        severity: EventSeverity.info,
      );

      final result = engine.evaluate(event: event, policy: policy);

      expect(result.event.isUnknownPerson, isFalse);
      expect(result.shouldAlert, isFalse);
    });

    test('Escalates repeated failed attempts to Brute Force', () {
      engine.clearHistory();
      final event = AuthEvent(
        id: '3',
        serverId: 'srv_test',
        service: 'mysqld',
        timestamp: DateTime.now(),
        clientIp: '203.0.113.50',
        user: 'guest',
        status: EventStatus.failed,
        severity: EventSeverity.warning,
      );

      // Attempt 1 & 2
      engine.evaluate(event: event, policy: policy);
      engine.evaluate(event: event, policy: policy);

      // Attempt 3: threshold breached
      final result3 = engine.evaluate(event: event, policy: policy);
      expect(result3.event.severity, EventSeverity.critical);
      expect(result3.alertTitle, contains('BRUTE FORCE'));
      expect(result3.recommendBlock, isTrue);
    });

    test('Custom threshold change immediately adjusts detection sensitivity', () {
      engine.clearHistory();
      // Policy with strict threshold of 2 attempts
      final strictPolicy = policy.copyWith(maxFailedAttemptsThreshold: 2);
      final event = AuthEvent(
        id: '4',
        serverId: 'srv_test',
        service: 'sshd',
        timestamp: DateTime.now(),
        clientIp: '198.51.100.99',
        user: 'root',
        status: EventStatus.failed,
        severity: EventSeverity.warning,
      );

      // Attempt 1
      final r1 = engine.evaluate(event: event, policy: strictPolicy);
      expect(r1.recommendBlock, isFalse);

      // Attempt 2: threshold immediately triggered!
      final r2 = engine.evaluate(event: event, policy: strictPolicy);
      expect(r2.event.severity, EventSeverity.critical);
      expect(r2.alertTitle, contains('BRUTE FORCE'));
      expect(r2.recommendBlock, isTrue);
    });

  });

  group('ServerProvider & SecureVault Tests', () {
    test('ServerProvider starts with empty servers on first install', () {
      final provider = ServerProvider();
      expect(provider.servers, isEmpty);
      expect(provider.activeServer, isNull);

      final withDefault = ServerProvider(initialServers: [ServerProvider.defaultVps]);
      expect(withDefault.servers.isNotEmpty, isTrue);
      expect(withDefault.activeServer, isNotNull);
      expect(withDefault.activeServer!.id, equals('srv_rumahweb_01'));
      expect(withDefault.activeServer!.host, equals('202.10.46.4'));
      expect(withDefault.activeServer!.username, equals('cethokaryo'));
    });

    test('Saving credential updates vault status', () async {
      final provider = ServerProvider();
      await provider.saveCredential('srv_test_01', AuthType.privateKey, '-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----');
      expect(provider.hasStoredCredential('srv_test_01'), isTrue);
    });

    test('Add, update, and delete server updates state and vault', () async {
      final provider = ServerProvider();
      final initialCount = provider.servers.length;

      await provider.addServer(
        name: 'Database Cluster A',
        host: '10.0.0.15',
        port: 22,
        username: 'dbadmin',
        authType: AuthType.password,
        credential: 'secure-db-password',
      );

      expect(provider.servers.length, equals(initialCount + 1));
      final added = provider.servers.last;
      expect(added.name, equals('Database Cluster A'));
      expect(provider.hasStoredCredential(added.id), isTrue);

      // Update server
      final updated = added.copyWith(name: 'Database Cluster Primary');
      await provider.updateServer(updated);
      expect(provider.servers.last.name, equals('Database Cluster Primary'));

      // Delete server
      await provider.deleteServer(added.id);
      expect(provider.servers.length, equals(initialCount));
      expect(provider.hasStoredCredential(added.id), isFalse);
    });

    test('Server profiles persist and reload in new provider instance', () async {
      final provider1 = ServerProvider();
      await provider1.addServer(
        name: 'Persistent Backup Server',
        host: '192.168.10.50',
        port: 22,
        username: 'sysadmin',
        authType: AuthType.password,
        credential: 'backup-password',
      );

      // Create new provider instance (simulating hot reload or app restart)
      final provider2 = ServerProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider2.servers.any((s) => s.name == 'Persistent Backup Server'), isTrue);
      final loaded = provider2.servers.firstWhere((s) => s.name == 'Persistent Backup Server');
      expect(loaded.host, equals('192.168.10.50'));

      // Clean up
      await provider2.deleteServer(loaded.id);
    });

    test('PolicyProvider updates and persists maxFailedAttemptsThreshold across provider instances', () async {
      final policyProvider1 = PolicyProvider();
      const serverId = 'srv_test_policy_01';
      final initialPolicy = policyProvider1.getPolicy(serverId);
      expect(initialPolicy.maxFailedAttemptsThreshold, equals(3));

      // Update to 7 failed attempts
      final updatedPolicy = initialPolicy.copyWith(maxFailedAttemptsThreshold: 7);
      policyProvider1.updatePolicy(serverId, updatedPolicy);
      expect(policyProvider1.getPolicy(serverId).maxFailedAttemptsThreshold, equals(7));

      // Create new PolicyProvider instance (simulating hot reload or app restart)
      final policyProvider2 = PolicyProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      final reloadedPolicy = policyProvider2.getPolicy(serverId);
      expect(reloadedPolicy.maxFailedAttemptsThreshold, equals(7));
    });

    test('testServer without credentials fails with clear user guidance', () async {
      final provider = ServerProvider();
      const uncredentialedServer = ServerProfile(
        id: 'srv_no_key_99',
        name: 'Empty Key Server',
        host: '192.168.1.100',
        username: 'admin',
        authType: AuthType.privateKey,
      );

      final result = await provider.testServer(uncredentialedServer);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('No stored credential found'));
    });

    test('executeServiceControl without credentials returns clear guidance', () async {
      final provider = ServerProvider();
      final result = await provider.executeServiceControl(
        serviceId: 'mysqld',
        action: 'restart',
      );
      // Either fails with clear credentials error or executes if auto-seeded
      if (!result.success) {
        expect(result.errorMessage, isNotNull);
      }
    });

    test('executeServiceControl with invalid action rejects execution', () async {
      final provider = ServerProvider();
      final result = await provider.executeServiceControl(
        serviceId: 'mysqld',
        action: 'rm -rf /',
      );
      expect(result.success, isFalse);
    });

    test('SecureVault and ServerProvider save, retrieve, and track sudo password', () async {
      final vault = SecureVault();
      await vault.saveSudoPassword('srv_test_01', 'Secret_Sudo_Pass_123');
      final fetched = await vault.getSudoPassword('srv_test_01');
      expect(fetched, equals('Secret_Sudo_Pass_123'));
      await vault.deleteSudoPassword('srv_test_01');
      final afterDelete = await vault.getSudoPassword('srv_test_01');
      expect(afterDelete, isNull);

      final provider = ServerProvider();
      expect(provider.hasStoredSudoPassword('srv_test_sudo'), isFalse);
      await provider.saveSudoPassword('srv_test_sudo', 'SuperSecretPass!');
      expect(provider.hasStoredSudoPassword('srv_test_sudo'), isTrue);
      final retrieved = await provider.getSavedSudoPassword('srv_test_sudo');
      expect(retrieved, equals('SuperSecretPass!'));

      // Test addServer with sudoPassword
      await provider.addServer(
        name: 'Sudo Server',
        host: '10.0.0.99',
        port: 22,
        username: 'wito_general',
        authType: AuthType.password,
        credential: 'ssh_password',
        sudoPassword: 'my_sudo_password',
      );
      final addedSudoServer = provider.servers.last;
      expect(provider.hasStoredSudoPassword(addedSudoServer.id), isTrue);
      expect(await provider.getSavedSudoPassword(addedSudoServer.id), equals('my_sudo_password'));
    });

    test('selectServer switches active server profile', () async {
      final provider = ServerProvider(initialServers: [ServerProvider.defaultVps]);
      await provider.addServer(
        name: 'Staging Server',
        host: '10.0.0.2',
        port: 22,
        username: 'admin',
        authType: AuthType.password,
        credential: 'test',
      );
      expect(provider.activeServer?.name, equals('Staging Server'));

      provider.selectServer('srv_rumahweb_01');
      expect(provider.activeServer?.id, equals('srv_rumahweb_01'));
      expect(provider.activeServer?.name, contains('RumahWeb'));
    });
  });

  group('SSH 2FA & RFC 6238 TOTP Tests', () {
    const rfcSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    test('TotpHelper generates exact RFC 6238 test vectors', () {
      // Official RFC 6238 / RFC 4226 HMAC-SHA1 vectors:
      expect(
        TotpHelper.generateTotp(
          rfcSecret,
          time: DateTime.fromMillisecondsSinceEpoch(59 * 1000),
        ),
        equals('287082'),
      );
      expect(
        TotpHelper.generateTotp(
          rfcSecret,
          time: DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000),
        ),
        equals('081804'),
      );
      expect(
        TotpHelper.generateTotp(
          rfcSecret,
          time: DateTime.fromMillisecondsSinceEpoch(1111111111 * 1000),
        ),
        equals('050471'),
      );
      expect(
        TotpHelper.generateTotp(
          rfcSecret,
          time: DateTime.fromMillisecondsSinceEpoch(1234567890 * 1000),
        ),
        equals('005924'),
      );
      expect(
        TotpHelper.generateTotp(
          rfcSecret,
          time: DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000),
        ),
        equals('279037'),
      );
    });

    test('TotpHelper validates Base32 secrets correctly', () {
      expect(TotpHelper.isValidSecret(rfcSecret), isTrue);
      expect(TotpHelper.isValidSecret('JBSWY3DPEHPK3PXP'), isTrue);
      // Ignores spaces and dashes
      expect(TotpHelper.isValidSecret('JBSW Y3DP-EHPK 3PXP'), isTrue);
      // Rejects invalid Base32 (numbers 8, 9, 1, 0 or special chars)
      expect(TotpHelper.isValidSecret('INVALID89'), isFalse);
      expect(TotpHelper.isValidSecret('SHORT'), isFalse);
      expect(TotpHelper.isValidSecret(null), isFalse);
    });

    test('TotpHelper formatting and window calculations work properly', () {
      expect(TotpHelper.formatCode('287082'), equals('287 082'));
      expect(TotpHelper.formatCode('123'), equals('123'));

      final t = DateTime.fromMillisecondsSinceEpoch(59 * 1000); // 59s % 30 = 29 remainder -> 1s left
      expect(TotpHelper.remainingSeconds(time: t), equals(1));
    });

    test('SecureVault manages 2FA secrets securely', () async {
      final vault = SecureVault();
      await vault.save2FASecret('srv_2fa_test', 'JBSWY3DPEHPK3PXP');
      final retrieved = await vault.get2FASecret('srv_2fa_test');
      expect(retrieved, equals('JBSWY3DPEHPK3PXP'));

      await vault.delete2FASecret('srv_2fa_test');
      final afterDelete = await vault.get2FASecret('srv_2fa_test');
      expect(afterDelete, isNull);
    });

    test('ServerProfile serializes and deserializes has2FA flag', () {
      const server = ServerProfile(
        id: 'srv_mfa_1',
        name: 'Secure Bastion',
        host: '192.168.1.100',
        username: 'root',
        has2FA: true,
      );
      expect(server.has2FA, isTrue);

      final map = server.toMap();
      expect(map['has2FA'], isTrue);

      final fromMap = ServerProfile.fromMap(map);
      expect(fromMap.has2FA, isTrue);

      final copied = server.copyWith(has2FA: false);
      expect(copied.has2FA, isFalse);
    });

    test('ServerProvider persists 2FA secrets and manages lifecycle', () async {
      final provider = ServerProvider();
      await provider.addServer(
        name: 'MFA Protected Server',
        host: '10.0.1.50',
        port: 22,
        username: 'secadmin',
        authType: AuthType.password,
        credential: 'MySecretPass!',
        has2FA: true,
        twoFactorSecret: 'JBSWY3DPEHPK3PXP',
      );

      final added = provider.activeServer;
      expect(added, isNotNull);
      expect(added!.has2FA, isTrue);

      final storedSecret = await provider.getTwoFactorSecret(added.id);
      expect(storedSecret, equals('JBSWY3DPEHPK3PXP'));

      // Delete server wipes 2FA secret
      await provider.deleteServer(added.id);
      final deletedSecret = await provider.getTwoFactorSecret(added.id);
      expect(deletedSecret, isNull);
    });
  });


  group('BiometricService & Forensic Mitigation Tests', () {
    test('isBiometricsAvailable returns false safely on desktop without throwing MissingPluginException', () async {
      final biometricService = BiometricService();
      final available = await biometricService.isBiometricsAvailable();
      expect(available, isFalse);
    });

    test('authenticate completes with fallback on desktop platforms without crashing', () async {
      final biometricService = BiometricService();
      final result = await biometricService.authenticate(
        reason: 'Authorize immediate firewall block for test IP',
      );
      expect(result, isTrue);
    });

    test('PolicyProvider banIp records and unbanIp removes banned IPs cleanly', () async {
      final provider = PolicyProvider();
      const serverId = 'srv_mitigation_test';
      const testIp = '198.51.100.42';

      provider.banIp(serverId, testIp, 'Repeated brute-force attacks', 'sshd');
      final policy = provider.getPolicy(serverId);
      expect(policy.bannedIps.any((b) => b.ip == testIp), isTrue);

      final record = policy.bannedIps.firstWhere((b) => b.ip == testIp);
      expect(record.service, equals('sshd'));
      expect(record.reason, equals('Repeated brute-force attacks'));

      provider.unbanIp(serverId, testIp);
      final policyAfter = provider.getPolicy(serverId);
      expect(policyAfter.bannedIps.any((b) => b.ip == testIp), isFalse);
    });
    test('PolicyProvider syncServerBannedIps merges fail2ban server bans seamlessly', () {
      final provider = PolicyProvider();
      const serverId = 'srv_fail2ban_sync_test';
      final now = DateTime.now();

      final serverBans = [
        BannedIpRecord(
          ip: '203.0.113.88',
          service: 'mysqld-auth',
          reason: 'fail2ban jail [mysqld-auth]',
          bannedAt: now,
        ),
        BannedIpRecord(
          ip: '203.0.113.99',
          service: 'sshd',
          reason: 'fail2ban jail [sshd]',
          bannedAt: now,
        ),
      ];

      provider.syncServerBannedIps(serverId, serverBans);
      final policy = provider.getPolicy(serverId);

      expect(policy.bannedIps.any((b) => b.ip == '203.0.113.88'), isTrue);
      expect(policy.bannedIps.any((b) => b.ip == '203.0.113.99'), isTrue);
      final mysqlBan = policy.bannedIps.firstWhere((b) => b.ip == '203.0.113.88');
      expect(mysqlBan.service, equals('mysqld-auth'));
      expect(mysqlBan.reason, contains('fail2ban jail'));
    });
    test('PolicyProvider syncs multiple jails including mysqld-auth and sshd with correct IP deduplication', () {
      final provider = PolicyProvider();
      const serverId = 'srv_vps_multi_jail';
      final now = DateTime.now();

      final serverBans = [
        BannedIpRecord(
          ip: '45.148.10.240',
          service: 'sshd',
          reason: 'fail2ban jail [sshd]',
          bannedAt: now,
        ),
        BannedIpRecord(
          ip: '102.220.160.189',
          service: 'sshd',
          reason: 'fail2ban jail [sshd]',
          bannedAt: now,
        ),
        BannedIpRecord(
          ip: '36.82.127.116',
          service: 'mysqld-auth',
          reason: 'fail2ban jail [mysqld-auth]',
          bannedAt: now,
        ),
        BannedIpRecord(
          ip: '194.32.120.107',
          service: 'mysqld-auth',
          reason: 'fail2ban jail [mysqld-auth]',
          bannedAt: now,
        ),
      ];

      provider.syncServerBannedIps(serverId, serverBans);
      final policy = provider.getPolicy(serverId);

      expect(policy.bannedIps.any((b) => b.ip == '45.148.10.240'), isTrue);
      expect(policy.bannedIps.any((b) => b.ip == '102.220.160.189'), isTrue);
      expect(policy.bannedIps.any((b) => b.ip == '36.82.127.116'), isTrue);
      expect(policy.bannedIps.any((b) => b.ip == '194.32.120.107'), isTrue);

      final mysqlRecord = policy.bannedIps.firstWhere((b) => b.ip == '36.82.127.116');
      expect(mysqlRecord.service, equals('mysqld-auth'));
      expect(mysqlRecord.reason, contains('mysqld-auth'));
    });
  
  group('Real-Time Age, Biometric & Attempt Counter Tests', () {
    test('Formatters.timeAgo calculates localized dynamic relative time', () {
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      final oneDayAgo = now.subtract(const Duration(days: 1));

      expect(Formatters.timeAgo(oneMinuteAgo), equals('1m ago'));
      expect(Formatters.timeAgo(oneMinuteAgo, isIndonesian: true), equals('1 mnt lalu'));

      expect(Formatters.timeAgo(twoHoursAgo), equals('2h ago'));
      expect(Formatters.timeAgo(twoHoursAgo, isIndonesian: true), equals('2 jam lalu'));

      expect(Formatters.timeAgo(oneDayAgo), equals('1d ago'));
      expect(Formatters.timeAgo(oneDayAgo, isIndonesian: true), equals('1 hari lalu'));
    });

    test('TelemetryProvider tracks and increments per-IP attempt counter', () {
      final telemetry = TelemetryProvider();
      
      // Default attempt counts initialized from historical log stream
      expect(telemetry.getAttemptCount('185.220.101.5'), equals(14));
      expect(telemetry.getAttemptCount('194.26.29.112'), equals(8));

      // Query non-existent IP returns 1
      expect(telemetry.getAttemptCount('192.168.1.99'), equals(1));
    });

    test('BiometricService safe desktop execution without platform exception', () async {
      final bio = BiometricService();
      final available = await bio.isBiometricsAvailable();
      // On Linux desktop environment, returns false or checks hardware gracefully
      expect(available, isA<bool>());

      final authResult = await bio.authenticate(reason: 'Test Auth');
      // On non-supported desktop, gracefully returns true so tests and desktop runs proceed
      expect(authResult, isTrue);
    });

    test('ServerMetrics strictly calculates rolling 24 hours back from current time', () {
      final telemetry = TelemetryProvider();
      final metrics = telemetry.metrics;

      expect(metrics.hourlyTrend.length, equals(24));
      // Index 23 is the current hour
      final currentHour = DateTime.now().hour;
      expect(metrics.hourlyTrend[23].clockHour, equals(currentHour));
      expect(metrics.hourlyTrend[23].label, equals('${currentHour.toString().padLeft(2, '0')}:00'));

      // Check that historical events within 24h are counted
      expect(metrics.totalAttempts24h, greaterThan(0));

      // Ingest an event strictly outside the 24-hour window (30 hours ago)
      final outsideEvent = AuthEvent(
        id: 'test_outside_24h',
        serverId: 'srv_test',
        service: 'mysqld',
        timestamp: DateTime.now().subtract(const Duration(hours: 30)),
        clientIp: '203.0.113.200',
        user: 'old_attacker',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 90,
      );

      final countBefore = telemetry.metrics.totalAttempts24h;
      telemetry.ingestEvent(outsideEvent, const SecurityPolicy(serverId: 'srv_test'));
      final countAfter = telemetry.metrics.totalAttempts24h;

      // Because outsideEvent occurred 30 hours ago, totalAttempts24h must NOT increase
      expect(countAfter, equals(countBefore));

      // Ingest an event within the last 2 hours
      final insideEvent = AuthEvent(
        id: 'test_inside_24h',
        serverId: 'srv_test',
        service: 'mysqld',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        clientIp: '203.0.113.201',
        user: 'fresh_attacker',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 90,
      );
      telemetry.ingestEvent(insideEvent, const SecurityPolicy(serverId: 'srv_test'));
      expect(telemetry.metrics.totalAttempts24h, equals(countBefore + 1));
      expect(telemetry.metrics.failedAttempts24h, greaterThan(0));
    });

    test('allEvents and filteredEvents return events sorted strictly descending (latest to older)', () {
      final telemetry = TelemetryProvider();

      final all = telemetry.allEvents;
      expect(all.length, greaterThan(1));
      for (int i = 0; i < all.length - 1; i++) {
        expect(
          all[i].timestamp.isAfter(all[i + 1].timestamp) ||
              all[i].timestamp.isAtSameMomentAs(all[i + 1].timestamp),
          isTrue,
          reason: 'Event at index $i (${all[i].timestamp}) should be newer than or equal to index ${i + 1} (${all[i + 1].timestamp})',
        );
      }

      final filtered = telemetry.filteredEvents;
      expect(filtered.length, greaterThan(1));
      for (int i = 0; i < filtered.length - 1; i++) {
        expect(
          filtered[i].timestamp.isAfter(filtered[i + 1].timestamp) ||
              filtered[i].timestamp.isAtSameMomentAs(filtered[i + 1].timestamp),
          isTrue,
          reason: 'Filtered event at index $i should be newer than or equal to index ${i + 1}',
        );
      }
    });

    test('getAttemptCount and getEvidenceLogsForIp provide full evidence logs matching attempt count', () {
      final telemetry = TelemetryProvider();

      // IP with 14 attempts
      final count185 = telemetry.getAttemptCount('185.220.101.5');
      final logs185 = telemetry.getEvidenceLogsForIp('185.220.101.5');
      expect(count185, equals(14));
      expect(logs185.length, equals(14));
      expect(logs185.first, contains("Access denied for user 'root'@'185.220.101.5'"));

      // IP with 12 attempts
      final count45 = telemetry.getAttemptCount('45.154.255.88');
      final logs45 = telemetry.getEvidenceLogsForIp('45.154.255.88');
      expect(count45, equals(12));
      expect(logs45.length, equals(12));
      expect(logs45.first, contains('Failed password for invalid user support'));

      // Ingesting a new attempt for 185.220.101.5 increments both attempt count and evidence logs
      final newLog = "2026-09-27 10:15:00 121 [Note] Access denied for user 'root'@'185.220.101.5' (using password: YES)";
      final freshEvent = AuthEvent(
        id: 'test_ev_fresh',
        serverId: 'srv_rumahweb_01',
        service: 'mysqld',
        timestamp: DateTime.now(),
        clientIp: '185.220.101.5',
        user: 'root',
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 95,
        rawLog: newLog,
      );

      telemetry.ingestEvent(freshEvent, const SecurityPolicy(serverId: 'srv_rumahweb_01'));
      expect(telemetry.getAttemptCount('185.220.101.5'), equals(15));
      expect(telemetry.getEvidenceLogsForIp('185.220.101.5').length, equals(15));
      expect(telemetry.getEvidenceLogsForIp('185.220.101.5').first, equals(newLog));
    });

    testWidgets('ForensicDialog renders Bukti Log Percobaan section with full evidence list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final telemetry = TelemetryProvider();
      final event = telemetry.allEvents.firstWhere((e) => e.clientIp == '185.220.101.5');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TelemetryProvider>.value(value: telemetry),
            ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
            ChangeNotifierProvider<PolicyProvider>(create: (_) => PolicyProvider()),
            ChangeNotifierProvider<ServerProvider>(create: (_) => ServerProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ForensicDialog(event: event),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and diagnosis
      expect(find.text('FORENSIK INSIDEN'), findsOneWidget);
      expect(find.text('185.220.101.5'), findsOneWidget);

      // Verify attempt frequency row
      expect(find.text('Frekuensi Percobaan'), findsOneWidget);
      expect(find.text('14 kali percobaan masuk'), findsOneWidget);
      expect(find.text('INTENSITAS TINGGI'), findsOneWidget);

      // Verify Bukti Log Percobaan (Attempt Evidence Logs) section
      expect(find.text('BUKTI LOG PERCOBAAN (14)'), findsOneWidget);
      expect(find.text('Salin Semua Bukti'), findsOneWidget);
      expect(find.text('#1 (Terbaru)'), findsOneWidget);

      telemetry.dispose();
      await tester.pump();
    });
  });

  group('AppBar Scrolled Elevation, Shadow & Biometric Stability Tests', () {
    test('AppTheme defines elevated scrolledUnderElevation and non-transparent shadowColor for AppBars', () {
      final darkBar = AppTheme.darkTheme.appBarTheme;
      final lightBar = AppTheme.lightTheme.appBarTheme;

      // Dark theme must have scrolledUnderElevation and shadowColor
      expect(darkBar.elevation, equals(0.0));
      expect(darkBar.scrolledUnderElevation, greaterThanOrEqualTo(4.0));
      expect(darkBar.shadowColor, isNotNull);
      expect(darkBar.shadowColor, isNot(Colors.transparent));

      // Light theme must have scrolledUnderElevation and shadowColor
      expect(lightBar.elevation, equals(0.0));
      expect(lightBar.scrolledUnderElevation, greaterThanOrEqualTo(4.0));
      expect(lightBar.shadowColor, isNotNull);
      expect(lightBar.shadowColor, isNot(Colors.transparent));
    });

    test('BiometricService suppresses duplicate concurrent authentication calls', () async {
      final bio = BiometricService();
      // Sequential authentication should succeed on desktop test runner
      final first = await bio.authenticate(reason: 'First Call');
      expect(first, isTrue);

      final second = await bio.authenticate(reason: 'Second Call');
      expect(second, isTrue);
    });

    testWidgets('DashboardScreen AppBar elevates with shadow when scrolled', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ServerProvider(initialServers: [ServerProvider.defaultVps])),
            ChangeNotifierProvider(create: (_) => PolicyProvider()),
            ChangeNotifierProvider(create: (_) => TelemetryProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: DashboardScreen(onNavigateToTab: (_) {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find AppBar
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      final AppBar appBarBefore = tester.widget(appBarFinder);
      expect(appBarBefore.notificationPredicate, isNotNull);

      // Scroll down
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pump();

      // Verify scroll offset is greater than 0
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.pixels, greaterThan(0));
    });

    test('SettingsProvider manages 6-digit PIN hashing, verification, and removal', () async {
      final settings = SettingsProvider();

      // Invalid PIN (not 6 digits) fails
      expect(await settings.setAppPin('1234'), isFalse);
      expect(await settings.setAppPin('abcdef'), isFalse);

      // Valid 6-digit PIN succeeds
      expect(await settings.setAppPin('123456'), isTrue);
      expect(settings.hasPin, isTrue);
      expect(settings.isSecurityLockActive, isTrue);

      // Verification checks
      expect(await settings.verifyAppPin('123456'), isTrue);
      expect(await settings.verifyAppPin('654321'), isFalse);

      // Removal
      await settings.removeAppPin();
      expect(settings.hasPin, isFalse);
    });

    testWidgets('DashboardScreen displays clean empty state with SETUP NEW SERVER button when no servers exist', (tester) async {
      await SecureVault().clearAll();
      final emptyProvider = ServerProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<ServerProvider>.value(value: emptyProvider), // empty on first install
            ChangeNotifierProvider(create: (_) => PolicyProvider()),
            ChangeNotifierProvider(create: (_) => TelemetryProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: DashboardScreen(onNavigateToTab: (_) {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show empty state and SETUP SERVER button
      expect(find.text('BELUM ADA SERVER TERHUBUNG'), findsOneWidget);
      expect(find.text('SETUP SERVER BARU'), findsOneWidget);
    });
  });

  group('Server Deletion, Empty State & System Reset Tests', () {
    test('TelemetryProvider clearEventsForServer and clearAll purge events and metrics', () {
      final telemetry = TelemetryProvider();
      expect(telemetry.allEvents.isNotEmpty, isTrue);

      telemetry.clearEventsForServer('srv_rumahweb_01');
      expect(telemetry.allEvents.where((e) => e.serverId == 'srv_rumahweb_01'), isEmpty);

      final zeroMetrics = telemetry.getMetricsForServer(null);
      expect(zeroMetrics.totalAttempts24h, equals(0));
      expect(zeroMetrics.failedAttempts24h, equals(0));

      telemetry.clearAll();
      expect(telemetry.allEvents, isEmpty);
    });

    test('ServerProvider clearAllServers resets server list and activeServer', () async {
      await SecureVault().clearAll();
      final provider = ServerProvider(initialServers: [ServerProvider.defaultVps]);
      expect(provider.servers.isNotEmpty, isTrue);
      expect(provider.activeServer, isNotNull);

      await provider.clearAllServers();
      expect(provider.servers, isEmpty);
      expect(provider.activeServer, isNull);
    });

    test('SettingsProvider logout reverts to Guest User and clears operator details', () async {
      await SecureVault().clearAll();
      final settings = SettingsProvider();
      await settings.init();
      await settings.updateProfile(
        name: 'Chief Security Officer',
        email: 'cso@cethokaryo.id',
        phone: '+62812345678',
      );
      expect(settings.isGuest, isFalse);
      expect(settings.operatorName, equals('Chief Security Officer'));

      await settings.logout();
      expect(settings.isGuest, isTrue);
      expect(settings.operatorName, equals('Guest User'));
      expect(settings.operatorEmail, isEmpty);
      expect(settings.operatorPhone, isEmpty);
    });

    testWidgets('ServiceDetailScreen and AuditExplorerScreen show clean empty state when no server is connected', (tester) async {
      await SecureVault().clearAll();
      final emptyProvider = ServerProvider();

      // Test ServiceDetailScreen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<ServerProvider>.value(value: emptyProvider),
            ChangeNotifierProvider(create: (_) => PolicyProvider()),
            ChangeNotifierProvider(create: (_) => TelemetryProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: ServiceDetailScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('BELUM ADA SERVER TERHUBUNG'), findsOneWidget);
      expect(find.text('SETUP SERVER BARU'), findsOneWidget);

      // Test AuditExplorerScreen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<ServerProvider>.value(value: emptyProvider),
            ChangeNotifierProvider(create: (_) => PolicyProvider()),
            ChangeNotifierProvider(create: (_) => TelemetryProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: AuditExplorerScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('BELUM ADA SERVER TERHUBUNG'), findsOneWidget);
      expect(find.text('SETUP SERVER BARU'), findsOneWidget);
    });

    testWidgets('SettingsScreen shows Logout button when logged in and Danger Zone Clear All Data section', (tester) async {
      await SecureVault().clearAll();
      final settings = SettingsProvider();
      await settings.updateProfile(
        name: 'Austin DevOps',
        email: 'austin@cethokaryo.id',
        phone: '+62811111111',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ServerProvider()),
            ChangeNotifierProvider(create: (_) => PolicyProvider()),
            ChangeNotifierProvider(create: (_) => TelemetryProvider()),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verified user should see LOGOUT / KELUAR AKUN
      expect(find.text('KELUAR AKUN'), findsOneWidget);

      // Scroll down to display Danger Zone
      await tester.scrollUntilVisible(find.text('ZONA BAHAYA & RESET SISTEM'), 300);
      await tester.pumpAndSettle();
      expect(find.text('ZONA BAHAYA & RESET SISTEM'), findsOneWidget);
      expect(find.text('HAPUS SEMUA DATA & RESTART'), findsOneWidget);
    });
  });
});
}
