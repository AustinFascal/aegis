import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/models/server_profile.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/ui/screens/faq_screen.dart';
import 'package:aegis/ui/screens/server_management_screen.dart';
import 'package:aegis/ui/screens/sftp_screen.dart';
import 'package:aegis/ui/screens/terminal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testServer = ServerProfile(
    id: 'test_srv_sftp',
    name: 'Primary Gateway SVR',
    host: '192.168.1.100',
    port: 22,
    username: 'secops',
    authType: AuthType.password,
    isConnected: true,
  );

  final sampleFiles = [
    SftpName(
      filename: 'nginx.conf',
      longname: '-rw-r--r-- 1 root root 2048 Jan 1 12:00 nginx.conf',
      attr: SftpFileAttrs(
        size: 2048,
        mode: const SftpFileMode.value(0x81a4),
        modifyTime: 1735689600,
      ),
    ),
    SftpName(
      filename: 'var',
      longname: 'drwxr-xr-x 2 root root 4096 Jan 1 12:00 var',
      attr: SftpFileAttrs(
        size: 4096,
        mode: const SftpFileMode.value(0x41ed),
        modifyTime: 1735689600,
      ),
    ),
    SftpName(
      filename: 'firewall.sh',
      longname: '-rwxr-xr-x 1 root root 1024 Jan 1 12:00 firewall.sh',
      attr: SftpFileAttrs(
        size: 1024,
        mode: const SftpFileMode.value(0x81ed),
        modifyTime: 1735689600,
      ),
    ),
  ];

  group('ServerManagementScreen SFTP Button Integration Tests', () {
    testWidgets('Server card displays SFTP button beside TERMINAL and opens SftpScreen', (tester) async {
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

      // Verify TERMINAL and SFTP buttons are present
      expect(find.text('TERMINAL'), findsWidgets);
      expect(find.text('SFTP'), findsWidgets);

      // Verify SFTP button has folder_shared icon
      expect(find.byIcon(Icons.folder_shared_rounded), findsWidgets);

      // Tap SFTP button
      final sftpBtn = find.text('SFTP').first;
      await tester.ensureVisible(sftpBtn);
      await tester.tap(sftpBtn);
      await tester.pumpAndSettle();

      // Verify SftpScreen is opened
      expect(find.byType(SftpScreen), findsOneWidget);
      expect(find.text('SFTP FILE MANAGER'), findsOneWidget);
      expect(find.textContaining('Primary Gateway SVR'), findsWidgets);

      telemetry.dispose();
      await tester.pump();
    });
  });

  group('SftpScreen UI & Component Tests', () {
    testWidgets('SftpScreen renders connected view: breadcrumb bar, search, file list, and upload FAB', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: SftpScreen(
              server: testServer,
              initialConnectionStateForTesting: SftpConnectionState.connected,
              initialItemsForTesting: sampleFiles,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify AppBar Title & Subtitle
      expect(find.text('SFTP FILE MANAGER'), findsOneWidget);
      expect(find.textContaining('Primary Gateway SVR'), findsWidgets);

      // Verify Terminal shortcut icon button in AppBar
      expect(find.byTooltip('Buka Terminal SSH'), findsOneWidget);

      // Verify Path Breadcrumb Bar
      expect(find.byIcon(Icons.edit_location_alt_rounded), findsOneWidget);

      // Verify Search / Filter bar
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Verify Remote File Listing items
      expect(find.text('nginx.conf'), findsOneWidget);
      expect(find.text('var'), findsOneWidget);
      expect(find.text('firewall.sh'), findsOneWidget);

      // Verify Floating Action Button for Upload
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('UNGGAH BERKAS'), findsOneWidget);
    });

    testWidgets('Tapping Terminal shortcut navigates to TerminalScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: SftpScreen(
              server: testServer,
              initialConnectionStateForTesting: SftpConnectionState.connected,
              initialItemsForTesting: sampleFiles,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final terminalShortcut = find.byTooltip('Buka Terminal SSH');
      expect(terminalShortcut, findsOneWidget);
      await tester.tap(terminalShortcut);
      await tester.pumpAndSettle();

      // Verify TerminalScreen opened
      expect(find.byType(TerminalScreen), findsOneWidget);
    });

    testWidgets('Tapping Jump to Path opens dialog with quick bookmarks', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: SftpScreen(
              server: testServer,
              initialConnectionStateForTesting: SftpConnectionState.connected,
              initialItemsForTesting: sampleFiles,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final jumpBtn = find.byIcon(Icons.edit_location_alt_rounded);
      expect(jumpBtn, findsOneWidget);
      await tester.tap(jumpBtn);
      await tester.pumpAndSettle();

      // Verify Jump Dialog rendered
      expect(find.text('Lompat ke Path'), findsOneWidget);
      expect(find.text('Bookmark Cepat:'), findsOneWidget);
      expect(find.text('Root'), findsOneWidget);
      expect(find.text('etc'), findsOneWidget);
      expect(find.text('Logs'), findsOneWidget);
      expect(find.text('Web'), findsOneWidget);
      expect(find.text('Tmp'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Lompat ke Path'), findsNothing);
    });

    testWidgets('Typing query in search bar filters file list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: SftpScreen(
              server: testServer,
              initialConnectionStateForTesting: SftpConnectionState.connected,
              initialItemsForTesting: sampleFiles,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('nginx.conf'), findsOneWidget);
      expect(find.text('firewall.sh'), findsOneWidget);
      expect(find.text('var'), findsOneWidget);

      // Enter search query "firewall"
      await tester.enterText(find.byType(TextField), 'firewall');
      await tester.pump();

      // Only firewall.sh should match
      expect(find.text('firewall.sh'), findsOneWidget);
      expect(find.text('nginx.conf'), findsNothing);
      expect(find.text('var'), findsNothing);
    });

    testWidgets('SftpScreen works on mobile viewport without overflowing', (tester) async {
      // Simulate mobile device width 390x844
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = SettingsProvider();
      await settings.init();
      final serverProvider = ServerProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: SftpScreen(server: testServer),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No overflow exceptions should occur
      expect(tester.takeException(), isNull);
      expect(find.byType(SftpScreen), findsOneWidget);
    });
  });

  group('FaqScreen Terminal & SFTP Documentation Tests', () {
    testWidgets('FaqScreen displays Terminal and SFTP documentation and code snippets', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
            home: FaqScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Filter by Server category or search for SFTP
      await tester.enterText(find.byType(TextField), 'SFTP');
      await tester.pumpAndSettle();

      // Verify SFTP question appears
      expect(find.text('Bagaimana cara menggunakan fitur SFTP File Manager di Aegis?'), findsOneWidget);

      // Tap to expand SFTP item
      await tester.tap(find.text('Bagaimana cara menggunakan fitur SFTP File Manager di Aegis?'));
      await tester.pumpAndSettle();

      // Verify explanation content appears
      expect(find.textContaining('Secure File Transfer Protocol'), findsWidgets);
      expect(find.textContaining('Bilah Breadcrumb Interaktif'), findsOneWidget);
      expect(find.textContaining('Editor Teks Jarak Jauh Bawaan'), findsOneWidget);
      expect(find.textContaining('chmod 644 /etc/nginx/nginx.conf'), findsOneWidget);

      // Clear search and search for Terminal
      await tester.enterText(find.byType(TextField), 'Terminal');
      await tester.pumpAndSettle();

      // Verify Terminal question appears
      expect(find.text('Bagaimana cara menggunakan Terminal SSH Interaktif di Aegis? Apa saja fiturnya?'), findsOneWidget);

      // Tap to expand Terminal item
      await tester.tap(find.text('Bagaimana cara menggunakan Terminal SSH Interaktif di Aegis? Apa saja fiturnya?'));
      await tester.pumpAndSettle();

      // Verify explanation content appears
      expect(find.textContaining('xterm-256color'), findsWidgets);
      expect(find.textContaining('Bilah Tombol Virtual'), findsOneWidget);
      expect(find.textContaining('Bilah Perintah Cepat SecOps'), findsOneWidget);
      expect(find.textContaining('sudo fail2ban-client status'), findsOneWidget);
    });
  });
}
