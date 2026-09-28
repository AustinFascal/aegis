import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/models/auth_event.dart';
import 'package:aegis/providers/policy_provider.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/services/threat_intel_service.dart';
import 'package:aegis/ui/widgets/forensic_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThreatIntelService Unit Tests', () {
    late ThreatIntelService service;

    setUp(() {
      service = ThreatIntelService();
      service.clearCache();
      service.customHttpFetcher = null;
    });

    test('Private and localhost IPs are identified and returned as clean without external requests', () async {
      final loopback = await service.checkIp(ip: '127.0.0.1');
      expect(loopback.isPublic, isFalse);
      expect(loopback.abuseConfidenceScore, 0);
      expect(loopback.isWhitelisted, isTrue);
      expect(loopback.usageType, contains('RFC 1918'));

      final lan10 = await service.checkIp(ip: '10.244.0.1');
      expect(lan10.isPublic, isFalse);
      expect(lan10.abuseConfidenceScore, 0);

      final lan192 = await service.checkIp(ip: '192.168.1.100');
      expect(lan192.isPublic, isFalse);
      expect(lan192.abuseConfidenceScore, 0);

      final lan172 = await service.checkIp(ip: '172.24.0.5');
      expect(lan172.isPublic, isFalse);
      expect(lan172.abuseConfidenceScore, 0);

      final ipv6Local = await service.checkIp(ip: '::1');
      expect(ipv6Local.isPublic, isFalse);
    });

    test('Simulated mode returns realistic intelligence for penetration testing threat origins', () async {
      // 185.220.101.99 is known Tor Exit Gateway in PenetrationTestService
      final torIntel = await service.checkIp(ip: '185.220.101.99');
      expect(torIntel.isPublic, isTrue);
      expect(torIntel.isTor, isTrue);
      expect(torIntel.abuseConfidenceScore, 100);
      expect(torIntel.totalReports, greaterThan(100));
      expect(torIntel.isSimulated, isTrue);

      // 195.123.245.61 is known Botnet C2 Node
      final c2Intel = await service.checkIp(ip: '195.123.245.61');
      expect(c2Intel.isPublic, isTrue);
      expect(c2Intel.abuseConfidenceScore, 100);
      expect(c2Intel.usageType, contains('Botnet'));
      expect(c2Intel.isSimulated, isTrue);

      // 8.8.8.8 is benign Google Public DNS
      final googleDns = await service.checkIp(ip: '8.8.8.8');
      expect(googleDns.isPublic, isTrue);
      expect(googleDns.abuseConfidenceScore, 0);
      expect(googleDns.isWhitelisted, isTrue);
      expect(googleDns.isp, 'Google LLC');
    });

    test('Results are cached in-memory and clearCache flushes them', () async {
      final intel1 = await service.checkIp(ip: '45.154.255.88');
      final intel2 = await service.checkIp(ip: '45.154.255.88');

      // Should return exact same cached object reference
      expect(identical(intel1, intel2), isTrue);

      service.clearCache();
      final intel3 = await service.checkIp(ip: '45.154.255.88');
      expect(identical(intel1, intel3), isFalse);
    });

    test('Parses live AbuseIPDB JSON response via custom HTTP fetcher', () async {
      service.customHttpFetcher = (ip, key) async {
        expect(ip, '118.25.6.39');
        expect(key, 'test-abuseipdb-api-key');
        return {
          'data': {
            'ipAddress': '118.25.6.39',
            'isPublic': true,
            'ipVersion': 4,
            'isWhitelisted': false,
            'abuseConfidenceScore': 92,
            'countryCode': 'CN',
            'countryName': 'China',
            'usageType': 'Data Center/Web Hosting/Transit',
            'isp': 'Tencent Cloud Computing',
            'domain': 'tencent.com',
            'hostnames': ['vm-cluster.tencent.com'],
            'isTor': false,
            'totalReports': 412,
            'numDistinctUsers': 118,
            'lastReportedAt': '2026-09-20T08:14:00+00:00'
          }
        };
      };

      final intel = await service.checkIp(
        ip: '118.25.6.39',
        apiKey: 'test-abuseipdb-api-key',
      );

      expect(intel.ipAddress, '118.25.6.39');
      expect(intel.abuseConfidenceScore, 92);
      expect(intel.isp, 'Tencent Cloud Computing');
      expect(intel.domain, 'tencent.com');
      expect(intel.totalReports, 412);
      expect(intel.numDistinctUsers, 118);
      expect(intel.isSimulated, isFalse);
      expect(intel.isHighRisk, isTrue);
    });

    test('verifyApiKey succeeds with valid response and fails on error', () async {
      service.customHttpFetcher = (ip, key) async => {'data': {}};
      final valid = await service.verifyApiKey('valid-key');
      expect(valid, isTrue);

      service.customHttpFetcher = (ip, key) async => throw Exception('Unauthorized 401');
      final invalid = await service.verifyApiKey('invalid-key');
      expect(invalid, isFalse);

      final empty = await service.verifyApiKey('   ');
      expect(empty, isFalse);
    });
  });

  group('SettingsProvider AbuseIPDB Key Management Tests', () {
    test('Set, read, and remove AbuseIPDB API key updates state', () async {
      final settings = SettingsProvider();
      await settings.init();

      expect(settings.hasAbuseIpDbApiKey, isFalse);

      await settings.setAbuseIpDbApiKey('a1b2c3d4e5f6');
      expect(settings.hasAbuseIpDbApiKey, isTrue);
      expect(settings.abuseIpDbApiKey, 'a1b2c3d4e5f6');

      await settings.removeAbuseIpDbApiKey();
      expect(settings.hasAbuseIpDbApiKey, isFalse);
      expect(settings.abuseIpDbApiKey, isNull);
    });
  });

  group('ForensicDialog Threat Intel UI Tests', () {
    testWidgets('ForensicDialog renders Threat Intelligence card with AbuseIPDB details', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final policy = PolicyProvider();
      final server = ServerProvider();
      final telemetry = TelemetryProvider();

      final event = AuthEvent(
        id: 'test-event-threat-1',
        serverId: 'srv-1',
        timestamp: DateTime.now(),
        service: 'OpenSSH',
        user: 'root',
        clientIp: '185.220.101.99', // Tor Exit Node from PenTest origin catalog
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        failureReason: 'Failed password for root',
        riskScore: 95,
        country: 'RU',
        city: 'Moscow',
        asn: 'AS208294 (Tor Exit Gateway)',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: policy),
            ChangeNotifierProvider.value(value: server),
            ChangeNotifierProvider.value(value: telemetry),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ForensicDialog(event: event),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Forensic Dialog header
      expect(find.text('OPENSSH'), findsOneWidget);

      // Verify Threat Intelligence section header exists
      expect(
        find.textContaining('ABUSEIPDB'),
        findsWidgets,
      );

      // Verify Tor Exit Node and High Score attributes
      expect(find.textContaining('100%'), findsWidgets);
      expect(find.textContaining('TOR EXIT NODE'), findsWidgets);

      // Verify quick "Atur Key" or "API Key" action exists
      expect(find.textContaining('Key'), findsWidgets);

      // Tap the key setup button to open the API key configuration dialog
      final keyBtn = find.text('Atur Key');
      if (keyBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(keyBtn.first);
        await tester.tap(keyBtn.first);
        await tester.pumpAndSettle();

        // Verify API Key dialog opened
        expect(find.text('AbuseIPDB API Key'), findsWidgets);
        expect(find.textContaining('abuseipdb.com/register'), findsOneWidget);

        // Tap cancel to close dialog
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
      }

      telemetry.dispose();
      await tester.pump();
    });
  });
}
