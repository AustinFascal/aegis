import 'dart:math';

enum PartitionStatus { healthy, warning, critical }

class CpuCoreMetric {
  final String name; // e.g. 'cpu0', 'cpu1' or 'Core 0'
  final double usage; // 0.0 to 100.0

  const CpuCoreMetric({
    required this.name,
    required this.usage,
  });

  String get displayName {
    if (name.startsWith('cpu')) {
      final idx = name.replaceFirst('cpu', '');
      return 'Core $idx';
    }
    return name;
  }

  Map<String, dynamic> toMap() => {'name': name, 'usage': usage};

  factory CpuCoreMetric.fromMap(Map<String, dynamic> map) {
    return CpuCoreMetric(
      name: map['name']?.toString() ?? 'cpu',
      usage: (map['usage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CpuTelemetry {
  final double overall; // 0.0 to 100.0
  final List<CpuCoreMetric> cores;
  final List<double> loadAvg; // [1m, 5m, 15m]
  final String? modelName;

  const CpuTelemetry({
    required this.overall,
    required this.cores,
    this.loadAvg = const [0.0, 0.0, 0.0],
    this.modelName,
  });

  int get coreCount => cores.length;

  String get loadAvgFormatted {
    if (loadAvg.length >= 3) {
      return '${loadAvg[0].toStringAsFixed(2)}, ${loadAvg[1].toStringAsFixed(2)}, ${loadAvg[2].toStringAsFixed(2)}';
    }
    return 'N/A';
  }

  Map<String, dynamic> toMap() => {
        'overall': overall,
        'cores': cores.map((c) => c.toMap()).toList(),
        'load_avg': loadAvg,
        'model_name': modelName,
      };

  factory CpuTelemetry.fromMap(Map<String, dynamic> map) {
    final rawCores = map['cores'] as List<dynamic>? ?? [];
    final cores = rawCores
        .map((c) => CpuCoreMetric.fromMap(c as Map<String, dynamic>))
        .toList();
    final rawLoad = map['load_avg'] as List<dynamic>? ?? [0.0, 0.0, 0.0];
    final loadAvg = rawLoad.map((x) => (x as num).toDouble()).toList();

    return CpuTelemetry(
      overall: (map['overall'] as num?)?.toDouble() ?? 0.0,
      cores: cores,
      loadAvg: loadAvg,
      modelName: map['model_name']?.toString(),
    );
  }
}

class RamTelemetry {
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final int availableBytes;
  final int cachedBytes;
  final int buffersBytes;
  final int swapTotal;
  final int swapUsed;
  final double usagePercent;

  const RamTelemetry({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.availableBytes,
    this.cachedBytes = 0,
    this.buffersBytes = 0,
    this.swapTotal = 0,
    this.swapUsed = 0,
    required this.usagePercent,
  });

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final clampedIndex = i.clamp(0, suffixes.length - 1);
    final val = bytes / pow(1024, clampedIndex);
    return '${val.toStringAsFixed(clampedIndex >= 3 ? 1 : 0)} ${suffixes[clampedIndex]}';
  }

  String get totalFormatted => formatBytes(totalBytes);
  String get usedFormatted => formatBytes(usedBytes);
  String get freeFormatted => formatBytes(freeBytes);
  String get availableFormatted => formatBytes(availableBytes);
  String get cachedFormatted => formatBytes(cachedBytes);
  String get swapUsedFormatted => formatBytes(swapUsed);
  String get swapTotalFormatted => formatBytes(swapTotal);

  Map<String, dynamic> toMap() => {
        'total_bytes': totalBytes,
        'used_bytes': usedBytes,
        'free_bytes': freeBytes,
        'available_bytes': availableBytes,
        'cached_bytes': cachedBytes,
        'buffers_bytes': buffersBytes,
        'swap_total': swapTotal,
        'swap_used': swapUsed,
        'usage_percent': usagePercent,
      };

  factory RamTelemetry.fromMap(Map<String, dynamic> map) {
    return RamTelemetry(
      totalBytes: (map['total_bytes'] as num?)?.toInt() ?? 0,
      usedBytes: (map['used_bytes'] as num?)?.toInt() ?? 0,
      freeBytes: (map['free_bytes'] as num?)?.toInt() ?? 0,
      availableBytes: (map['available_bytes'] as num?)?.toInt() ?? 0,
      cachedBytes: (map['cached_bytes'] as num?)?.toInt() ?? 0,
      buffersBytes: (map['buffers_bytes'] as num?)?.toInt() ?? 0,
      swapTotal: (map['swap_total'] as num?)?.toInt() ?? 0,
      swapUsed: (map['swap_used'] as num?)?.toInt() ?? 0,
      usagePercent: (map['usage_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PartitionHealth {
  final String filesystem;
  final String mount;
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;
  final double usagePercent;

  const PartitionHealth({
    required this.filesystem,
    required this.mount,
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
    required this.usagePercent,
  });

  PartitionStatus get status {
    if (usagePercent >= 90.0) return PartitionStatus.critical;
    if (usagePercent >= 75.0) return PartitionStatus.warning;
    return PartitionStatus.healthy;
  }

  String get totalFormatted => RamTelemetry.formatBytes(totalBytes);
  String get usedFormatted => RamTelemetry.formatBytes(usedBytes);
  String get availableFormatted => RamTelemetry.formatBytes(availableBytes);

  Map<String, dynamic> toMap() => {
        'filesystem': filesystem,
        'mount': mount,
        'total_bytes': totalBytes,
        'used_bytes': usedBytes,
        'available_bytes': availableBytes,
        'usage_percent': usagePercent,
      };

  factory PartitionHealth.fromMap(Map<String, dynamic> map) {
    final total = (map['total_bytes'] as num?)?.toInt() ?? 0;
    final used = (map['used_bytes'] as num?)?.toInt() ?? 0;
    var pct = (map['usage_percent'] as num?)?.toDouble() ?? 0.0;
    if (pct <= 0.0 && total > 0 && used > 0) {
      pct = double.parse(((used / total) * 100.0).toStringAsFixed(1));
    }
    final avail = (map['available_bytes'] as num?)?.toInt() ?? (total - used).clamp(0, total);

    return PartitionHealth(
      filesystem: map['filesystem']?.toString() ?? '',
      mount: map['mount']?.toString() ?? '/',
      totalBytes: total,
      usedBytes: used,
      availableBytes: avail,
      usagePercent: pct,
    );
  }
}

class NetworkSocketTelemetry {
  final int total;
  final int tcpInUse;
  final int tcpTimeWait;
  final int tcpAlloc;
  final int udpInUse;

  const NetworkSocketTelemetry({
    required this.total,
    required this.tcpInUse,
    this.tcpTimeWait = 0,
    this.tcpAlloc = 0,
    this.udpInUse = 0,
  });

  int get activeSockets => tcpInUse + udpInUse;

  Map<String, dynamic> toMap() => {
        'total': total,
        'tcp_inuse': tcpInUse,
        'tcp_tw': tcpTimeWait,
        'tcp_alloc': tcpAlloc,
        'udp_inuse': udpInUse,
      };

  factory NetworkSocketTelemetry.fromMap(Map<String, dynamic> map) {
    return NetworkSocketTelemetry(
      total: (map['total'] as num?)?.toInt() ?? 0,
      tcpInUse: (map['tcp_inuse'] as num?)?.toInt() ?? 0,
      tcpTimeWait: (map['tcp_tw'] as num?)?.toInt() ?? 0,
      tcpAlloc: (map['tcp_alloc'] as num?)?.toInt() ?? 0,
      udpInUse: (map['udp_inuse'] as num?)?.toInt() ?? 0,
    );
  }
}

class HardwareHistoryPoint {
  final DateTime timestamp;
  final double cpuPercent;
  final double ramPercent;

  const HardwareHistoryPoint({
    required this.timestamp,
    required this.cpuPercent,
    required this.ramPercent,
  });
}

class HardwareTelemetry {
  final String serverId;
  final DateTime timestamp;
  final CpuTelemetry cpu;
  final RamTelemetry ram;
  final List<PartitionHealth> partitions;
  final NetworkSocketTelemetry sockets;
  final int uptimeSeconds;
  final String uptimeFormatted;

  const HardwareTelemetry({
    required this.serverId,
    required this.timestamp,
    required this.cpu,
    required this.ram,
    required this.partitions,
    required this.sockets,
    required this.uptimeSeconds,
    required this.uptimeFormatted,
  });

  Map<String, dynamic> toMap() => {
        'server_id': serverId,
        'timestamp': timestamp.toIso8601String(),
        'cpu': cpu.toMap(),
        'ram': ram.toMap(),
        'partitions': partitions.map((p) => p.toMap()).toList(),
        'sockets': sockets.toMap(),
        'uptime_seconds': uptimeSeconds,
        'uptime_formatted': uptimeFormatted,
      };

  factory HardwareTelemetry.fromMap(
    Map<String, dynamic> map, {
    String? serverId,
    DateTime? timestamp,
  }) {
    final rawParts = map['partitions'] as List<dynamic>? ?? [];
    final partitions = rawParts
        .map((p) => PartitionHealth.fromMap(p as Map<String, dynamic>))
        .toList();

    return HardwareTelemetry(
      serverId: serverId ?? map['server_id']?.toString() ?? 'unknown',
      timestamp: timestamp ??
          (map['timestamp'] != null
              ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now()),
      cpu: CpuTelemetry.fromMap(map['cpu'] as Map<String, dynamic>? ?? {}),
      ram: RamTelemetry.fromMap(map['ram'] as Map<String, dynamic>? ?? {}),
      partitions: partitions,
      sockets: NetworkSocketTelemetry.fromMap(
          map['sockets'] as Map<String, dynamic>? ?? {}),
      uptimeSeconds: (map['uptime_seconds'] as num?)?.toInt() ?? 0,
      uptimeFormatted: map['uptime_formatted']?.toString() ?? 'Active',
    );
  }

  /// Generates a realistic mock snapshot for offline testing / demo simulation
  factory HardwareTelemetry.mock(String serverId, {double? baseCpu, double? baseRam}) {
    final rand = Random();
    final cpuVal = (baseCpu ?? (18.0 + rand.nextDouble() * 22.0)).clamp(5.0, 95.0);
    final ramVal = (baseRam ?? (42.0 + rand.nextDouble() * 8.0)).clamp(20.0, 90.0);

    final cores = List.generate(4, (i) {
      final coreUsage = (cpuVal + (rand.nextDouble() * 16.0 - 8.0)).clamp(2.0, 98.0);
      return CpuCoreMetric(
        name: 'cpu$i',
        usage: double.parse(coreUsage.toStringAsFixed(1)),
      );
    });

    const totalRam = 8 * 1024 * 1024 * 1024; // 8 GB
    final usedRam = (totalRam * (ramVal / 100.0)).toInt();
    final freeRam = totalRam - usedRam;

    return HardwareTelemetry(
      serverId: serverId,
      timestamp: DateTime.now(),
      cpu: CpuTelemetry(
        overall: double.parse(cpuVal.toStringAsFixed(1)),
        cores: cores,
        loadAvg: [
          double.parse((0.45 + rand.nextDouble() * 0.4).toStringAsFixed(2)),
          double.parse((0.65 + rand.nextDouble() * 0.3).toStringAsFixed(2)),
          double.parse((0.55 + rand.nextDouble() * 0.2).toStringAsFixed(2)),
        ],
        modelName: 'Intel Xeon E-2276G @ 3.80GHz (4 Cores)',
      ),
      ram: RamTelemetry(
        totalBytes: totalRam,
        usedBytes: usedRam,
        freeBytes: freeRam,
        availableBytes: (freeRam * 1.3).toInt().clamp(0, totalRam),
        cachedBytes: 1536 * 1024 * 1024,
        buffersBytes: 256 * 1024 * 1024,
        swapTotal: 4 * 1024 * 1024 * 1024,
        swapUsed: 512 * 1024 * 1024,
        usagePercent: double.parse(ramVal.toStringAsFixed(1)),
      ),
      partitions: [
        const PartitionHealth(
          filesystem: '/dev/sda1',
          mount: '/',
          totalBytes: 80 * 1024 * 1024 * 1024,
          usedBytes: 42 * 1024 * 1024 * 1024,
          availableBytes: 38 * 1024 * 1024 * 1024,
          usagePercent: 52.5,
        ),
        const PartitionHealth(
          filesystem: '/dev/sda2',
          mount: '/home',
          totalBytes: 320 * 1024 * 1024 * 1024,
          usedBytes: 110 * 1024 * 1024 * 1024,
          availableBytes: 210 * 1024 * 1024 * 1024,
          usagePercent: 34.4,
        ),
        const PartitionHealth(
          filesystem: '/dev/sda3',
          mount: '/var',
          totalBytes: 60 * 1024 * 1024 * 1024,
          usedBytes: 46 * 1024 * 1024 * 1024,
          availableBytes: 14 * 1024 * 1024 * 1024,
          usagePercent: 76.7,
        ),
      ],
      sockets: NetworkSocketTelemetry(
        total: 142 + rand.nextInt(15),
        tcpInUse: 34 + rand.nextInt(8),
        tcpTimeWait: 12 + rand.nextInt(5),
        tcpAlloc: 48,
        udpInUse: 6 + rand.nextInt(3),
      ),
      uptimeSeconds: 1572480,
      uptimeFormatted: '18d 4h 34m',
    );
  }
}
