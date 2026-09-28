import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/server_metrics.dart';
import '../../providers/settings_provider.dart';

class ThreatTimelineChart extends StatelessWidget {
  final List<TimeSeriesPoint> points;

  const ThreatTimelineChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider?>(context);
    final isIndo = settings?.isIndonesian ?? false;

    if (points.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Text(
          isIndo ? 'Tidak ada data linimasa 24 jam' : 'No timeline data available',
          style: TextStyle(
            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
          ),
        ),
      );
    }

    final failedSpots = points.map((p) {
      return FlSpot(p.hour.toDouble(), p.failedCount.toDouble());
    }).toList();

    final successSpots = points.map((p) {
      return FlSpot(p.hour.toDouble(), p.successCount.toDouble());
    }).toList();

    int maxVal = 0;
    for (final p in points) {
      if (p.failedCount > maxVal) maxVal = p.failedCount;
      if (p.successCount > maxVal) maxVal = p.successCount;
    }
    final maxY = maxVal < 4 ? 4.0 : (maxVal + 2).toDouble();

    final dangerColor = isDark ? AppColors.danger : AppColors.dangerLight;
    final successColor = isDark ? AppColors.success : AppColors.successLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 16, 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    isIndo ? 'AKTIVITAS LOGIN & INTRUSI 24 JAM' : '24H LOGIN ACTIVITY & INCURSIONS',
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isIndo ? '24 JAM DARI SEKARANG' : 'LAST 24H ROLLING',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildLegend(dangerColor, isIndo ? 'Gagal / Intrusi' : 'Failed / Incursions', isDark),
                  _buildLegend(successColor, isIndo ? 'Terotorisasi' : 'Authorized', isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.spotIndex;
                        if (idx < 0 || idx >= points.length) return null;
                        final point = points[idx];
                        final isFailed = spot.barIndex == 0;
                        final name = isFailed
                            ? (isIndo ? 'Gagal / Intrusi' : 'Failed / Incursions')
                            : (isIndo ? 'Terotorisasi' : 'Authorized');
                        final color = isFailed ? dangerColor : successColor;
                        final timeTitle = point.label.isNotEmpty ? point.label : '${point.hour}:00';
                        return LineTooltipItem(
                          '$timeTitle\n$name: ${spot.y.toInt()}',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 4).clamp(1.0, 10.0),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                        .withValues(alpha: isDark ? 0.5 : 0.8),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final point = points[index];
                        final displayLabel = point.label.isNotEmpty
                            ? point.label
                            : '${point.clockHour.toString().padLeft(2, '0')}:00';
                        return Text(
                          displayLabel,
                          style: TextStyle(
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (maxY / 4).clamp(1.0, 10.0),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 23,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Failed Attempts / Incursions
                  LineChartBarData(
                    spots: failedSpots,
                    isCurved: true,
                    color: dangerColor,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: dangerColor.withValues(alpha: isDark ? 0.12 : 0.08),
                    ),
                  ),
                  // Successful Logins
                  LineChartBarData(
                    spots: successSpots,
                    isCurved: true,
                    color: successColor,
                    barWidth: 2.0,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: successColor.withValues(alpha: isDark ? 0.08 : 0.06),
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

  Widget _buildLegend(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
