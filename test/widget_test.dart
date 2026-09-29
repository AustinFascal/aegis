import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/main.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/ui/screens/service_detail_screen.dart';
import 'package:aegis/ui/screens/features_screen.dart';
import 'package:aegis/ui/screens/policy_settings_screen.dart';
import 'package:aegis/ui/screens/server_management_screen.dart';
import 'package:aegis/ui/screens/settings_screen.dart';
import 'package:aegis/ui/widgets/two_factor_auth_dialog.dart';
import 'package:aegis/ui/screens/faq_screen.dart';
import 'package:aegis/providers/policy_provider.dart';
import 'package:aegis/providers/server_provider.dart';

void main() {
  testWidgets('AegisApp smoke test & theme switching verification', (WidgetTester tester) async {
    // Set a standard mobile screen resolution
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AegisApp(initialOnboardingCompleted: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify brand title is present
    expect(find.textContaining('AEGIS'), findsWidgets);

    // Verify ThemeProvider is initialized
    final BuildContext context = tester.element(find.byType(MaterialApp));
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    expect(themeProvider.isDarkMode, isTrue);

    // Verify default language is Indonesian
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    expect(settingsProvider.language, equals('id'));
    expect(settingsProvider.isIndonesian, isTrue);

    // Verify theme toggle is absent on initial screen (Dashboard)
    expect(find.byTooltip('Switch to Light Mode'), findsNothing);

    // Navigate to Settings page via Top Navbar on Dashboard (the only entry point)
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Toggle theme to light mode on Settings page
    final themeToggleFinder = find.byTooltip('Switch to Light Mode');
    expect(themeToggleFinder, findsWidgets);
    await tester.tap(themeToggleFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(themeProvider.isDarkMode, isFalse);

    // Toggle theme back to dark mode
    final darkToggleFinder = find.byTooltip('Switch to Dark Mode');
    expect(darkToggleFinder, findsWidgets);
    await tester.tap(darkToggleFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(themeProvider.isDarkMode, isTrue);
  });

  testWidgets('AegisApp desktop wide layout test', (WidgetTester tester) async {
    // Set wide desktop screen size
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AegisApp(initialOnboardingCompleted: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // NavigationRail should be visible on wide displays with 5 primary destinations (Settings is separate)
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.textContaining('AEGIS'), findsWidgets);
  });

  testWidgets('AegisApp compact screen (320px) zero-overflow test across all tabs & settings', (WidgetTester tester) async {
    // Test on ultra-compact mobile screen: 320x568 (iPhone SE 1st gen / small Android)
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AegisApp(initialOnboardingCompleted: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tab 0: Dashboard renders without overflow (5 items in bottom bar)
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Tab 1: Services (All detected services)
    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ServiceDetailScreen), findsOneWidget);

    // Tab 2: Features (Terminal, SFTP, Hardening, Pentest, SIEM)
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FeaturesScreen), findsOneWidget);

    // Tab 3: Policies (Zero theme toggle, clean policy parameters)
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PolicySettingsScreen), findsOneWidget);

    // Tab 4: Servers
    await tester.tap(find.byIcon(Icons.dns_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ServerManagementScreen), findsOneWidget);

    // Return to Dashboard (Tab 0)
    await tester.tap(find.byIcon(Icons.radar_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Open Settings from Dashboard Top Navbar
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Guest User'), findsOneWidget);
  });

  testWidgets('SettingsScreen language switch between Indonesian and English', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AegisApp(initialOnboardingCompleted: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Navigate to Settings from top navbar
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final BuildContext context = tester.element(find.byType(SettingsScreen));
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    // Default is Indonesian
    expect(settingsProvider.language, equals('id'));
    expect(find.text('Bahasa Indonesia'), findsOneWidget);

    // Switch to English
    await tester.tap(find.text('English (US)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(settingsProvider.language, equals('en'));
    expect(settingsProvider.isIndonesian, isFalse);

    // Switch back to Indonesian
    await tester.tap(find.text('Bahasa Indonesia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(settingsProvider.language, equals('id'));
    expect(settingsProvider.isIndonesian, isTrue);
  });

  testWidgets('TwoFactorAuthDialog displays verification prompt for wito_general and submits OTP', (WidgetTester tester) async {
    String? submittedCode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                submittedCode = await TwoFactorAuthDialog.show(
                  ctx,
                  username: 'wito_general',
                  serverName: 'Production Server',
                  promptText: 'Verification code:',
                );
              },
              child: const Text('Open 2FA'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open 2FA'));
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Verifikasi 2FA Diperlukan'), findsOneWidget);
    expect(find.textContaining('wito_general'), findsOneWidget);
    expect(find.text('Verification code:'), findsOneWidget);

    // Type 6 digit OTP
    await tester.enterText(find.byType(TextFormField), '482910');
    await tester.pump();

    // Click VERIFIKASI
    await tester.tap(find.text('VERIFIKASI'));
    await tester.pumpAndSettle();

    // Verify dialog dismissed and code captured
    expect(find.byType(TwoFactorAuthDialog), findsNothing);
    expect(submittedCode, equals('482910'));
  });

  testWidgets('TwoFactorAuthDialog can be cancelled', (WidgetTester tester) async {
    String? submittedCode = 'initial';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                submittedCode = await TwoFactorAuthDialog.show(
                  ctx,
                  username: 'wito_general',
                  serverName: 'Production Server',
                );
              },
              child: const Text('Open 2FA'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open 2FA'));
    await tester.pumpAndSettle();

    // Cancel
    await tester.tap(find.text('BATAL'));
    await tester.pumpAndSettle();

    expect(find.byType(TwoFactorAuthDialog), findsNothing);
    expect(submittedCode, isNull);
  });

  testWidgets('FaqScreen mounts, switches language, expands topics, and shows server terminal commands', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
        ],
        child: const MaterialApp(
          home: FaqScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and search bar
    expect(find.text('PUSAT BANTUAN & FAQ'), findsOneWidget);
    expect(find.text('DOKUMENTASI KEBIJAKAN & TELEMETRI SERVER'), findsOneWidget);

    // Verify topic: Jendela Kecepatan (Waktu Geser)
    expect(find.text('Apa fungsi dari "Jendela Kecepatan (Waktu Geser)"?'), findsOneWidget);

    // Tap to expand Jendela Kecepatan item
    await tester.tap(find.text('Apa fungsi dari "Jendela Kecepatan (Waktu Geser)"?'));
    await tester.pumpAndSettle();

    // Verify explanation content appears
    expect(find.textContaining('rentang waktu bergulir'), findsOneWidget);
    expect(find.textContaining('Skenario Brute-Force'), findsOneWidget);

    // Switch Language to English via Top Bar toggle
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    // Verify English text
    expect(find.text('HELP CENTER & FAQ'), findsOneWidget);
    expect(find.text('What is the function of the "Velocity Window (Sliding Time)"?'), findsOneWidget);

    // Collapse topic 1 to bring other items into view
    await tester.tap(find.text('What is the function of the "Velocity Window (Sliding Time)"?'));
    await tester.pumpAndSettle();

    // Expand Server Storage FAQ
    final serverFaqFinder = find.text('Are the Failed Login Threshold & Velocity Window saved on the server? How do I access them?');
    await tester.ensureVisible(serverFaqFinder);
    await tester.tap(serverFaqFinder);
    await tester.pumpAndSettle();

    // Verify server command snippets are visible
    expect(find.textContaining('fail2ban-client get sshd maxretry'), findsOneWidget);

    // Search and verify Penetration Testing & IP Isolation FAQ items
    await tester.enterText(find.byType(TextField), 'Penetration Testing');
    await tester.pumpAndSettle();
    expect(find.text('How does the Penetration Testing Lab feature on the Settings page work?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'device IP');
    await tester.pumpAndSettle();
    expect(find.text('Does the system record my actual device IP during Penetration Testing, or only the chosen simulated IP?'), findsOneWidget);
  });

  testWidgets('Top nav Help button in PolicySettingsScreen navigates directly to FaqScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<PolicyProvider>(create: (_) => PolicyProvider()),
          ChangeNotifierProvider<ServerProvider>(create: (_) => ServerProvider()),
        ],
        child: const MaterialApp(
          home: PolicySettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Help button on Top Nav
    final helpButton = find.byTooltip('Pusat Bantuan & FAQ');
    expect(helpButton, findsOneWidget);

    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    // Verify FaqScreen opened
    expect(find.byType(FaqScreen), findsOneWidget);
  });
}
