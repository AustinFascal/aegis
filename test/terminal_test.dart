import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/models/server_profile.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/ui/screens/server_management_screen.dart';
import 'package:aegis/ui/screens/terminal_screen.dart';
import 'package:aegis/ui/screens/features_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testServer = ServerProfile(
    id: 'test_srv_terminal',
    name: 'Production Cloud Node',
    host: '192.168.1.50',
    port: 22,
    username: 'admin',
    authType: AuthType.password,
    isConnected: true,
  );

  group('TerminalScreen UI & Interaction Tests', () {
    testWidgets('TerminalScreen renders header, welcome banner, quick command chips, and input line', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
          ],
          child: MaterialApp(
            home: TerminalScreen(server: testServer),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify AppBar details
      expect(find.text('Production Cloud Node'), findsOneWidget);
      expect(find.text('admin@192.168.1.50:22'), findsOneWidget);

      // Verify initial console welcome banner
      expect(find.textContaining('AEGIS SECURE CONSOLE'), findsOneWidget);
      expect(find.textContaining('admin@192.168.1.50:22'), findsWidgets);

      // Verify Quick Command chips
      expect(find.text('aegis status'), findsOneWidget);
      expect(find.text('fail2ban'), findsOneWidget);
      expect(find.text('uptime'), findsOneWidget);
      expect(find.text('disk (df)'), findsOneWidget);

      // Verify Virtual Key buttons
      expect(find.text('Ctrl+C'), findsOneWidget);
      expect(find.text('Tab'), findsOneWidget);
      expect(find.text('▲ Up'), findsOneWidget);
      expect(find.text('▼ Down'), findsOneWidget);
      expect(find.text('sudo'), findsOneWidget);
      expect(find.text('| grep'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // Verify input prompt and textfield
      expect(find.text('# '), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Virtual keys insert sudo and pipe grep into textfield', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
          ],
          child: MaterialApp(
            home: TerminalScreen(server: testServer),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap 'sudo' button
      await tester.tap(find.text('sudo'));
      await tester.pump();

      final inputFinder = find.byType(TextField);
      TextField textField = tester.widget(inputFinder);
      expect(textField.controller?.text, 'sudo ');

      // Enter 'cat /etc/passwd'
      await tester.enterText(inputFinder, 'cat /etc/passwd');
      await tester.pump();

      // Tap '| grep'
      await tester.tap(find.text('| grep'));
      await tester.pump();

      textField = tester.widget(inputFinder);
      expect(textField.controller?.text, 'cat /etc/passwd | grep ');

      // Tap 'Clear'
      await tester.tap(find.text('Clear'));
      await tester.pump();

      // Terminal screen console lines cleared
      expect(find.textContaining('AEGIS SECURE CONSOLE'), findsNothing);
    });

    testWidgets('TerminalView renders with buffer, supports theme switching and fullscreen toggle', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
          ],
          child: MaterialApp(
            home: TerminalScreen(server: testServer),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify TerminalScreen and Terminal instance
      final terminalScreenFinder = find.byType(TerminalScreen);
      expect(terminalScreenFinder, findsOneWidget);

      final state = tester.state<TerminalScreenState>(terminalScreenFinder);
      expect(state.terminal.buffer.getText(), contains('AEGIS SECURE CONSOLE'));

      // Verify Triple Dot Menu exists and opens all options
      final moreBtn = find.byTooltip('Menu Terminal');
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pilih Tema'), findsOneWidget);
      expect(find.text('Layar Penuh'), findsOneWidget);
      expect(find.text('Hubungkan Ulang'), findsOneWidget);
      expect(find.text('Perbesar Font (A+)'), findsOneWidget);
      expect(find.text('Perkecil Font (A-)'), findsOneWidget);
      expect(find.text('Salin Log Konsol'), findsOneWidget);
      expect(find.text('Bersihkan Konsol'), findsOneWidget);

      // Tap 'Pilih Tema' -> opens theme picker dialog
      await tester.tap(find.text('Pilih Tema'));
      await tester.pumpAndSettle();

      // Verify theme choices in dialog
      expect(find.text('Cyber OLED'), findsOneWidget);
      expect(find.text('Matrix Green'), findsOneWidget);
      expect(find.text('Monokai Pro'), findsOneWidget);
      expect(find.text('Nord Glacier'), findsOneWidget);

      // Select Matrix Green
      await tester.tap(find.text('Matrix Green'));
      await tester.pumpAndSettle();

      // Verify Fullscreen toggle button
      final fullscreenBtn = find.byTooltip('Layar Penuh');
      expect(fullscreenBtn, findsOneWidget);
      await tester.tap(fullscreenBtn);
      await tester.pumpAndSettle();

      // In fullscreen mode, input row and banner are hidden
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Keluar Layar Penuh'), findsOneWidget);

      // Tap fullscreen exit
      await tester.tap(find.byTooltip('Keluar Layar Penuh'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // Verify htop quick command chip
      expect(find.text('htop'), findsOneWidget);

      // Verify extended virtual navigation keys exist
      expect(find.text('ESC'), findsOneWidget);
      expect(find.text('◀ Left'), findsOneWidget);
      expect(find.text('▶ Right'), findsOneWidget);
    });

    testWidgets('TerminalScreen is responsive on mobile phone viewport (360x640) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
          ],
          child: MaterialApp(
            home: TerminalScreen(server: testServer),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify no RenderFlex overflow occurred on phone screen
      expect(tester.takeException(), isNull);

      // Verify on phone only Status Pill and Triple Dot menu exist in AppBar actions
      expect(find.byTooltip('Menu Terminal'), findsOneWidget);
      // Quick desktop buttons are collapsed into triple dot menu
      expect(find.byTooltip('Hubungkan Ulang'), findsNothing);

      // Tap triple dot menu on phone
      await tester.tap(find.byTooltip('Menu Terminal'));
      await tester.pumpAndSettle();

      // Verify all options are present in triple dot menu on phone
      expect(find.text('Pilih Tema'), findsOneWidget);
      expect(find.text('Layar Penuh'), findsOneWidget);
      expect(find.text('Hubungkan Ulang'), findsOneWidget);
      expect(find.text('Perbesar Font (A+)'), findsOneWidget);
      expect(find.text('Perkecil Font (A-)'), findsOneWidget);
      expect(find.text('Salin Log Konsol'), findsOneWidget);
      expect(find.text('Bersihkan Konsol'), findsOneWidget);

      // Close menu by tapping outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('ServerManagementScreen Terminal Button Tests', () {
    testWidgets('Server card displays responsive action buttons and FeaturesScreen opens TerminalScreen', (tester) async {
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

      // Verify KONFIGURASI and TEST SSH exist and shortcut button TERMINAL was removed
      expect(find.text('KONFIGURASI'), findsWidgets);
      expect(find.text('UJI SSH'), findsWidgets);
      expect(find.text('TERMINAL'), findsNothing);

      // Verify FeaturesScreen opens TerminalScreen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: telemetry),
          ],
          child: const MaterialApp(
            home: FeaturesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final terminalBtn = find.text('BUKA TERMINAL');
      expect(terminalBtn, findsOneWidget);
      await tester.tap(terminalBtn);
      await tester.pumpAndSettle();

      // Verify TerminalScreen opened
      expect(find.byType(TerminalScreen), findsOneWidget);
      expect(find.textContaining('admin@192.168.1.50:22'), findsWidgets);

      telemetry.dispose();
      await tester.pump();
    });
  });
}
