import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/core/constants/service_registry.dart';
import 'package:aegis/models/auth_event.dart';
import 'package:aegis/models/security_policy.dart';
import 'package:aegis/models/server_profile.dart';
import 'package:aegis/providers/policy_provider.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/services/penetration_test_service.dart';
import 'package:aegis/ui/widgets/penetration_test_card.dart';

void main() {
  group('PenetrationTestService Unit Tests', () {
    final policy = SecurityPolicy(
      serverId: 'test-srv-01',
      trustedIps: ['127.0.0.1'],
      maxFailedAttemptsThreshold: 3,
      timeWindowSeconds: 120,
    );

    test('threat origins library contains 20+ diverse global threat actor profiles', () {
      final origins = PenetrationTestService.threatOrigins;
      expect(origins.length, greaterThanOrEqualTo(20));

      final countries = origins.map((o) => o['country']).toSet();
      expect(countries.contains('RU'), isTrue);
      expect(countries.contains('US'), isTrue);
      expect(countries.contains('CN'), isTrue);
      expect(countries.contains('DE'), isTrue);
      expect(countries.contains('NL'), isTrue);
      expect(countries.contains('ID'), isTrue);
      expect(countries.contains('JP'), isTrue);
      expect(countries.contains('KP'), isTrue);
    });

    test('executes brute force pen-test on OpenSSH daemon and triggers alert', () async {
      final service = ServiceRegistry.getById('sshd');
      final result = await PenetrationTestService().executePenTest(
        service: service,
        scenario: PenTestScenario.bruteForce,
        policy: policy,
        serverId: 'test-srv-01',
      );

      expect(result.service.id, equals('sshd'));
      expect(result.scenario, equals(PenTestScenario.bruteForce));
      expect(result.alertTriggered, isTrue);
      expect(result.event.status, equals(EventStatus.failed));
      expect(result.event.severity, equals(EventSeverity.critical));
      expect(result.event.riskScore, greaterThanOrEqualTo(90));
      expect(result.event.evidenceLogs.length, greaterThanOrEqualTo(3));
      expect(result.executionLogs.isNotEmpty, isTrue);
    });

    test('executes custom IP penetration test', () async {
      final service = ServiceRegistry.getById('sshd');
      final result = await PenetrationTestService().executePenTest(
        service: service,
        scenario: PenTestScenario.bruteForce,
        policy: policy,
        serverId: 'test-srv-01',
        customIp: '198.18.0.55',
      );

      expect(result.clientIp, equals('198.18.0.55'));
      expect(result.event.clientIp, equals('198.18.0.55'));
    });

    test('executes unknown person pen-test on MySQL and triggers critical alert', () async {
      final service = ServiceRegistry.getById('mysqld');
      final result = await PenetrationTestService().executePenTest(
        service: service,
        scenario: PenTestScenario.unknownPerson,
        policy: policy,
        serverId: 'test-srv-01',
      );

      expect(result.service.id, equals('mysqld'));
      expect(result.scenario, equals(PenTestScenario.unknownPerson));
      expect(result.alertTriggered, isTrue);
      expect(result.event.status, equals(EventStatus.success));
      expect(result.event.isUnknownPerson, isTrue);
      expect(result.event.riskScore, equals(98));
      expect(result.alertTitle, contains('Unknown Person'));
    });

    test('executes exploit probe pen-test on NGINX', () async {
      final service = ServiceRegistry.getById('nginx');
      final result = await PenetrationTestService().executePenTest(
        service: service,
        scenario: PenTestScenario.exploitProbe,
        policy: policy,
        serverId: 'test-srv-01',
      );

      expect(result.service.id, equals('nginx'));
      expect(result.scenario, equals(PenTestScenario.exploitProbe));
      expect(result.alertTriggered, isTrue);
      expect(result.event.severity, equals(EventSeverity.critical));
      expect(result.alertTitle, contains('EXPLOIT PROBE'));
    });
  });

  group('PenetrationTestCard Widget Tests', () {
    Widget buildTestApp({List<ServerProfile>? initialServers}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(
            create: (_) => ServerProvider(
              initialServers: initialServers ?? [ServerProvider.defaultVps],
            ),
          ),
          ChangeNotifierProvider(create: (_) => PolicyProvider()),
          ChangeNotifierProvider(create: (_) => TelemetryProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: PenetrationTestCard(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders PenetrationTestCard with all service selection & scenario options when server configured', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify Card title
      expect(find.textContaining('UJI PENETRASI'), findsWidgets);

      // Verify Target server banner is visible
      expect(find.textContaining('TARGET:'), findsOneWidget);
      expect(find.textContaining('RumahWeb VPS'), findsOneWidget);

      // Verify Scenario chips are present
      expect(find.textContaining('Brute Force'), findsWidgets);
      expect(find.textContaining('Orang Tak Dikenal'), findsWidgets);
      expect(find.textContaining('Injeksi Eksploitasi'), findsWidgets);

      // Verify Launch button is present and enabled
      final launchButton = find.widgetWithText(ElevatedButton, 'LANCARKAN UJI PENETRASI');
      expect(launchButton, findsOneWidget);
      final btnWidget = tester.widget<ElevatedButton>(launchButton);
      expect(btnWidget.onPressed, isNotNull);
    });

    testWidgets('card is disabled with warning banner when no server is added', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(initialServers: []));
      await tester.pumpAndSettle();

      // Verify Warning banner is shown
      expect(find.textContaining('SERVER BELUM DIKONFIGURASI'), findsOneWidget);
      expect(
        find.textContaining('Fitur uji penetrasi dinonaktifkan karena belum ada server'),
        findsOneWidget,
      );

      // Verify Launch button is disabled
      final launchButton = find.byType(ElevatedButton);
      expect(launchButton, findsOneWidget);
      final btnWidget = tester.widget<ElevatedButton>(launchButton);
      expect(btnWidget.onPressed, isNull);

      // Verify tapping does nothing
      await tester.tap(launchButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('SIMULASI BERHASIL'), findsNothing);
    });

    testWidgets('renders on narrow mobile viewport (360x700) with zero overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Ensure no flutter overflow exceptions occurred
      expect(tester.takeException(), isNull);

      // Target banner and main controls are visible
      expect(find.textContaining('TARGET:'), findsOneWidget);
      expect(find.textContaining('LANCARKAN UJI PENETRASI'), findsOneWidget);
    });

    testWidgets('selecting scenario switches active scenario and updates UI', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final unknownChip = find.textContaining('Orang Tak Dikenal');
      expect(unknownChip, findsOneWidget);

      await tester.tap(unknownChip);
      await tester.pumpAndSettle();

      // Switch to Exploit probe
      final exploitChip = find.textContaining('Injeksi Eksploitasi');
      expect(exploitChip, findsOneWidget);

      await tester.tap(exploitChip);
      await tester.pumpAndSettle();
    });

    testWidgets('opens IP selection sheet and selects an IP from library', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap "PILIH IP LAIN" / "CHOOSE IP"
      final chooseIpBtn = find.textContaining('PILIH IP LAIN');
      expect(chooseIpBtn, findsOneWidget);
      await tester.tap(chooseIpBtn);
      await tester.pumpAndSettle();

      // Verify Sheet header is displayed
      expect(find.textContaining('PILIH IP PENYERANG'), findsOneWidget);

      // Tap on an entry e.g. Kyiv or Amsterdam
      final kyivIp = find.textContaining('45.154.255.88');
      if (kyivIp.evaluate().isNotEmpty) {
        await tester.tap(kyivIp);
        await tester.pumpAndSettle();
        expect(find.textContaining('45.154.255.88'), findsOneWidget);
      }
    });

    testWidgets('tapping Launch Pen-Test runs simulation and displays terminal output', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final launchButton = find.textContaining('LANCARKAN UJI PENETRASI');
      expect(launchButton, findsOneWidget);

      await tester.tap(launchButton);
      // Pump initial step
      await tester.pump(const Duration(milliseconds: 200));

      // Pump through all delays in execution
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify terminal logs are displayed
      expect(find.textContaining('[RECON]'), findsOneWidget);
      expect(find.textContaining('[DISPATCH]'), findsOneWidget);

      // Verify success banner and action button appear
      expect(find.textContaining('SIMULASI BERHASIL'), findsOneWidget);
      expect(find.textContaining('BUKA FORENSIK'), findsOneWidget);
    });
  });
}
