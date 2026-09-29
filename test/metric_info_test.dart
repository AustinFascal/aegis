import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/ui/widgets/metric_card.dart';
import 'package:aegis/ui/widgets/metric_info_dialog.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/telemetry_provider.dart';
import 'package:aegis/providers/policy_provider.dart';
import 'package:aegis/ui/screens/dashboard_screen.dart';
import 'package:aegis/models/server_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetricCard & MetricInfoDialog Tests', () {
    testWidgets('MetricCard displays info icon and triggers onInfoTap when tapped', (tester) async {
      bool infoTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Failed Logins',
              value: '12',
              subtitle: 'Last 24 Hours',
              icon: Icons.cancel_outlined,
              infoTooltip: 'Explain metric',
              onInfoTap: () {
                infoTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify title, value, subtitle and info icon are rendered
      expect(find.text('FAILED LOGINS'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Last 24 Hours'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Tap info icon
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(infoTapped, isTrue);
    });

    testWidgets('MetricInfoDialog renders details and actions for Failed Logins', (tester) async {
      bool auditExplored = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MetricInfoDialog.show(
                      context,
                      type: MetricType.failedLogins,
                      currentValue: '8',
                      accentColor: Colors.red,
                      isIndo: true,
                      isDark: true,
                      onExploreAudit: () {
                        auditExplored = true;
                      },
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Dialog content verification
      expect(find.text('Percobaan Login Gagal'), findsOneWidget);
      expect(find.text('NILAI SAAT INI'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Perlu Perhatian (Tinggi)'), findsOneWidget);
      expect(find.text('Deskripsi & Definisi'), findsOneWidget);
      expect(find.text('Sumber Log & Formula'), findsOneWidget);
      expect(find.text('Panduan Ambang Batas & Tindakan'), findsOneWidget);
      expect(find.text('Buka Audit Explorer'), findsOneWidget);

      // Tap Buka Audit Explorer button
      await tester.ensureVisible(find.text('Buka Audit Explorer'));
      await tester.tap(find.text('Buka Audit Explorer'));
      await tester.pumpAndSettle();

      expect(auditExplored, isTrue);
    });

    testWidgets('DashboardScreen renders info buttons on all 4 metric cards and opens info sheet on tap', (tester) async {
      final themeProvider = ThemeProvider();
      final settingsProvider = SettingsProvider();
      final serverProvider = ServerProvider();
      final telemetryProvider = TelemetryProvider();
      final policyProvider = PolicyProvider();

      // Add a dummy server so dashboard renders the metrics grid
      await serverProvider.addServer(
        name: 'Test Server',
        host: '10.0.0.1',
        port: 22,
        username: 'root',
        authType: AuthType.password,
        credential: 'testpassword',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: telemetryProvider),
            ChangeNotifierProvider.value(value: policyProvider),
          ],
          child: MaterialApp(
            home: DashboardScreen(onNavigateToTab: (_) {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should find 4 info outline icons (one on each metric card)
      final infoIcons = find.byIcon(Icons.info_outline_rounded);
      expect(infoIcons, findsNWidgets(4));

      // Tap the first info button (Failed Logins)
      await tester.tap(infoIcons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should open the MetricInfoDialog
      expect(find.byType(MetricInfoDialog), findsOneWidget);
      expect(find.text('Deskripsi & Definisi'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      // Close the modal via header close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MetricInfoDialog), findsNothing);

      telemetryProvider.dispose();
    });
  });
}
