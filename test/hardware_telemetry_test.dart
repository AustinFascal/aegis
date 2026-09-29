import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aegis/models/hardware_telemetry.dart';
import 'package:aegis/models/server_profile.dart';
import 'package:aegis/providers/hardware_telemetry_provider.dart';
import 'package:aegis/providers/server_provider.dart';
import 'package:aegis/providers/settings_provider.dart';
import 'package:aegis/providers/theme_provider.dart';
import 'package:aegis/ui/widgets/hardware_telemetry_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HardwareTelemetry Models Unit Tests', () {
    test('CpuCoreMetric displayName and serialization', () {
      const core = CpuCoreMetric(name: 'cpu0', usage: 25.4);
      expect(core.displayName, equals('Core 0'));
      expect(core.usage, equals(25.4));

      final map = core.toMap();
      final revived = CpuCoreMetric.fromMap(map);
      expect(revived.name, equals('cpu0'));
      expect(revived.usage, equals(25.4));
    });

    test('CpuTelemetry coreCount and loadAvgFormatted', () {
      const cpu = CpuTelemetry(
        overall: 32.5,
        cores: [
          CpuCoreMetric(name: 'cpu0', usage: 40.0),
          CpuCoreMetric(name: 'cpu1', usage: 25.0),
        ],
        loadAvg: [0.55, 0.70, 0.65],
        modelName: 'AMD EPYC 7763',
      );

      expect(cpu.coreCount, equals(2));
      expect(cpu.overall, equals(32.5));
      expect(cpu.loadAvgFormatted, equals('0.55, 0.70, 0.65'));
      expect(cpu.modelName, equals('AMD EPYC 7763'));

      final map = cpu.toMap();
      final fromJson = CpuTelemetry.fromMap(map);
      expect(fromJson.coreCount, equals(2));
      expect(fromJson.overall, equals(32.5));
      expect(fromJson.loadAvg, equals([0.55, 0.70, 0.65]));
    });

    test('RamTelemetry bytes formatting and percentage calculation', () {
      const ram = RamTelemetry(
        totalBytes: 16 * 1024 * 1024 * 1024, // 16 GB
        usedBytes: 8 * 1024 * 1024 * 1024,  // 8 GB
        freeBytes: 4 * 1024 * 1024 * 1024,
        availableBytes: 8 * 1024 * 1024 * 1024,
        cachedBytes: 3 * 1024 * 1024 * 1024,
        buffersBytes: 1 * 1024 * 1024 * 1024,
        swapTotal: 4 * 1024 * 1024 * 1024,
        swapUsed: 1 * 1024 * 1024 * 1024,
        usagePercent: 50.0,
      );

      expect(ram.totalFormatted, contains('16'));
      expect(ram.usedFormatted, contains('8'));
      expect(ram.freeFormatted, contains('4'));
      expect(ram.usagePercent, equals(50.0));

      final map = ram.toMap();
      final fromJson = RamTelemetry.fromMap(map);
      expect(fromJson.totalBytes, equals(ram.totalBytes));
      expect(fromJson.usagePercent, equals(50.0));
    });

    test('PartitionHealth status levels and formatting', () {
      const partHealthy = PartitionHealth(
        filesystem: '/dev/sda1',
        mount: '/',
        totalBytes: 100 * 1024 * 1024 * 1024,
        usedBytes: 50 * 1024 * 1024 * 1024,
        availableBytes: 50 * 1024 * 1024 * 1024,
        usagePercent: 50.0,
      );
      expect(partHealthy.status, equals(PartitionStatus.healthy));

      const partWarning = PartitionHealth(
        filesystem: '/dev/sda2',
        mount: '/home',
        totalBytes: 100 * 1024 * 1024 * 1024,
        usedBytes: 80 * 1024 * 1024 * 1024,
        availableBytes: 20 * 1024 * 1024 * 1024,
        usagePercent: 80.0,
      );
      expect(partWarning.status, equals(PartitionStatus.warning));

      const partCritical = PartitionHealth(
        filesystem: '/dev/sda3',
        mount: '/var',
        totalBytes: 100 * 1024 * 1024 * 1024,
        usedBytes: 95 * 1024 * 1024 * 1024,
        availableBytes: 5 * 1024 * 1024 * 1024,
        usagePercent: 95.0,
      );
      expect(partCritical.status, equals(PartitionStatus.critical));
    });

    test('NetworkSocketTelemetry active socket counters', () {
      const sockets = NetworkSocketTelemetry(
        total: 250,
        tcpInUse: 45,
        tcpTimeWait: 15,
        tcpAlloc: 60,
        udpInUse: 10,
      );
      expect(sockets.total, equals(250));
      expect(sockets.tcpInUse, equals(45));
      expect(sockets.udpInUse, equals(10));
      expect(sockets.activeSockets, equals(55));
    });

    test('HardwareTelemetry.mock generates realistic snapshot', () {
      final mock = HardwareTelemetry.mock('srv_test_01');
      expect(mock.serverId, equals('srv_test_01'));
      expect(mock.cpu.coreCount, equals(4));
      expect(mock.cpu.overall, greaterThan(0.0));
      expect(mock.ram.totalBytes, greaterThan(0));
      expect(mock.partitions.isNotEmpty, isTrue);
      expect(mock.sockets.total, greaterThan(0));
      expect(mock.uptimeFormatted.isNotEmpty, isTrue);
    });
  });

  group('HardwareTelemetryProvider State Tests', () {
    test('Initializes with default mock telemetry and history points', () {
      final provider = HardwareTelemetryProvider();
      final telem = provider.getTelemetryForServer('srv_rumahweb_01');
      expect(telem, isNotNull);
      expect(telem!.cpu.overall, greaterThan(0.0));

      final history = provider.getHistoryForServer('srv_rumahweb_01');
      expect(history.length, greaterThan(10));
      provider.dispose();
    });

    test('Toggles sampling and changes interval cleanly', () {
      final provider = HardwareTelemetryProvider();
      expect(provider.isSampling, isTrue);

      provider.toggleSampling();
      expect(provider.isSampling, isFalse);

      provider.toggleSampling();
      expect(provider.isSampling, isTrue);

      provider.setSampleInterval(const Duration(seconds: 5));
      expect(provider.sampleInterval.inSeconds, equals(5));

      provider.toggleDetailedView();
      expect(provider.isDetailedView, isTrue);

      provider.dispose();
    });
  });

  group('HardwareTelemetryCard Widget Tests', () {
    testWidgets('Renders HardwareTelemetryCard with CPU, RAM, Partitions, Sockets', (tester) async {
      final hwProvider = HardwareTelemetryProvider();
      final serverProvider = ServerProvider();
      final settingsProvider = SettingsProvider();
      final themeProvider = ThemeProvider();

      const testServer = ServerProfile(
        id: 'srv_test_01',
        name: 'Production Node 1',
        host: '10.0.0.1',
        port: 22,
        username: 'admin',
        isConnected: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: hwProvider),
            ChangeNotifierProvider.value(value: serverProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HardwareTelemetryCard(activeServer: testServer),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and live badge
      expect(find.text(settingsProvider.t('hardware_telemetry_heading')), findsOneWidget);
      expect(find.textContaining('LIVE'), findsOneWidget);

      // Check primary metric labels
      expect(find.text(settingsProvider.t('cpu_utilization')), findsOneWidget);
      expect(find.text(settingsProvider.t('ram_usage')), findsOneWidget);
      expect(find.text(settingsProvider.t('partition_health')), findsOneWidget);
      expect(find.text(settingsProvider.t('active_sockets')), findsOneWidget);

      // Check pause sampling interaction
      final pauseBtn = find.byIcon(Icons.pause_circle_outline_rounded);
      expect(pauseBtn, findsOneWidget);
      await tester.tap(pauseBtn);
      await tester.pumpAndSettle();
      expect(hwProvider.isSampling, isFalse);

      // Check expand details interaction
      final expandBtn = find.byIcon(Icons.unfold_more_rounded);
      expect(expandBtn, findsOneWidget);
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();
      expect(hwProvider.isDetailedView, isTrue);

      // Verify detailed multi-core section and partition health list
      expect(find.textContaining('CPU'), findsWidgets);
      expect(find.textContaining('PARTISI'), findsWidgets);

      hwProvider.dispose();
    });
  });
}
