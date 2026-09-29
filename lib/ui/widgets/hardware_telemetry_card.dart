import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hardware_telemetry.dart';
import '../../models/server_profile.dart';
import '../../providers/hardware_telemetry_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';

class HardwareTelemetryCard extends StatefulWidget {
  final ServerProfile? activeServer;

  const HardwareTelemetryCard({super.key, this.activeServer});

  @override
  State<HardwareTelemetryCard> createState() => _HardwareTelemetryCardState();
}

class _HardwareTelemetryCardState extends State<HardwareTelemetryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getUsageColor(double usage, bool isDark) {
    if (usage >= 85.0) {
      return isDark ? AppColors.danger : AppColors.dangerLight;
    } else if (usage >= 70.0) {
      return isDark ? AppColors.warning : AppColors.warningLight;
    }
    return isDark ? AppColors.primary : AppColors.primaryLight;
  }

  Color _getPartitionStatusColor(PartitionStatus status, bool isDark) {
    switch (status) {
      case PartitionStatus.critical:
        return isDark ? AppColors.danger : AppColors.dangerLight;
      case PartitionStatus.warning:
        return isDark ? AppColors.warning : AppColors.warningLight;
      case PartitionStatus.healthy:
        return isDark ? AppColors.success : AppColors.successLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final hwProvider = Provider.of<HardwareTelemetryProvider?>(context);
    final serverProvider = context.watch<ServerProvider>();

    if (hwProvider != null) {
      hwProvider.attachServerProvider(serverProvider);
    }

    final serverId = widget.activeServer?.id;
    final telemetry = hwProvider?.getTelemetryForServer(serverId) ??
        HardwareTelemetry.mock(serverId ?? 'default');
    final history = hwProvider?.getHistoryForServer(serverId) ?? const [];

    final isDetailed = hwProvider?.isDetailedView ?? false;
    final isSampling = hwProvider?.isSampling ?? true;
    final intervalSec = hwProvider?.sampleInterval.inSeconds ?? 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Toolbar
          _buildHeader(
            context,
            settings,
            hwProvider,
            serverProvider,
            isDark,
            isSampling,
            intervalSec,
            isDetailed,
          ),

          const SizedBox(height: 16),

          // 2. Primary 4 KPI Metrics Grid (CPU, RAM, Partitions, Sockets & Uptime)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cols = width >= 900 ? 4 : (width >= 480 ? 2 : 1);

              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 112,
                ),
                children: [
                  _buildCpuMetricTile(telemetry.cpu, isDark, settings),
                  _buildRamMetricTile(telemetry.ram, isDark, settings),
                  _buildPartitionMetricTile(
                    telemetry.partitions,
                    isDark,
                    settings,
                  ),
                  _buildSocketsUptimeTile(
                    telemetry.sockets,
                    telemetry.uptimeFormatted,
                    isDark,
                    settings,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // 3. Real-Time Telemetry Trend Sparkline (fl_chart)
          _buildTrendChart(history, isDark, settings),

          // 4. In-Depth Collapsible Section (Multi-Core Visualizer & Partition Details)
          if (isDetailed) ...[
            const SizedBox(height: 18),
            _buildDetailedMultiCoreSection(telemetry.cpu, isDark, settings),
            const SizedBox(height: 16),
            _buildDetailedPartitionsSection(telemetry.partitions, isDark, settings),
            const SizedBox(height: 16),
            _buildDetailedSocketsSection(telemetry.sockets, isDark, settings),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SettingsProvider settings,
    HardwareTelemetryProvider? hwProvider,
    ServerProvider serverProvider,
    bool isDark,
    bool isSampling,
    int intervalSec,
    bool isDetailed,
  ) {
    final theme = Theme.of(context);
    final isIndo = settings.isIndonesian;

    return LayoutBuilder(
      builder: (context, headerConstraints) {
        final isCompact = headerConstraints.maxWidth < 520;

        final titleWidget = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.memory_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        settings.t('hardware_telemetry_heading'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      // Live pulsating badge
                      FadeTransition(
                        opacity: isSampling ? _pulseController : const AlwaysStoppedAnimation(1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isSampling ? AppColors.success : AppColors.warning)
                                .withValues(alpha: isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (isSampling ? AppColors.success : AppColors.warning)
                                  .withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSampling
                                      ? (isDark ? AppColors.success : AppColors.successLight)
                                      : (isDark ? AppColors.warning : AppColors.warningLight),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSampling ? '${intervalSec}s LIVE' : settings.t('sampling_paused'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isSampling
                                      ? (isDark ? AppColors.success : AppColors.successLight)
                                      : (isDark ? AppColors.warning : AppColors.warningLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    settings.t('hardware_telemetry_sub'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final toolbarWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pause / Resume Toggle
            IconButton(
              icon: Icon(
                isSampling ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                size: 20,
              ),
              color: isSampling
                  ? (isDark ? AppColors.warning : AppColors.warningLight)
                  : (isDark ? AppColors.success : AppColors.successLight),
              tooltip: isSampling
                  ? (isIndo ? 'Jeda Sampling' : 'Pause Sampling')
                  : (isIndo ? 'Lanjutkan Sampling' : 'Resume Sampling'),
              onPressed: () => hwProvider?.toggleSampling(),
            ),

            // Interval Selector Menu
            PopupMenuButton<int>(
              icon: Icon(
                Icons.speed_rounded,
                size: 20,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
              tooltip: isIndo ? 'Ubah Frekuensi Sampling' : 'Change Sampling Rate',
              onSelected: (sec) {
                hwProvider?.setSampleInterval(Duration(seconds: sec));
              },
              itemBuilder: (context) => [
                _buildIntervalMenuItem(2, '2s (High Frequency)', intervalSec),
                _buildIntervalMenuItem(3, '3s (Default Balanced)', intervalSec),
                _buildIntervalMenuItem(5, '5s (Eco Polling)', intervalSec),
                _buildIntervalMenuItem(10, '10s (Low Overhead)', intervalSec),
              ],
            ),

            // Refresh Now Button
            IconButton(
              icon: hwProvider?.isLoading == true
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              color: theme.colorScheme.primary,
              tooltip: isIndo ? 'Sampel Sekarang' : 'Sample Now',
              onPressed: hwProvider?.isLoading == true
                  ? null
                  : () => hwProvider?.sampleServer(
                        serverProvider: serverProvider,
                        server: widget.activeServer,
                      ),
            ),

            // Detailed View Toggle
            IconButton(
              icon: Icon(
                isDetailed ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                size: 20,
              ),
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              tooltip: isDetailed
                  ? (isIndo ? 'Tutup Rincian' : 'Collapse Details')
                  : (isIndo ? 'Rincian CPU & Partisi' : 'Expand Details'),
              onPressed: () => hwProvider?.toggleDetailedView(),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: toolbarWidget,
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 8),
            toolbarWidget,
          ],
        );
      },
    );
  }

  PopupMenuItem<int> _buildIntervalMenuItem(int sec, String label, int current) {
    return PopupMenuItem<int>(
      value: sec,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          if (sec == current)
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 16),
        ],
      ),
    );
  }

  Widget _buildCpuMetricTile(
    CpuTelemetry cpu,
    bool isDark,
    SettingsProvider settings,
  ) {
    final color = _getUsageColor(cpu.overall, isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.developer_board_rounded, color: color, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        settings.t('cpu_utilization'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${cpu.coreCount} Cores',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${cpu.overall.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (cpu.overall / 100.0).clamp(0.0, 1.0),
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Load: ${cpu.loadAvgFormatted}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRamMetricTile(
    RamTelemetry ram,
    bool isDark,
    SettingsProvider settings,
  ) {
    final color = _getUsageColor(ram.usagePercent, isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, color: color, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        settings.t('ram_usage'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${ram.usagePercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      ram.usedFormatted,
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      ' / ${ram.totalFormatted}',
                      style: TextStyle(
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (ram.usagePercent / 100.0).clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartitionMetricTile(
    List<PartitionHealth> partitions,
    bool isDark,
    SettingsProvider settings,
  ) {
    final validPartitions = partitions.where((p) => p.totalBytes > 0).toList();
    final rootPart = validPartitions.firstWhere(
      (p) => p.mount == '/',
      orElse: () => validPartitions.isNotEmpty
          ? validPartitions.first
          : (partitions.isNotEmpty
              ? partitions.first
              : HardwareTelemetry.mock('default').partitions.first),
    );
    final effectivePct = (rootPart.usagePercent <= 0.0 && rootPart.totalBytes > 0 && rootPart.usedBytes > 0)
        ? double.parse(((rootPart.usedBytes / rootPart.totalBytes) * 100.0).toStringAsFixed(1))
        : rootPart.usagePercent;
    final color = _getPartitionStatusColor(rootPart.status, isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storage_rounded, color: color, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        settings.t('partition_health'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rootPart.status.name.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${rootPart.mount} ${effectivePct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${rootPart.usedFormatted}/${rootPart.totalFormatted})',
                      style: TextStyle(
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (effectivePct / 100.0).clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocketsUptimeTile(
    NetworkSocketTelemetry sockets,
    String uptime,
    bool isDark,
    SettingsProvider settings,
  ) {
    const color = AppColors.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub_rounded, color: color, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        settings.t('active_sockets'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    uptime,
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${sockets.activeSockets}',
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'active (${sockets.total} total)',
                      style: TextStyle(
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'TCP: ${sockets.tcpInUse} • UDP: ${sockets.udpInUse} • TW: ${sockets.tcpTimeWait}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(
    List<HardwareHistoryPoint> history,
    bool isDark,
    SettingsProvider settings,
  ) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    final isIndo = settings.isIndonesian;
    final cpuSpots = <FlSpot>[];
    final ramSpots = <FlSpot>[];

    for (int i = 0; i < history.length; i++) {
      cpuSpots.add(FlSpot(i.toDouble(), history[i].cpuPercent));
      ramSpots.add(FlSpot(i.toDouble(), history[i].ramPercent));
    }

    final cpuColor = isDark ? AppColors.primary : AppColors.primaryLight;
    final ramColor = isDark ? AppColors.purple : AppColors.purpleLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                isIndo ? 'TREN SAMPLING REALTIME (15 SAMPEL)' : 'REAL-TIME SAMPLING TREND (15 SAMPLES)',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem('CPU', cpuColor),
                  const SizedBox(width: 12),
                  _buildLegendItem('RAM', ramColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                minX: 0,
                maxX: (history.length - 1).toDouble().clamp(1.0, 30.0),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                        .withValues(alpha: 0.5),
                    strokeWidth: 0.8,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 50,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: cpuSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: cpuColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: cpuColor.withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: ramSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: ramColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: ramColor.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMultiCoreSection(
    CpuTelemetry cpu,
    bool isDark,
    SettingsProvider settings,
  ) {
    final isIndo = settings.isIndonesian;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              isIndo ? 'PENGGUNAAN MULTI-CORE CPU' : 'MULTI-CORE CPU UTILIZATION',
              style: TextStyle(
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            if (cpu.modelName != null)
              Text(
                cpu.modelName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  fontSize: 9,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 700
                ? 4
                : (constraints.maxWidth >= 450 ? 2 : 2);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 44,
              ),
              itemCount: cpu.cores.length,
              itemBuilder: (context, index) {
                final core = cpu.cores[index];
                final color = _getUsageColor(core.usage, isDark);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        core.displayName,
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (core.usage / 100.0).clamp(0.0, 1.0),
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${core.usage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailedPartitionsSection(
    List<PartitionHealth> partitions,
    bool isDark,
    SettingsProvider settings,
  ) {
    final isIndo = settings.isIndonesian;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isIndo ? 'KESEHATAN PARTISI & PENYIMPANAN' : 'PARTITION HEALTH & STORAGE',
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: partitions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final part = partitions[index];
            final color = _getPartitionStatusColor(part.status, isDark);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 520;

                if (isCompact) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: themeColor(context).colorScheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      part.mount,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        color: themeColor(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      part.filesystem,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                part.status.name.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${part.usagePercent.toStringAsFixed(1)}% Used',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${part.usedFormatted} / ${part.totalFormatted}',
                              style: TextStyle(
                                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (part.usagePercent / 100.0).clamp(0.0, 1.0),
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColor(context).colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            part.mount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: themeColor(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    part.filesystem,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${part.usedFormatted} / ${part.totalFormatted} (${part.usagePercent.toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (part.usagePercent / 100.0).clamp(0.0, 1.0),
                                backgroundColor: color.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          part.status.name.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailedSocketsSection(
    NetworkSocketTelemetry sockets,
    bool isDark,
    SettingsProvider settings,
  ) {
    final isIndo = settings.isIndonesian;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isIndo ? 'RINCIAN SOKET JARINGAN KERNEL' : 'KERNEL NETWORK SOCKET BREAKDOWN',
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildSocketChip('TCP In-Use', '${sockets.tcpInUse}', AppColors.primary, isDark),
              _buildSocketChip('TCP Time-Wait', '${sockets.tcpTimeWait}', AppColors.warning, isDark),
              _buildSocketChip('TCP Allocated', '${sockets.tcpAlloc}', AppColors.info, isDark),
              _buildSocketChip('UDP In-Use', '${sockets.udpInUse}', AppColors.success, isDark),
              _buildSocketChip('Total Sockets', '${sockets.total}', AppColors.textMuted, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocketChip(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  ThemeData themeColor(BuildContext context) => Theme.of(context);
}
