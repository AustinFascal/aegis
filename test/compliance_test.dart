import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/models/compliance_check.dart';
import 'package:aegis/models/server_profile.dart';
import 'package:aegis/providers/policy_provider.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/services/compliance_service.dart';
import 'package:aegis/ui/screens/compliance_screen.dart';
import 'package:aegis/ui/screens/faq_screen.dart';
import 'package:aegis/ui/screens/policy_settings_screen.dart';
import 'package:aegis/ui/screens/server_management_screen.dart';
import 'package:aegis/ui/widgets/compliance_scanner_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testServer = ServerProfile(
    id: 'test_srv_compliance',
    name: 'Bastion SecOps Host',
    host: '10.0.0.15',
    port: 22,
    username: 'aegis_admin',
    authType: AuthType.password,
    isConnected: true,
  );

  group('ComplianceService Unit Tests', () {
    test('Calculates score and grade accurately', () {
      expect(ComplianceScanReport.calculateGrade(96), 'A+');
      expect(ComplianceScanReport.calculateGrade(88), 'A');
      expect(ComplianceScanReport.calculateGrade(74), 'B');
      expect(ComplianceScanReport.calculateGrade(60), 'C');
      expect(ComplianceScanReport.calculateGrade(40), 'F');

      const passItem = ComplianceCheckItem(
        id: 'c1',
        category: ComplianceCategory.ssh,
        titleId: 'T1',
        titleEn: 'T1',
        descriptionId: 'D1',
        descriptionEn: 'D1',
        rationaleId: 'R1',
        rationaleEn: 'R1',
        command: 'cmd',
        expected: 'exp',
        status: ComplianceStatus.passed,
        severity: ComplianceSeverity.critical,
        remediationScript: 'fix',
        standard: 'CIS',
      );

      const failItem = ComplianceCheckItem(
        id: 'c2',
        category: ComplianceCategory.sysctl,
        titleId: 'T2',
        titleEn: 'T2',
        descriptionId: 'D2',
        descriptionEn: 'D2',
        rationaleId: 'R2',
        rationaleEn: 'R2',
        command: 'cmd',
        expected: 'exp',
        status: ComplianceStatus.failed,
        severity: ComplianceSeverity.critical,
        remediationScript: 'fix',
        standard: 'CIS',
      );

      expect(ComplianceScanReport.calculateScore([passItem]), 100);
      expect(ComplianceScanReport.calculateScore([failItem]), 0);
      expect(ComplianceScanReport.calculateScore([passItem, failItem]), 50);
    });

    test('Generates baseline compliance scan report with 17 benchmarks across 5 categories', () async {
      final service = ComplianceService();
      final report = await service.runComplianceScan(server: testServer, forceSimulation: true);

      expect(report.serverId, 'test_srv_compliance');
      expect(report.serverName, 'Bastion SecOps Host');
      expect(report.items.length, 17);
      expect(report.score, greaterThan(0));
      expect(report.score, lessThanOrEqualTo(100));

      final categories = report.items.map((i) => i.category).toSet();
      expect(categories, contains(ComplianceCategory.ssh));
      expect(categories, contains(ComplianceCategory.sysctl));
      expect(categories, contains(ComplianceCategory.firewall));
      expect(categories, contains(ComplianceCategory.identity));
      expect(categories, contains(ComplianceCategory.filesystem));

      final playbook = service.generateRemediationPlaybook(report);
      expect(playbook, contains('#!/bin/bash'));
      expect(playbook, contains('AEGIS AUTOMATED HARDENING'));

      final mdReport = service.generateMarkdownReport(report, false);
      expect(mdReport, contains('SYSTEM HARDENING & COMPLIANCE AUDIT REPORT'));
      expect(mdReport, contains('Bastion SecOps Host'));
    });
  });

  group('ComplianceScannerCard & Integration Widget Tests', () {
    testWidgets('ComplianceScannerCard renders badge, title, and navigates to ComplianceScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider(initialServers: [testServer]);
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ComplianceScannerCard(server: testServer),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('HARDENING SISTEM & KEPATUHAN'), findsOneWidget);
      expect(find.text('CIS Linux Level 1 & 2'), findsOneWidget);
      expect(find.text('OpenSSH 5.2 Hardening'), findsOneWidget);
      expect(find.text('BUKA PEMINDAI KEPATUHAN'), findsOneWidget);

      // Tap button to navigate to ComplianceScreen
      await tester.tap(find.text('BUKA PEMINDAI KEPATUHAN'));
      await tester.pumpAndSettle();

      expect(find.byType(ComplianceScreen), findsOneWidget);
      expect(find.text('HARDENING & KEPATUHAN'), findsOneWidget);
    });

    testWidgets('PolicySettingsScreen renders ComplianceScannerCard', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider(initialServers: [testServer]);
      final policyProvider = PolicyProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: policyProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: PolicySettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ComplianceScannerCard), findsOneWidget);
      expect(find.text('BUKA PEMINDAI KEPATUHAN'), findsOneWidget);
    });

    testWidgets('Server card displays HARDENING button beside SFTP and opens ComplianceScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider(initialServers: [testServer]);
      final themeProvider = ThemeProvider();
      final telemetry = TelemetryProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: telemetry),
          ],
          child: const MaterialApp(
            home: ServerManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify TERMINAL, SFTP, and HARDENING buttons are present
      expect(find.text('TERMINAL'), findsWidgets);
      expect(find.text('SFTP'), findsWidgets);
      expect(find.text('HARDENING'), findsWidgets);

      // Tap HARDENING button
      final hardeningBtn = find.text('HARDENING').first;
      await tester.ensureVisible(hardeningBtn);
      await tester.tap(hardeningBtn);
      await tester.pumpAndSettle();

      // Verify ComplianceScreen opens
      expect(find.byType(ComplianceScreen), findsOneWidget);
      expect(find.text('HARDENING & KEPATUHAN'), findsOneWidget);

      telemetry.dispose();
      await tester.pump();
    });
  });

  group('ComplianceScreen UI & Interaction Tests', () {
    testWidgets('ComplianceScreen renders score card, category filter, findings list, and expands items', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider(initialServers: [testServer]);
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: ComplianceScreen(server: testServer),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Verify Score Card and Breakdown
      expect(find.textContaining('Skor Kepatuhan CIS & Hardening'), findsOneWidget);
      expect(find.textContaining('GRADE'), findsOneWidget);
      expect(find.textContaining('Lolos:'), findsOneWidget);

      // Verify Category Filter Chips
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('OpenSSH'), findsOneWidget);
      expect(find.text('Kernel Sysctl'), findsOneWidget);
      expect(find.text('Firewall'), findsOneWidget);

      // Verify Findings
      expect(find.text('Larangan Login Langsung Root SSH'), findsOneWidget);
      expect(find.text('Autentikasi Kunci Publik (Password Dinonaktifkan)'), findsOneWidget);

      // Tap to expand an item
      await tester.tap(find.text('Larangan Login Langsung Root SSH'));
      await tester.pumpAndSettle();

      // Verify expanded details
      expect(find.textContaining('Rasional Keamanan:'), findsOneWidget);
      expect(find.textContaining('Skrip Perbaikan'), findsOneWidget);
      expect(find.text('Salin Perbaikan'), findsOneWidget);

      // Tap Playbook dialog button
      final playbookBtn = find.byTooltip('Playbook Remediasi');
      expect(playbookBtn, findsOneWidget);
      await tester.tap(playbookBtn);
      await tester.pumpAndSettle();

      expect(find.text('Playbook Remediasi Otomatis'), findsOneWidget);
      expect(find.text('Salin Skrip'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      expect(find.text('Playbook Remediasi Otomatis'), findsNothing);
    });

    testWidgets('ComplianceScreen renders on narrow mobile viewport without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider(initialServers: [testServer]);
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: ComplianceScreen(server: testServer),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ComplianceScreen), findsOneWidget);
    });
  });

  group('FaqScreen Hardening & Compliance Documentation Tests', () {
    testWidgets('FaqScreen displays System Hardening and CIS compliance documentation and code snippets', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: FaqScreen(initialCategory: FaqCategory.security),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the compliance hardening FAQ question
      final questionFinder = find.textContaining('CIS Benchmark');
      expect(questionFinder, findsOneWidget);

      // Scroll and tap the question to expand
      await tester.ensureVisible(questionFinder);
      await tester.tap(questionFinder);
      await tester.pumpAndSettle();

      // Check expanded content and code snippet
      expect(find.textContaining('Cakupan 17 Pengujian Keamanan'), findsOneWidget);
      expect(find.textContaining('99-aegis-hardening.conf'), findsOneWidget);
      expect(find.textContaining('kernel.randomize_va_space'), findsWidgets);
    });
  });
}

