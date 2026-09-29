import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/hardware_telemetry.dart';
import '../models/server_profile.dart';
import 'server_provider.dart';

class HardwareTelemetryProvider extends ChangeNotifier {
  final Map<String, HardwareTelemetry> _telemetryCache = {};
  final Map<String, List<HardwareHistoryPoint>> _historyCache = {};
  final Set<String> _realTelemetryServerIds = {};

  ServerProvider? _serverProvider;
  bool _isSampling = true;
  bool _isSamplingBusy = false;
  Duration _sampleInterval = const Duration(seconds: 3);
  bool _isDetailedView = false;
  bool _isLoading = false;
  DateTime? _lastSampledAt;
  Timer? _samplingTimer;

  bool get isSampling => _isSampling;
  Duration get sampleInterval => _sampleInterval;
  bool get isDetailedView => _isDetailedView;
  bool get isLoading => _isLoading;
  DateTime? get lastSampledAt => _lastSampledAt;

  String? _lastAttachedServerId;

  void attachServerProvider(ServerProvider sp) {
    _serverProvider = sp;
    final active = sp.activeServer;
    if (active != null && active.id != _lastAttachedServerId) {
      _lastAttachedServerId = active.id;
      if (sp.hasStoredCredential(active.id) || sp.isServerConnected(active.id) || active.isConnected) {
        sampleServer(serverProvider: sp, server: active, notify: false);
      }
    }
  }

  HardwareTelemetry? getTelemetryForServer(String? serverId) {
    if (serverId == null || serverId.isEmpty) {
      return _telemetryCache['default'] ?? _generateMockSnapshot('default');
    }
    return _telemetryCache[serverId] ?? _generateMockSnapshot(serverId);
  }

  List<HardwareHistoryPoint> getHistoryForServer(String? serverId) {
    final id = (serverId == null || serverId.isEmpty) ? 'default' : serverId;
    return List.unmodifiable(_historyCache[id] ?? []);
  }

  HardwareTelemetryProvider() {
    _initSeedData('srv_rumahweb_01');
    _initSeedData('default');
    _startSamplingLoop();
  }

  void _initSeedData(String serverId) {
    final mock = HardwareTelemetry.mock(serverId);
    _telemetryCache[serverId] = mock;

    final now = DateTime.now();
    final history = <HardwareHistoryPoint>[];
    for (int i = 15; i >= 0; i--) {
      final t = now.subtract(Duration(seconds: i * 3));
      final cpuP = (mock.cpu.overall + (i % 5 - 2) * 1.5).clamp(5.0, 95.0);
      final ramP = (mock.ram.usagePercent + (i % 3 - 1) * 0.4).clamp(10.0, 90.0);
      history.add(HardwareHistoryPoint(
        timestamp: t,
        cpuPercent: double.parse(cpuP.toStringAsFixed(1)),
        ramPercent: double.parse(ramP.toStringAsFixed(1)),
      ));
    }
    _historyCache[serverId] = history;
  }

  HardwareTelemetry _generateMockSnapshot(String serverId) {
    final prev = _telemetryCache[serverId];
    if (prev != null) {
      return _fluctuateExisting(prev);
    }
    final mock = HardwareTelemetry.mock(serverId);
    _telemetryCache[serverId] = mock;
    return mock;
  }

  HardwareTelemetry _fluctuateExisting(HardwareTelemetry prev) {
    final rand = Random();
    final dCpu = (rand.nextDouble() * 3.0 - 1.5);
    final newCpu = (prev.cpu.overall + dCpu).clamp(1.0, 99.0);
    final dRam = (rand.nextDouble() * 0.2 - 0.1);
    final newRamPct = (prev.ram.usagePercent + dRam).clamp(5.0, 95.0);

    final updatedCores = prev.cpu.cores.map((c) {
      final cUsage = (c.usage + (rand.nextDouble() * 4.0 - 2.0)).clamp(0.0, 100.0);
      return CpuCoreMetric(name: c.name, usage: double.parse(cUsage.toStringAsFixed(1)));
    }).toList();

    final totalRam = prev.ram.totalBytes;
    final usedRam = (totalRam * (newRamPct / 100.0)).toInt();
    final freeRam = (totalRam - usedRam).clamp(0, totalRam);
    final availRam = prev.ram.availableBytes > 0
        ? (prev.ram.availableBytes - (usedRam - prev.ram.usedBytes)).clamp(0, totalRam)
        : freeRam;

    final upSec = prev.uptimeSeconds + _sampleInterval.inSeconds;
    final d = upSec ~/ 86400;
    final h = (upSec % 86400) ~/ 3600;
    final m = (upSec % 3600) ~/ 60;
    final upFmt = d > 0 ? '${d}d ${h}h ${m}m' : (h > 0 ? '${h}h ${m}m' : '${m}m');

    return HardwareTelemetry(
      serverId: prev.serverId,
      timestamp: DateTime.now(),
      cpu: CpuTelemetry(
        overall: double.parse(newCpu.toStringAsFixed(1)),
        cores: updatedCores,
        loadAvg: prev.cpu.loadAvg,
        modelName: prev.cpu.modelName,
      ),
      ram: RamTelemetry(
        totalBytes: totalRam,
        usedBytes: usedRam,
        freeBytes: freeRam,
        availableBytes: availRam,
        cachedBytes: prev.ram.cachedBytes,
        buffersBytes: prev.ram.buffersBytes,
        swapTotal: prev.ram.swapTotal,
        swapUsed: prev.ram.swapUsed,
        usagePercent: double.parse(newRamPct.toStringAsFixed(1)),
      ),
      partitions: prev.partitions.isNotEmpty && prev.partitions.any((p) => p.totalBytes > 0)
          ? prev.partitions
          : HardwareTelemetry.mock(prev.serverId).partitions,
      sockets: NetworkSocketTelemetry(
        total: prev.sockets.total,
        tcpInUse: (prev.sockets.tcpInUse + (rand.nextInt(3) - 1)).clamp(0, prev.sockets.total),
        tcpTimeWait: prev.sockets.tcpTimeWait,
        tcpAlloc: prev.sockets.tcpAlloc,
        udpInUse: prev.sockets.udpInUse,
      ),
      uptimeSeconds: upSec,
      uptimeFormatted: upFmt,
    );
  }

