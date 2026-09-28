import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/auth_event.dart';
import '../../providers/telemetry_provider.dart';
import 'forensic_dialog.dart';

class EventTile extends StatelessWidget {
  final AuthEvent event;

  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    SettingsProvider? settings;
    try {
      settings = context.watch<SettingsProvider>();
    } catch (_) {}
    final isIndo = settings?.isIndonesian ?? true;

    TelemetryProvider? telemetry;
    try {
      telemetry = context.watch<TelemetryProvider>();
    } catch (_) {}
    final displayCount = telemetry?.getAttemptCount(event.clientIp, fallbackEvent: event) ?? event.attemptCount;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (event.isUnknownPerson) {
      statusColor = isDark ? AppColors.warning : AppColors.warningLight;
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = isIndo ? 'ORANG TAK DIKENAL' : 'UNKNOWN PERSON';
    } else if (event.status == EventStatus.failed) {
      statusColor = isDark ? AppColors.danger : AppColors.dangerLight;
      statusIcon = Icons.gpp_bad_rounded;
      statusLabel = isIndo ? 'DITOLAK' : 'UNAUTHORIZED';
    } else {
      statusColor = isDark ? AppColors.success : AppColors.successLight;
      statusIcon = Icons.verified_user_rounded;
      statusLabel = isIndo ? 'TEROTORISASI' : 'AUTHORIZED';
    }

    final isMysql = event.service.toLowerCase().contains('mysql');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => ForensicDialog(event: event),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isMysql ? AppColors.mysql : AppColors.ssh)
                              .withValues(alpha: isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (isMysql ? AppColors.mysql : AppColors.ssh)
                                .withValues(alpha: isDark ? 0.4 : 0.25),
                          ),
                        ),
                        child: Text(
                          event.service.toUpperCase(),
                          style: TextStyle(
                            color: isMysql
                                ? (isDark ? AppColors.primary : AppColors.mysql)
                                : (isDark
                                    ? const Color(0xFF90CAF9)
                                    : const Color(0xFF1E40AF)),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: isDark ? 0.14 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    Formatters.timeAgo(event.timestamp, isIndonesian: isIndo),
                    style: TextStyle(
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: isIndo ? 'Pengguna: ' : 'User: ',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textMuted
                                      : AppColors.lightTextMuted,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: event.user,
                                style: TextStyle(
                                  color: (event.user == 'root' ||
                                          event.user == 'admin')
                                      ? (isDark ? AppColors.danger : AppColors.dangerLight)
                                      : theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                event.clientIp,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (event.country != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.lightSurfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event.country!,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.textMuted
                                        : AppColors.lightTextMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: (displayCount > 3 ? AppColors.danger : theme.colorScheme.primary)
                                    .withValues(alpha: isDark ? 0.18 : 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (displayCount > 3 ? AppColors.danger : theme.colorScheme.primary)
                                      .withValues(alpha: isDark ? 0.4 : 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 10,
                                    color: displayCount > 3 ? AppColors.danger : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    isIndo ? "${displayCount}x coba" : "${displayCount}x tries",
                                    style: TextStyle(
                                      color: displayCount > 3 ? AppColors.danger : theme.colorScheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: "monospace",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: isDark ? 0.1 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: isDark ? 0.3 : 0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isIndo ? 'RISIKO' : 'RISK',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${event.riskScore}',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (event.failureReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  event.failureReason!,
                  style: TextStyle(
                    color: statusColor.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
