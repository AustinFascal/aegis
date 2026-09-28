import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/security/biometric_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/auth_event.dart';
import '../../providers/policy_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../services/threat_intel_service.dart';

class ForensicDialog extends StatefulWidget {
  final AuthEvent event;

  const ForensicDialog({super.key, required this.event});

  @override
  State<ForensicDialog> createState() => _ForensicDialogState();
}

class _ForensicDialogState extends State<ForensicDialog> {
  bool _isProcessing = false;
  bool _isFetchingServerLogs = false;
  IpThreatIntel? _threatIntel;
  bool _isLoadingIntel = true;
  String? _intelError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadThreatIntel();
    });
  }

  Future<void> _loadThreatIntel({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingIntel = true;
      _intelError = null;
    });

    try {
      final settings = context.read<SettingsProvider>();
      final intel = await ThreatIntelService().checkIp(
        ip: widget.event.clientIp,
        apiKey: settings.abuseIpDbApiKey,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _threatIntel = intel;
          _isLoadingIntel = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _intelError = e.toString();
          _isLoadingIntel = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    SettingsProvider? settings;
    try {
      settings = context.watch<SettingsProvider>();
    } catch (_) {}
    final isIndo = settings?.isIndonesian ?? true;
    final event = widget.event;
    final policyProvider = context.read<PolicyProvider>();
    final serverProvider = context.read<ServerProvider>();
    final currentServerId = serverProvider.activeServer?.id ?? event.serverId;

    TelemetryProvider? telemetry;
    try {
      telemetry = context.watch<TelemetryProvider>();
    } catch (_) {}

    // Dynamic, verified attempt count backed by authentic evidence logs
    final evidenceLogs = telemetry?.getEvidenceLogsForIp(event.clientIp, fallbackEvent: event) ??
        event.allEvidenceLogs;
    final attemptCount = evidenceLogs.isNotEmpty
        ? evidenceLogs.length
        : (telemetry?.getAttemptCount(event.clientIp, fallbackEvent: event) ?? event.attemptCount);

    Color riskColor;
    if (event.riskScore >= 80) {
      riskColor = isDark ? AppColors.danger : AppColors.dangerLight;
    } else if (event.riskScore >= 40) {
      riskColor = isDark ? AppColors.warning : AppColors.warningLight;
    } else {
      riskColor = isDark ? AppColors.success : AppColors.successLight;
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: riskColor.withValues(alpha: isDark ? 0.4 : 0.25),
                          ),
                        ),
                        child: Icon(Icons.shield_outlined,
                            color: riskColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIndo ? 'FORENSIK INSIDEN' : 'INCIDENT FORENSICS',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.lightTextMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            event.service.toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 14),

              // Threat diagnosis banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: riskColor.withValues(alpha: isDark ? 0.35 : 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          event.isUnknownPerson
                              ? (isIndo ? '🚨 KRITIS: LOGIN PENGGUNA TIDAK DIKENAL' : '🚨 CRITICAL: UNKNOWN PERSON LOGIN')
                              : (event.status == EventStatus.failed
                                  ? (isIndo ? '⚠️ INTRUSI TIDAK TEROTORISASI' : '⚠️ UNAUTHORIZED INCURSION')
                                  : (isIndo ? '✅ AKSES TERVERIFIKASI' : '✅ VERIFIED ACCESS')),
                          style: TextStyle(
                            color: riskColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isIndo ? 'RISIKO: ${event.riskScore}/100' : 'RISK: ${event.riskScore}/100',
                          style: TextStyle(
                            color: riskColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    if (event.failureReason != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        event.failureReason!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Metadata grid
              _buildRow(context, 'Target Account', event.user, isMonospace: true),
              _buildRow(context, 'Client IP', event.clientIp, isMonospace: true),
              _buildRow(
                context,
                isIndo ? 'Frekuensi Percobaan' : 'Attempt Frequency',
                isIndo ? '$attemptCount kali percobaan masuk' : '$attemptCount login attempts recorded',
                isMonospace: true,
                badgeText: attemptCount > 3
                    ? (isIndo ? 'INTENSITAS TINGGI' : 'HIGH INTENSITY')
                    : (attemptCount > 1 ? (isIndo ? 'BERULANG' : 'REPEATED') : null),
                badgeColor: attemptCount > 3
                    ? (isDark ? AppColors.danger : AppColors.dangerLight)
                    : (isDark ? AppColors.warning : AppColors.warningLight),
              ),
              _buildRow(context, 'Timestamp', Formatters.formatDateTime(event.timestamp)),
              _buildRow(
                context,
                isIndo ? 'Lokasi Asal' : 'Origin Location',
                '${event.city ?? "Unknown"}, ${event.country ?? "N/A"}',
              ),
              _buildRow(context, 'Network ASN', event.asn ?? 'AS13335 (Cloudflare/Proxy)'),

              const SizedBox(height: 14),

              // THREAT INTELLIGENCE (AbuseIPDB Integration)
              _buildThreatIntelSection(
                context: context,
                isDark: isDark,
                isIndo: isIndo,
                theme: theme,
                settings: settings,
              ),

              const SizedBox(height: 16),

              // BUKTI LOG PERCOBAAN (ATTEMPT EVIDENCE LOGS)
              _buildEvidenceLogsSection(
                context: context,
                evidenceLogs: evidenceLogs,
                clientIp: event.clientIp,
                service: event.service,
                isDark: isDark,
                isIndo: isIndo,
                theme: theme,
                serverProvider: serverProvider,
                telemetry: telemetry,
              ),

              const SizedBox(height: 20),

              // Rapid Incident Mitigation Bar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? AppColors.success
                            : AppColors.successLight,
                        side: BorderSide(
                          color: isDark
                              ? AppColors.success
                              : AppColors.successLight,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        policyProvider.addTrustedIp(currentServerId, event.clientIp);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isIndo ? 'IP ${event.clientIp} ditambahkan ke Daftar Putih' : 'IP ${event.clientIp} added to Trusted Whitelist'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(isIndo ? 'PERCAYAI IP' : 'TRUST IP'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? AppColors.danger : AppColors.dangerLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);

                              try {
                                final settingsProvider = context.read<SettingsProvider>();
                                final requiresBiometric = settingsProvider.biometricLock;

                                bool authenticated = true;
                                if (requiresBiometric) {
                                  authenticated = await BiometricService().authenticate(
                                    context: context,
                                    reason: isIndo
                                        ? 'Otorisasi pemblokiran firewall segera untuk IP ${event.clientIp}'
                                        : 'Authorize immediate firewall block for IP ${event.clientIp}',
                                  );
                                }

                                if (!mounted) return;

                                if (authenticated) {
                                  policyProvider.banIp(
                                    currentServerId,
                                    event.clientIp,
                                    event.failureReason ?? 'Blocked by AEGIS Admin',
                                    event.service,
                                  );

                                  // Execute immediate firewall block on server via SSH (iptables + fail2ban)
                                  unawaited(serverProvider.executeFirewallControl(
                                    ip: event.clientIp,
                                    action: 'ban',
                                    service: event.service,
                                    serverId: currentServerId,
                                  ));

                                  navigator.pop();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          isIndo ? '🛡️ IP ${event.clientIp} telah DIBLOKIR di firewall!' : '🛡️ IP ${event.clientIp} has been BANNED on firewall!'),
                                      backgroundColor: isDark
                                          ? AppColors.danger
                                          : AppColors.dangerLight,
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(isIndo ? 'Verifikasi biometrik dibatalkan.' : 'Biometric verification cancelled.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(isIndo ? 'Gagal memblokir IP: $e' : 'Failed to ban IP: $e'),
                                      backgroundColor: isDark
                                          ? AppColors.danger
                                          : AppColors.dangerLight,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isProcessing = false);
                                }
                              }
                            },
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.block_rounded, size: 18),
                      label: Text(isIndo ? 'BLOKIR IP' : 'BLOCK IP'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section displaying all individual log records that constitute the attempt frequency
  Widget _buildEvidenceLogsSection({
    required BuildContext context,
    required List<String> evidenceLogs,
    required String clientIp,
    required String service,
    required bool isDark,
    required bool isIndo,
    required ThemeData theme,
    required ServerProvider serverProvider,
    required TelemetryProvider? telemetry,
  }) {
    final count = evidenceLogs.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with title and action buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 16,
                    color: isDark ? AppColors.primary : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isIndo
                        ? 'BUKTI LOG PERCOBAAN ($count)'
                        : 'ATTEMPT EVIDENCE LOGS ($count)',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Fetch live from server button if connected
                  if (serverProvider.activeServer?.isConnected == true)
                    InkWell(
                      onTap: _isFetchingServerLogs
                          ? null
                          : () async {
                              setState(() => _isFetchingServerLogs = true);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final serverLogs = await serverProvider.fetchIpEvidenceLogs(ip: clientIp);
                                if (serverLogs.isNotEmpty && telemetry != null) {
                                  telemetry.addEvidenceLogs(clientIp, serverLogs);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(isIndo
                                          ? 'Berhasil menarik ${serverLogs.length} bukti log dari server VPS!'
                                          : 'Successfully fetched ${serverLogs.length} evidence logs from VPS!'),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(isIndo
                                          ? 'Tidak ada log tambahan ditemukan di server untuk IP ini.'
                                          : 'No additional server logs found for this IP.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(isIndo ? 'Gagal menarik log dari server: $e' : 'Failed to fetch logs: $e'),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isFetchingServerLogs = false);
                                }
                              }
                            },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.primary : AppColors.primaryLight)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (isDark ? AppColors.primary : AppColors.primaryLight)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isFetchingServerLogs)
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.5),
                              )
                            else
                              Icon(
                                Icons.cloud_sync_rounded,
                                size: 12,
                                color: isDark ? AppColors.primary : AppColors.primaryLight,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              isIndo ? 'Tarik dari Server' : 'Fetch from Server',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.primary : AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Copy All Evidence Button
                  if (evidenceLogs.isNotEmpty)
                    InkWell(
                      onTap: () {
                        final buffer = StringBuffer();
                        buffer.writeln('=== AEGIS INCIDENT EVIDENCE REPORT ===');
                        buffer.writeln('Client IP: $clientIp');
                        buffer.writeln('Service: ${service.toUpperCase()}');
                        buffer.writeln('Total Attempts: $count');
                        buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
                        buffer.writeln('--- RECORDED LOG ATTEMPTS ---');
                        for (int i = 0; i < evidenceLogs.length; i++) {
                          buffer.writeln('[#${i + 1}] ${evidenceLogs[i]}');
                        }
                        Clipboard.setData(ClipboardData(text: buffer.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isIndo
                                ? 'Semua $count bukti log percobaan disalin ke clipboard!'
                                : 'All $count attempt evidence logs copied to clipboard!'),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy_all_rounded, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              isIndo ? 'Salin Semua Bukti' : 'Copy All Evidence',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            isIndo
                ? 'Seluruh riwayat log masuk yang dihitung sebagai frekuensi percobaan IP ini:'
                : 'All authentication attempt records counted towards this IP\'s attempt frequency:',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 10),

          // Scrollable evidence list
          if (evidenceLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                isIndo ? 'Belum ada bukti log terekam.' : 'No evidence logs recorded yet.',
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  fontSize: 12,
                ),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: evidenceLogs.length,
                  separatorBuilder: (ctx, i) => Divider(
                    height: 12,
                    thickness: 0.6,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  itemBuilder: (ctx, index) {
                    final logLine = evidenceLogs[index];
                    final isFailed = logLine.toLowerCase().contains('denied') ||
                        logLine.toLowerCase().contains('failed') ||
                        logLine.toLowerCase().contains('rejected') ||
                        logLine.contains('403');
                    final isSuccess = logLine.toLowerCase().contains('accepted') ||
                        logLine.toLowerCase().contains('200 ok');

                    Color pillColor = isFailed
                        ? (isDark ? AppColors.danger : AppColors.dangerLight)
                        : (isSuccess
                            ? (isDark ? AppColors.success : AppColors.successLight)
                            : (isDark ? AppColors.warning : AppColors.warningLight));

                    String pillLabel = isFailed
                        ? (isIndo ? 'Gagal' : 'Failed')
                        : (isSuccess
                            ? (isIndo ? 'Sukses' : 'Success')
                            : (isIndo ? 'Aktivitas' : 'Activity'));

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Attempt Number & Status Badge
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  ),
                                ),
                                child: Text(
                                  '#${index + 1}${index == 0 ? (isIndo ? " (Terbaru)" : " (Latest)") : ""}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: index == 0
                                        ? (isDark ? AppColors.primary : AppColors.primaryLight)
                                        : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: pillColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  pillLabel,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: pillColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Raw log text
                        Expanded(
                          child: SelectableText(
                            logLine,
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              height: 1.35,
                            ),
                          ),
                        ),

                        // Mini copy button for this specific line
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          icon: const Icon(Icons.copy_rounded, size: 13),
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          tooltip: isIndo ? 'Salin baris ini' : 'Copy this line',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: logLine));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isIndo
                                    ? 'Log #${index + 1} disalin ke clipboard'
                                    : 'Log #${index + 1} copied to clipboard'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String value, {
    bool isMonospace = false,
    String? badgeText,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: isMonospace ? 'monospace' : null,
                    ),
                  ),
                ),
                if (badgeText != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? theme.colorScheme.primary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (badgeColor ?? theme.colorScheme.primary).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor ?? theme.colorScheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatIntelSection({
    required BuildContext context,
    required bool isDark,
    required bool isIndo,
    required ThemeData theme,
    required SettingsProvider? settings,
  }) {
    final intel = _threatIntel;
    Color statusColor;
    if (intel == null) {
      statusColor = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    } else if (!intel.isPublic) {
      statusColor = isDark ? AppColors.success : AppColors.successLight;
    } else {
      statusColor = intel.getRiskColor(isDark);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (intel != null && intel.isHighRisk)
              ? statusColor.withValues(alpha: isDark ? 0.5 : 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.radar_rounded,
                    size: 16,
                    color: isDark ? AppColors.primary : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isIndo
                        ? 'INTELIJEN ANCAMAN (ABUSEIPDB)'
                        : 'THREAT INTELLIGENCE (ABUSEIPDB)',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Mode Badge (Live / Demo / Internal)
                  if (intel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (!intel.isPublic
                                ? (isDark ? AppColors.success : AppColors.successLight)
                                : (intel.isSimulated
                                    ? (isDark ? AppColors.warning : AppColors.warningLight)
                                    : (isDark ? AppColors.primary : AppColors.primaryLight)))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (!intel.isPublic
                                  ? (isDark ? AppColors.success : AppColors.successLight)
                                  : (intel.isSimulated
                                      ? (isDark ? AppColors.warning : AppColors.warningLight)
                                      : (isDark ? AppColors.primary : AppColors.primaryLight)))
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        !intel.isPublic
                            ? 'INTERNAL'
                            : (intel.isSimulated
                                ? (isIndo ? 'DEMO / SIMULASI' : 'SIMULATION')
                                : (isIndo ? 'LIVE API' : 'LIVE API')),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: !intel.isPublic
                              ? (isDark ? AppColors.success : AppColors.successLight)
                              : (intel.isSimulated
                                  ? (isDark ? AppColors.warning : AppColors.warningLight)
                                  : (isDark ? AppColors.primary : AppColors.primaryLight)),
                        ),
                      ),
                    ),

                  // Quick API Key config button
                  InkWell(
                    onTap: settings != null ? () => _showApiKeyDialog(context, settings) : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.key_rounded,
                            size: 11,
                            color: settings?.hasAbuseIpDbApiKey == true
                                ? (isDark ? AppColors.success : AppColors.successLight)
                                : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            settings?.hasAbuseIpDbApiKey == true ? 'API Key ✓' : 'Atur Key',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Refresh button
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    icon: _isLoadingIntel
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          ),
                    tooltip: isIndo ? 'Segarkan Data Intelijen' : 'Refresh Threat Intel',
                    onPressed: _isLoadingIntel ? null : () => _loadThreatIntel(forceRefresh: true),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Content body
          if (_isLoadingIntel)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      isIndo
                          ? 'Memeriksa reputasi IP di database AbuseIPDB...'
                          : 'Querying IP reputation from AbuseIPDB...',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else if (_intelError != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.danger : AppColors.dangerLight).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: isDark ? AppColors.danger : AppColors.dangerLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _intelError!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.danger : AppColors.dangerLight,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _loadThreatIntel(forceRefresh: true),
                    child: Text(isIndo ? 'Coba Lagi' : 'Retry', style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            )
          else if (intel != null) ...[
            // Score Bar & Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withValues(alpha: isDark ? 0.35 : 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '${intel.abuseConfidenceScore}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            intel.getRiskLevelText(isIndonesian: isIndo),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isIndo
                            ? 'Skor Bahaya AbuseIPDB'
                            : 'Abuse Confidence Score',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: intel.abuseConfidenceScore / 100.0,
                      minHeight: 5,
                      backgroundColor: (isDark ? Colors.white10 : Colors.black12),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Metadata Detail Grid
            _buildIntelMetricRow(
              context,
              label: isIndo ? 'Total Laporan Komunitas' : 'Total Abuse Reports',
              value: intel.totalReports > 0
                  ? (isIndo
                      ? '${intel.totalReports} laporan (${intel.numDistinctUsers} pelapor)'
                      : '${intel.totalReports} reports (${intel.numDistinctUsers} users)')
                  : (isIndo ? '0 laporan (Bersih)' : '0 reports (Clean)'),
              isDark: isDark,
              highlight: intel.totalReports > 0,
            ),
            _buildIntelMetricRow(
              context,
              label: isIndo ? 'Terakhir Dilaporkan' : 'Last Reported',
              value: intel.lastReportedAt != null
                  ? Formatters.formatDateTime(intel.lastReportedAt!)
                  : (isIndo ? 'Belum pernah dilaporkan' : 'Never reported'),
              isDark: isDark,
            ),
            _buildIntelMetricRow(
              context,
              label: isIndo ? 'Penyedia Layanan / ISP' : 'ISP / Organization',
              value: intel.isp,
              isDark: isDark,
            ),
            _buildIntelMetricRow(
              context,
              label: isIndo ? 'Kategori Penggunaan' : 'Usage Type',
              value: intel.usageType,
              isDark: isDark,
            ),
            if (intel.domain.isNotEmpty)
              _buildIntelMetricRow(
                context,
                label: 'Domain / Host',
                value: intel.domain,
                isDark: isDark,
                isMonospace: true,
              ),

            // Threat Feature Badges
            if (intel.isTor ||
                intel.isWhitelisted ||
                intel.usageType.toLowerCase().contains('data center') ||
                intel.usageType.toLowerCase().contains('botnet') ||
                intel.usageType.toLowerCase().contains('c2')) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (intel.isTor)
                    _buildThreatTag(
                      icon: Icons.vpn_lock_rounded,
                      label: isIndo ? 'TOR EXIT NODE' : 'TOR EXIT NODE',
                      color: isDark ? AppColors.danger : AppColors.dangerLight,
                    ),
                  if (intel.usageType.toLowerCase().contains('botnet') ||
                      intel.usageType.toLowerCase().contains('c2'))
                    _buildThreatTag(
                      icon: Icons.pest_control_rounded,
                      label: isIndo ? 'BOTNET C2 NODE' : 'BOTNET C2 NODE',
                      color: isDark ? AppColors.danger : AppColors.dangerLight,
                    ),
                  if (intel.usageType.toLowerCase().contains('data center') ||
                      intel.usageType.toLowerCase().contains('hosting'))
                    _buildThreatTag(
                      icon: Icons.dns_rounded,
                      label: isIndo ? 'DATA CENTER / HOSTING' : 'DATA CENTER / HOSTING',
                      color: isDark ? AppColors.primary : AppColors.primaryLight,
                    ),
                  if (intel.isWhitelisted)
                    _buildThreatTag(
                      icon: Icons.verified_user_rounded,
                      label: isIndo ? 'REPUTASI TERDAFTAR (WHITELIST)' : 'WHITELISTED ENTITY',
                      color: isDark ? AppColors.success : AppColors.successLight,
                    ),
                ],
              ),
            ],

            // Demo Mode Notice
            if (intel.isSimulated && intel.isPublic) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: settings != null ? () => _showApiKeyDialog(context, settings) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isDark ? AppColors.warning : AppColors.warningLight).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: isDark ? AppColors.warning : AppColors.warningLight,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isIndo
                              ? 'Mode Simulasi. Pasang API key AbuseIPDB gratis untuk live scan.'
                              : 'Simulation mode. Add free AbuseIPDB API key for live intelligence.',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                      Text(
                        isIndo ? 'Atur →' : 'Set Up →',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.primary : AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildIntelMetricRow(
    BuildContext context, {
    required String label,
    required String value,
    required bool isDark,
    bool isMonospace = false,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                fontFamily: isMonospace ? 'monospace' : null,
                color: highlight
                    ? (isDark ? AppColors.danger : AppColors.dangerLight)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.abuseIpDbApiKey ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIndo = settings.isIndonesian;
    bool isVerifying = false;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.radar_rounded, color: isDark ? AppColors.primary : AppColors.primaryLight, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isIndo ? 'AbuseIPDB API Key' : 'AbuseIPDB API Key',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isIndo
                    ? 'Masukkan API key akun AbuseIPDB Anda (1.000 cek gratis/hari) untuk memindai reputasi IP ancaman langsung dari database siber global.'
                    : 'Enter your AbuseIPDB API key (free 1,000 checks/day) to query live threat reputation scores from the global cyber database.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: obscure,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  labelText: isIndo ? 'AbuseIPDB API Key' : 'AbuseIPDB API Key',
                  hintText: 'e.g. 7a4e9b8f1c...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.key_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'https://www.abuseipdb.com/register',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: 'https://www.abuseipdb.com/register'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isIndo ? 'Tautan registrasi disalin ke clipboard' : 'Registration link copied to clipboard'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        isIndo ? 'Salin URL ↗' : 'Copy URL ↗',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.primary : AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (settings.hasAbuseIpDbApiKey)
              TextButton(
                onPressed: () async {
                  await settings.removeAbuseIpDbApiKey();
                  if (ctx.mounted) Navigator.pop(dialogCtx);
                  _loadThreatIntel(forceRefresh: true);
                },
                child: Text(
                  isIndo ? 'Hapus Key' : 'Clear Key',
                  style: TextStyle(color: isDark ? AppColors.danger : AppColors.dangerLight),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(isIndo ? 'Batal' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final inputKey = controller.text.trim();
                      if (inputKey.isEmpty) {
                        await settings.removeAbuseIpDbApiKey();
                        if (ctx.mounted) Navigator.pop(dialogCtx);
                        _loadThreatIntel(forceRefresh: true);
                        return;
                      }

                      setDialogState(() => isVerifying = true);
                      final isValid = await ThreatIntelService().verifyApiKey(inputKey);
                      setDialogState(() => isVerifying = false);

                      if (isValid) {
                        await settings.setAbuseIpDbApiKey(inputKey);
                        if (ctx.mounted) Navigator.pop(dialogCtx);
                        _loadThreatIntel(forceRefresh: true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isIndo
                                  ? '✅ AbuseIPDB API Key terverifikasi dan tersimpan!'
                                  : '✅ AbuseIPDB API Key verified and saved!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isIndo
                                  ? '⚠️ Gagal memverifikasi API key. Pastikan key valid dan koneksi aktif.'
                                  : '⚠️ Failed to verify API key. Please check key and connection.'),
                              backgroundColor: isDark ? AppColors.danger : AppColors.dangerLight,
                            ),
                          );
                        }
                      }
                    },
              child: isVerifying
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isIndo ? 'Simpan & Verifikasi' : 'Save & Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
