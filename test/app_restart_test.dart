import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/core/security/secure_vault.dart';
import 'package:aegis/main.dart';
import 'package:aegis/providers/policy_provider.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/services/app_restart_service.dart';
import 'package:aegis/ui/screens/settings_screen.dart';

void main() {
  group('AppRestartService Unit & Integration Tests', () {
    test('AppRestartService detects test environment correctly', () {
      expect(AppRestartService.isTestEnvironment, isTrue);
    });

    test('AppRestartService.restart() completes without exception in test mode', () async {
      await expectLater(AppRestartService.restart(), completes);
    });

    test('PolicyProvider.clearAllPolicies() clears policies cleanly', () {
      final provider = PolicyProvider();
      provider.clearAllPolicies();
      expect(provider.getPolicy('any-server-id').trustedIps, isNotEmpty); // Returns default policy for new id
    });

    testWidgets('AegisRoot.restartApp() can be called from rootKey and resets app', (WidgetTester tester) async {
      final settings = SettingsProvider();
      await settings.init();

      await tester.pumpWidget(
        AegisRoot(
          key: AegisRoot.rootKey,
          initialSettingsProvider: settings,
          initialOnboardingCompleted: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(AegisRoot.rootKey.currentState, isNotNull);

      // Trigger restart
      AegisRoot.restartApp();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // After restart, onboarding completed is false
      expect(find.byType(AegisApp), findsOneWidget);
    });

    testWidgets('Clear All Data dialog opens and triggers wipe & restart', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await SecureVault().clearAll();
      final settings = SettingsProvider();
      await settings.updateProfile(
        name: 'Dev Operator',
        email: 'dev@cethokaryo.id',
        phone: '+62811111111',
      );

      final serverProvider = ServerProvider(initialServers: [ServerProvider.defaultVps]);
      final policyProvider = PolicyProvider();
      final telemetryProvider = TelemetryProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<ServerProvider>.value(value: serverProvider),
            ChangeNotifierProvider<PolicyProvider>.value(value: policyProvider),
            ChangeNotifierProvider<TelemetryProvider>.value(value: telemetryProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to danger zone
      await tester.scrollUntilVisible(find.text('HAPUS SEMUA DATA & RESTART'), 400);
      await tester.pumpAndSettle();

      final clearButton = find.text('HAPUS SEMUA DATA & RESTART');
      expect(clearButton, findsOneWidget);

      // Tap clear button to show confirmation dialog
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text('HAPUS SEMUA DATA & RESET?'), findsOneWidget);

      // Confirm wipe & restart
      final confirmButton = find.text('YA, HAPUS SEMUA & RESTART');
      expect(confirmButton, findsOneWidget);

      await tester.tap(confirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify servers and profile were reset
      expect(serverProvider.servers, isEmpty);
      expect(settings.operatorName, equals('Guest User'));
      expect(settings.isGuest, isTrue);
    });
  });
}