  void _startSamplingLoop() {
    _samplingTimer?.cancel();
    _samplingTimer = Timer.periodic(_sampleInterval, (timer) {
      if (!_isSampling) return;
      _tickSampling();
    });
  }

  Future<void> _tickSampling() async {
    if (!_isSampling || _isSamplingBusy) return;

    final sp = _serverProvider;
    final active = sp?.activeServer;

    // 1. If actively connected to real remote server or has stored credentials, continuously poll real SSH hardware telemetry
    if (sp != null && active != null && (sp.hasStoredCredential(active.id) || sp.isServerConnected(active.id) || active.isConnected)) {
      await sampleServer(serverProvider: sp, server: active, notify: true);
      return;
    }

    // 2. Offline / simulation fallback: gently fluctuate without modifying actual hardware specs
    for (final serverId in _telemetryCache.keys) {
      final prev = _telemetryCache[serverId]!;
      final updated = _fluctuateExisting(prev);
      _telemetryCache[serverId] = updated;

      final history = _historyCache.putIfAbsent(serverId, () => []);
      history.add(HardwareHistoryPoint(
        timestamp: DateTime.now(),
        cpuPercent: updated.cpu.overall,
        ramPercent: updated.ram.usagePercent,
      ));
      if (history.length > 25) {
        history.removeAt(0);
      }
    }
    _lastSampledAt = DateTime.now();
    notifyListeners();
  }

  /// Triggers a live hardware sample via ServerProvider and SSH
  Future<void> sampleServer({
    required ServerProvider serverProvider,
    ServerProfile? server,
    bool notify = true,
    bool isManual = false,
  }) async {
    final target = server ?? serverProvider.activeServer;
    if (target == null) return;
    if (_isSamplingBusy) return;

    _isSamplingBusy = true;
    if (isManual) {
      _isLoading = true;
    }
    if (notify) notifyListeners();

    try {
      HardwareTelemetry? realData;
      if (serverProvider.hasStoredCredential(target.id) ||
          serverProvider.isServerConnected(target.id) ||
          target.isConnected) {
        realData = await serverProvider.fetchHardwareTelemetry(server: target);
      }

      if (realData != null) {
        _realTelemetryServerIds.add(target.id);
        _telemetryCache[target.id] = realData;
      } else {
        // Fallback: If we already have existing data for target, gently fluctuate preserving real hardware topology
        if (_telemetryCache.containsKey(target.id)) {
          _telemetryCache[target.id] = _fluctuateExisting(_telemetryCache[target.id]!);
        } else {
          _telemetryCache[target.id] = _generateMockSnapshot(target.id);
        }
      }

      final current = _telemetryCache[target.id]!;
      final history = _historyCache.putIfAbsent(target.id, () => []);
      history.add(HardwareHistoryPoint(
        timestamp: DateTime.now(),
        cpuPercent: current.cpu.overall,
        ramPercent: current.ram.usagePercent,
      ));
      if (history.length > 25) {
        history.removeAt(0);
      }
      _lastSampledAt = DateTime.now();
    } catch (e) {
      debugPrint('[HardwareTelemetryProvider] Sample error: $e');
    } finally {
      _isLoading = false;
      _isSamplingBusy = false;
      notifyListeners();
    }
  }

  void toggleSampling() {
    _isSampling = !_isSampling;
    notifyListeners();
  }

  void setSampleInterval(Duration interval) {
    if (_sampleInterval != interval) {
      _sampleInterval = interval;
      _startSamplingLoop();
      notifyListeners();
    }
  }

  void toggleDetailedView() {
    _isDetailedView = !_isDetailedView;
    notifyListeners();
  }

  @override
  void dispose() {
    _samplingTimer?.cancel();
    super.dispose();
  }
}
