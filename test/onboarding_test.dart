import 'package:aegis/core/security/secure_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/main.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/policy_provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/ui/screens/onboarding_screen.dart';
import 'package:aegis/ui/screens/settings_screen.dart';
import 'package:aegis/core/security/biometric_service.dart';

void main() {
  group('Onboarding, Walkthrough & Profile Setup Tests', () {
    setUp(() async {
      await SecureVault().clearAll();
    });

    testWidgets('First app install launches OnboardingScreen with walkthrough slides',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // When initialOnboardingCompleted is false on fresh install
      await tester.pumpWidget(const AegisApp(initialOnboardingCompleted: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify OnboardingScreen is mounted
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('INFRASTRUCTURE SECURITY SENTINEL'), findsOneWidget);
      expect(find.text('LEWATI'), findsWidgets);
      expect(find.text('LANJUTKAN'), findsOneWidget);

      // Navigate to Slide 1 (Penetration Lab)
      await tester.tap(find.text('LANJUTKAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('PENETRATION TESTING LAB'), findsOneWidget);
      expect(find.textContaining('Isolasi IP Perangkat 100%'), findsOneWidget);

      // Navigate to Slide 2 (Profile Setup)
      await tester.tap(find.text('LANJUTKAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Setup Profil Operator'), findsOneWidget);
      expect(find.text('Nama Lengkap Operator'), findsOneWidget);
      expect(find.text('Alamat Email'), findsOneWidget);
      expect(find.text('Nomor Telepon'), findsOneWidget);
      expect(find.text('LEWATI (TAMU)'), findsOneWidget);
      expect(find.text('SIMPAN & MULAI'), findsOneWidget);

      // Verify that Role and Clearance Level are NOT present on profile setup
      expect(find.text('Jabatan / Peran'), findsNothing);
      expect(find.text('Tingkat Akses Keamanan'), findsNothing);
      expect(find.text('Clearance Level'), findsNothing);
    });

    testWidgets('Skipping profile setup results in Guest User on settings screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ServerProvider()),
            ChangeNotifierProvider(create: (_) => PolicyProvider()),
            ChangeNotifierProvider(create: (_) => TelemetryProvider()),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: MaterialApp(
            home: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return settings.isOnboardingCompleted
                    ? const SettingsScreen()
                    : const OnboardingScreen();
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap LEWATI in top bar
      final skipBtn = find.text('LEWATI').first;
      await tester.tap(skipBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // After skip, should transition to SettingsScreen as Guest User
      expect(settingsProvider.isOnboardingCompleted, isTrue);
      expect(settingsProvider.isGuest, isTrue);
      expect(settingsProvider.operatorName, equals('Guest User'));
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Verify guest profile card styling
      expect(find.text('Guest User'), findsOneWidget);
      expect(find.text('GUEST OPERATOR'), findsOneWidget);
      expect(find.text('SETUP PROFIL'), findsOneWidget);

      // Verify Role and Clearance Level are completely absent from profile card
      expect(find.text('Principal Infrastructure Sentinel'), findsNothing);
      expect(find.textContaining('Level 4'), findsNothing);
    });

    testWidgets('Completing profile setup saves Name, Email, and Phone without Role or Clearance',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ServerProvider()),
            ChangeNotifierProvider(create: (_) => PolicyProvider()),
            ChangeNotifierProvider(create: (_) => TelemetryProvider()),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: MaterialApp(
            home: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return settings.isOnboardingCompleted
                    ? const SettingsScreen()
                    : const OnboardingScreen();
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Navigate from Slide 0 -> Slide 1
      await tester.tap(find.text('LANJUTKAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Navigate from Slide 1 -> Slide 2 (Profile Setup)
      await tester.tap(find.text('LANJUTKAN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Fill in Name, Email, Phone on Slide 2
      final nameFinder = find.widgetWithText(TextFormField, 'Nama Lengkap Operator');
      final emailFinder = find.widgetWithText(TextFormField, 'Alamat Email');
      final phoneFinder = find.widgetWithText(TextFormField, 'Nomor Telepon');

      expect(nameFinder, findsOneWidget);
      await tester.enterText(nameFinder, 'Austin Fascal');
      await tester.enterText(emailFinder, 'austin@cethokaryo.id');
      await tester.enterText(phoneFinder, '+62 812-3456-7890');

      // Tap SIMPAN & MULAI
      await tester.tap(find.text('SIMPAN & MULAI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify settings state
      expect(settingsProvider.isOnboardingCompleted, isTrue);
      expect(settingsProvider.isGuest, isFalse);
      expect(settingsProvider.operatorName, equals('Austin Fascal'));
      expect(settingsProvider.operatorEmail, equals('austin@cethokaryo.id'));
      expect(settingsProvider.operatorPhone, equals('+62 812-3456-7890'));

      // Verify SettingsScreen profile card
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Austin Fascal'), findsOneWidget);
      expect(find.text('VERIFIED GUARDIAN'), findsOneWidget);
      expect(find.text('austin@cethokaryo.id'), findsOneWidget);
      expect(find.text('+62 812-3456-7890'), findsOneWidget);
      expect(find.text('UBAH PROFIL'), findsOneWidget);
    });

    testWidgets('Edit profile dialog on SettingsScreen only has Name, Email, Phone',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ServerProvider()),
            ChangeNotifierProvider(create: (_) => PolicyProvider()),
            ChangeNotifierProvider(create: (_) => TelemetryProvider()),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Initialize profile after pumpWidget so MethodChannels process normally
      await settingsProvider.completeOnboarding(
        name: 'Austin Sentinel',
        email: 'sentinel@aegis.io',
        phone: '+628111222333',
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap UBAH PROFIL
      await tester.tap(find.text('UBAH PROFIL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog is open
      expect(find.text('Profil Operator Keamanan'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nama Lengkap Operator'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Alamat Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nomor Telepon'), findsOneWidget);

      // Verify Role & Clearance Level do NOT exist
      expect(find.text('Jabatan / Peran'), findsNothing);
      expect(find.text('Tingkat Akses Keamanan'), findsNothing);
      expect(find.text('Security Role / Title'), findsNothing);
      expect(find.text('Clearance Level'), findsNothing);

      // Update name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Lengkap Operator'),
        'Commander Austin',
      );
      await tester.tap(find.text('SIMPAN PROFIL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(settingsProvider.operatorName, equals('Commander Austin'));
      expect(find.text('Commander Austin'), findsOneWidget);
    });

    test('BiometricService safe initialization and device fingerprint enforcement', () async {
      final bio = BiometricService();
      final isSupported = await bio.isDeviceSupported();
      expect(isSupported, isA<bool>());

      final biometrics = await bio.getAvailableBiometrics();
      expect(biometrics, isA<List>());

      final authResult = await bio.authenticate(
        reason: 'Test biometric authentication',
      );
      expect(authResult, isTrue);
    });
  });
}
