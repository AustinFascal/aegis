import '../../models/auth_event.dart';
import 'audit_explorer_screen.dart';
import 'settings_screen.dart';
import 'faq_screen.dart';
import 'server_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/service_registry.dart';
import '../../providers/server_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../providers/policy_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/server_profile.dart';
import '../widgets/metric_card.dart';
import '../widgets/metric_info_dialog.dart';
import '../widgets/connection_pulse.dart';
import '../widgets/threat_timeline_chart.dart';
import '../widgets/event_tile.dart';
import '../widgets/two_factor_auth_dialog.dart';
import '../widgets/aegis_logo.dart';
import '../../providers/hardware_telemetry_provider.dart';
import '../widgets/hardware_telemetry_card.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  Future<void> _handleDashboardRefresh(
    BuildContext context,
    ServerProvider serverProvider,
    TelemetryProvider telemetryProvider,
    PolicyProvider policyProvider,
    ServerProfile? activeServer, {
    bool showSnackBar = false,
  }) async {
    if (activeServer == null) return;

    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final isIndo = context.read<SettingsProvider>().isIndonesian;

    Future<String?> prompt2FA(String prompt) => TwoFactorAuthDialog.show(
      context,
      username: activeServer.username,
      serverName: activeServer.name,
      promptText: prompt,
    );

    // 1. Test / poll server status (reuses pooled connection; 2FA only if not yet connected)
    final result = await serverProvider.testActiveServer(onPrompt2FA: prompt2FA);

    int logCount = 0;
    if (result.success) {
      // 2. Fetch real-time logs from server and ingest into TelemetryProvider
      final policy = policyProvider.getPolicy(activeServer.id);
      final liveEvents = await serverProvider.fetchRealTimeLogs(
        server: activeServer,
        onPrompt2FA: prompt2FA,
      );
      if (liveEvents.isNotEmpty) {
        telemetryProvider.ingestBatchEvents(liveEvents, policy);
        logCount = liveEvents.length;
      }

      // 3. Sync fail2ban & iptables server banned IPs
      final serverBans = await serverProvider.fetchServerBannedIps(
        serverId: activeServer.id,
        onPrompt2FA: prompt2FA,
      );
      if (serverBans.isNotEmpty) {
        policyProvider.syncServerBannedIps(activeServer.id, serverBans);
      }

      // 4. Sample Continuous Hardware Telemetry
      if (context.mounted) {
        final hwProvider = context.read<HardwareTelemetryProvider>();
        await hwProvider.sampleServer(
          serverProvider: serverProvider,
          server: activeServer,
          notify: false,
        );
      }
    }

    await telemetryProvider.refreshTelemetry();

    if (showSnackBar && context.mounted) {
      final upCount = result.serviceStatuses.values.where((v) => v).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? (isIndo
                    ? '✅ Server ${activeServer.name} terhubung!\nUptime: ${result.uptime} • $upCount layanan aktif • $logCount log terkini tersinkronisasi'
                    : '✅ Connected to ${activeServer.name}!\nUptime: ${result.uptime} • $upCount online services • $logCount live logs synchronized')
                : (isIndo
                    ? '⚠️ Gagal terhubung: ${result.errorMessage}'
                    : '⚠️ Connection failed: ${result.errorMessage}'),
          ),
          backgroundColor: result.success
              ? (isDark ? AppColors.darkCard : AppColors.lightTextPrimary)
              : (isDark ? AppColors.danger : AppColors.dangerLight),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();

    final serverProvider = context.watch<ServerProvider>();
    final telemetryProvider = context.watch<TelemetryProvider>();
    final policyProvider = context.watch<PolicyProvider>();
    final activeServer = serverProvider.activeServer;
    final metrics = activeServer != null
        ? telemetryProvider.getMetricsForServer(activeServer.id)
        : telemetryProvider.metrics;
    final sortedAll = activeServer != null
        ? (telemetryProvider.allEvents
              .where((e) => e.serverId == activeServer.id)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp)))
        : <AuthEvent>[];
    final latestEvents = sortedAll.take(6).toList();
    final hasKey =
        activeServer != null &&
        serverProvider.hasStoredCredential(activeServer.id);

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              _showServerSwitchSheet(context, serverProvider, settings, isDark),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const AegisLogo(size: 20),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'AEGIS (Beta)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                      Text(
                        activeServer?.name ??
                            (settings.isIndonesian
                                ? 'Belum Ada Server'
                                : 'No Server Selected'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Test & Poll Server Button
          IconButton(
            icon: serverProvider.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(Icons.refresh_rounded, color: theme.colorScheme.primary),
            tooltip: settings.t('test_poll'),
            onPressed: serverProvider.isLoading
                ? null
                : () => _handleDashboardRefresh(
                      context,
                      serverProvider,
                      telemetryProvider,
                      policyProvider,
                      activeServer,
                      showSnackBar: true,
                    ),
          ),
          // Switch Server Button
          // IconButton(
          //   icon: Icon(
          //     Icons.dns_rounded,
          //     // color: theme.colorScheme.primary,
          //   ),
          //   tooltip: settings.isIndonesian ? 'Ganti Server Aktif' : 'Switch Active Server',
          //   onPressed: () => _showServerSwitchSheet(context, serverProvider, settings, isDark),
          // ),
          // Help Center & FAQ Button on Top Nav
          IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              // color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            ),
            tooltip: settings.isIndonesian
                ? 'Pusat Bantuan & FAQ'
                : 'Help Center & FAQ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqScreen()),
              );
            },
          ),
          // Settings Page Button
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              // color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            ),
            tooltip: settings.t('nav_settings'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (activeServer == null || serverProvider.servers.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.12 : 0.08,
                        ),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.dns_outlined,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      settings.isIndonesian
                          ? 'BELUM ADA SERVER TERHUBUNG'
                          : 'NO SERVER CONNECTED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Text(
                        settings.isIndonesian
                            ? 'Konfigurasikan server VPS Linux atau SSH pertama Anda untuk mulai memantau infrastruktur dan keamanan sistem secara real-time.'
                            : 'Configure your first Linux VPS or SSH server to start monitoring infrastructure and system security in real-time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () =>
                          ServerManagementScreen.showServerDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                        settings.isIndonesian
                            ? 'SETUP SERVER BARU'
                            : 'SETUP NEW SERVER',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final width = constraints.maxWidth;
          final isWideDesktop = width >= 1050;

          final int metricCols = width >= 900 ? 4 : (width >= 420 ? 2 : 1);

          return RefreshIndicator(
            onRefresh: () => _handleDashboardRefresh(
              context,
              serverProvider,
              telemetryProvider,
              policyProvider,
              activeServer,
              showSnackBar: false,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWideDesktop ? 28 : 16,
                vertical: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Missing Key Warning Alert Banner (if key not in vault)
                      if (!hasKey) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(
                              alpha: isDark ? 0.15 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (isDark
                                          ? AppColors.warning
                                          : AppColors.warningLight)
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.key_off_rounded,
                                color: isDark
                                    ? AppColors.warning
                                    : AppColors.warningLight,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No SSH Key Found for "${activeServer.name}"',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Configure your private key in the Servers menu to enable SSH telemetry polling.',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.textSecondary
                                            : AppColors.lightTextSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.warning
                                      : AppColors.warningLight,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () => onNavigateToTab(4),
                                child: const Text(
                                  'CONFIGURE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Server Health & Status Header
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, headerConstraints) {
                            final isCompact = headerConstraints.maxWidth < 560;

                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ConnectionPulse(
                                        isLive: activeServer.isConnected,
                                        label: activeServer.isConnected
                                            ? 'LIVE'
                                            : 'OFFLINE',
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(
                                              Icons.swap_horiz_rounded,
                                              size: 14,
                                            ),
                                            label: Text(
                                              settings.isIndonesian
                                                  ? 'GANTI'
                                                  : 'SWITCH',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () =>
                                                _showServerSwitchSheet(
                                                  context,
                                                  serverProvider,
                                                  settings,
                                                  isDark,
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.tune_rounded,
                                              size: 18,
                                            ),
                                            color: isDark
                                                ? AppColors.textMuted
                                                : AppColors.lightTextMuted,
                                            tooltip: 'Configure Policies',
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                            onPressed: () => onNavigateToTab(3),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${activeServer.username}@${activeServer.host}:${activeServer.port}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    activeServer.osInfo != null
                                        ? '${activeServer.osInfo} • ${activeServer.uptime ?? "Active"}'
                                        : 'Tap refresh above to poll server telemetry...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.textMuted
                                          : AppColors.lightTextMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      ConnectionPulse(
                                        isLive: activeServer.isConnected,
                                        label: activeServer.isConnected
                                            ? 'LIVE'
                                            : 'OFFLINE',
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${activeServer.username}@${activeServer.host}:${activeServer.port}',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontSize: 13,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              activeServer.osInfo != null
                                                  ? '${activeServer.osInfo} • ${activeServer.uptime ?? "Active"}'
                                                  : 'Tap refresh above to poll server telemetry...',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isDark
                                                    ? AppColors.textMuted
                                                    : AppColors.lightTextMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 14,
                                      ),
                                      label: Text(
                                        settings.isIndonesian
                                            ? 'GANTI'
                                            : 'SWITCH',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _showServerSwitchSheet(
                                        context,
                                        serverProvider,
                                        settings,
                                        isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.tune_rounded,
                                        size: 20,
                                      ),
                                      color: isDark
                                          ? AppColors.textMuted
                                          : AppColors.lightTextMuted,
                                      tooltip: 'Configure Policies',
                                      onPressed: () => onNavigateToTab(3),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Responsive KPI Metrics Grid
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: metricCols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 116,
                        ),
                        children: [
                          MetricCard(
                            title: settings.t('failed_logins'),
                            value: metrics.failedAttempts24h.toString(),
                            subtitle: settings.isIndonesian
                                ? '24 Jam Terakhir'
                                : 'Last 24 Hours',
                            icon: Icons.cancel_outlined,
                            accentColor: metrics.failedAttempts24h > 5
                                ? (isDark
                                      ? AppColors.danger
                                      : AppColors.dangerLight)
                                : (isDark
                                      ? AppColors.warning
                                      : AppColors.warningLight),
                            infoTooltip: settings.isIndonesian
                                ? 'Pelajari metrik login gagal'
                                : 'Explain failed logins metric',
                            onInfoTap: () => MetricInfoDialog.show(
                              context,
                              type: MetricType.failedLogins,
                              currentValue: metrics.failedAttempts24h.toString(),
                              accentColor: metrics.failedAttempts24h > 5
                                  ? (isDark
                                        ? AppColors.danger
                                        : AppColors.dangerLight)
                                  : (isDark
                                        ? AppColors.warning
                                        : AppColors.warningLight),
                              isIndo: settings.isIndonesian,
                              isDark: isDark,
                              onExploreAudit: () => onNavigateToTab(1),
                            ),
                          ),
                          MetricCard(
                            title: settings.t('unknown_logins'),
                            value: metrics.unknownPersonAttempts24h.toString(),
                            subtitle: settings.isIndonesian
                                ? 'Dari IP Tak Tepercaya'
                                : 'From Untrusted IPs',
                            icon: Icons.person_search_rounded,
                            accentColor: metrics.unknownPersonAttempts24h > 0
                                ? (isDark
                                      ? AppColors.danger
                                      : AppColors.dangerLight)
                                : (isDark
                                      ? AppColors.success
                                      : AppColors.successLight),
                            infoTooltip: settings.isIndonesian
                                ? 'Pelajari metrik login IP tak dikenal'
                                : 'Explain untrusted IP logins metric',
                            onInfoTap: () => MetricInfoDialog.show(
                              context,
                              type: MetricType.unknownLogins,
                              currentValue: metrics.unknownPersonAttempts24h.toString(),
                              accentColor: metrics.unknownPersonAttempts24h > 0
                                  ? (isDark
                                        ? AppColors.danger
                                        : AppColors.dangerLight)
                                  : (isDark
                                        ? AppColors.success
                                        : AppColors.successLight),
                              isIndo: settings.isIndonesian,
                              isDark: isDark,
                              onExploreAudit: () => onNavigateToTab(1),
                            ),
                          ),
                          MetricCard(
                            title: settings.t('blocked_attempts'),
                            value: metrics.blockedCount.toString(),
                            subtitle: settings.isIndonesian
                                ? 'Dimitigasi Kebijakan'
                                : 'Mitigated by Policy',
                            icon: Icons.gpp_good_rounded,
                            accentColor: isDark
                                ? AppColors.success
                                : AppColors.successLight,
                            infoTooltip: settings.isIndonesian
                                ? 'Pelajari metrik ancaman diblokir'
                                : 'Explain blocked attempts metric',
                            onInfoTap: () => MetricInfoDialog.show(
                              context,
                              type: MetricType.blockedAttempts,
                              currentValue: metrics.blockedCount.toString(),
                              accentColor: isDark
                                  ? AppColors.success
                                  : AppColors.successLight,
                              isIndo: settings.isIndonesian,
                              isDark: isDark,
                              onExploreAudit: () => onNavigateToTab(1),
                            ),
                          ),
                          MetricCard(
                            title: settings.t('security_index'),
                            value: '${metrics.integrityScore}%',
                            subtitle: metrics.integrityScore >= 80
                                ? (settings.isIndonesian
                                      ? 'Kondisi Aman'
                                      : 'Healthy Posture')
                                : (settings.isIndonesian
                                      ? 'Risiko Terdeteksi'
                                      : 'Elevated Risk'),
                            icon: Icons.speed_rounded,
                            accentColor: metrics.integrityScore >= 80
                                ? (isDark
                                      ? AppColors.success
                                      : AppColors.successLight)
                                : (isDark
                                      ? AppColors.danger
                                      : AppColors.dangerLight),
                            infoTooltip: settings.isIndonesian
                                ? 'Pelajari indeks integritas keamanan'
                                : 'Explain security index metric',
                            onInfoTap: () => MetricInfoDialog.show(
                              context,
                              type: MetricType.securityIndex,
                              currentValue: '${metrics.integrityScore}%',
                              accentColor: metrics.integrityScore >= 80
                                  ? (isDark
                                        ? AppColors.success
                                        : AppColors.successLight)
                                  : (isDark
                                        ? AppColors.danger
                                        : AppColors.dangerLight),
                              isIndo: settings.isIndonesian,
                              isDark: isDark,
                              onExploreAudit: () => onNavigateToTab(1),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Continuous Hardware Telemetry
                      HardwareTelemetryCard(activeServer: activeServer),

                      const SizedBox(height: 22),

                      // Desktop 2-Column or Mobile 1-Column Layout
                      if (isWideDesktop) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Charts & Services)
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ThreatTimelineChart(
                                    points: metrics.hourlyTrend,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildServicesSection(
                                    context,
                                    activeServer,
                                    settings,
                                    isDark,
                                    width,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Right Column (Live Threat Radar)
                            Expanded(
                              flex: 2,
                              child: _buildThreatFeedSection(
                                context,
                                latestEvents,
                                settings,
                                isDark,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        ThreatTimelineChart(points: metrics.hourlyTrend),
                        const SizedBox(height: 20),
                        _buildServicesSection(
                          context,
                          activeServer,
                          settings,
                          isDark,
                          width,
                        ),
                        const SizedBox(height: 22),
                        _buildThreatFeedSection(
                          context,
                          latestEvents,
                          settings,
                          isDark,
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicesSection(
    BuildContext context,
    dynamic activeServer,
    SettingsProvider settings,
    bool isDark,
    double width,
  ) {
    final statuses = activeServer?.serviceStatuses as Map<String, bool>? ?? {};
    final isConnected = activeServer?.isConnected ?? false;

    // Display all detected and registered services
    final services = ServiceRegistry.knownServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              settings.t('monitored_services'),
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            TextButton(
              onPressed: () => onNavigateToTab(1),
              child: Text(
                settings.t('deep_dive'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Responsive grid of all detected services
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 640
                ? 3
                : (constraints.maxWidth >= 420 ? 2 : 1);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 72,
              ),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final def = services[index];
                // Determine whether service is UP
                final isUp =
                    statuses[def.id] ??
                    (isConnected && (def.id == 'mysqld' || def.id == 'sshd'));

                return _buildServicePill(
                  context: context,
                  title: def.name,
                  sub: def.portDisplay,
                  color: def.color,
                  icon: def.icon,
                  isDark: isDark,
                  isOnline: isUp,
                  onTap: () => onNavigateToTab(1),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildThreatFeedSection(
    BuildContext context,
    List latestEvents,
    SettingsProvider settings,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              settings.isIndonesian
                  ? 'RADAR ANCAMAN & AKSES REALTIME'
                  : 'LIVE ACCESS & THREAT RADAR',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuditExplorerScreen()),
                );
              },
              child: Text(
                settings.t('all_logs'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (latestEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Text(
              settings.isIndonesian
                  ? 'Belum ada rekaman insiden keamanan.'
                  : 'No security events recorded yet.',
              style: TextStyle(
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
            ),
          )
        else
          ...latestEvents.map((e) => EventTile(event: e)),
      ],
    );
  }

  Widget _buildServicePill({
    required BuildContext context,
    required String title,
    required String sub,
    required Color color,
    required IconData icon,
    required bool isDark,
    bool isOnline = true,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.04 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.lightTextMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServerSwitchSheet(
    BuildContext context,
    ServerProvider serverProvider,
    SettingsProvider settings,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final isIndo = settings.isIndonesian;
    final active = serverProvider.activeServer;
    final servers = serverProvider.servers;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dns_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isIndo
                                ? 'PILIH SERVER AKTIF'
                                : 'SWITCH ACTIVE SERVER',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${servers.length} ${isIndo ? "Tersimpan" : "Saved"}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isIndo
                        ? 'Pilih server armada untuk memantau telemetri, log, dan layanan.'
                        : 'Select a fleet server to inspect telemetry, security logs, and services.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: servers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final server = servers[i];
                        final isSelected = active?.id == server.id;
                        final hasCred = serverProvider.hasStoredCredential(
                          server.id,
                        );

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              serverProvider.selectServer(server.id);
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isIndo
                                        ? 'Server aktif beralih ke: ${server.name}'
                                        : 'Switched active server to: ${server.name}',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: isDark ? 0.15 : 0.08,
                                      )
                                    : (isDark
                                          ? AppColors.darkSurfaceElevated
                                          : AppColors.lightSurfaceElevated),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : (isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          (isSelected
                                                  ? theme.colorScheme.primary
                                                  : AppColors.textMuted)
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.dns_outlined,
                                      size: 18,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : (isDark
                                                ? AppColors.textSecondary
                                                : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                server.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.success
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isIndo ? 'AKTIF' : 'ACTIVE',
                                                  style: const TextStyle(
                                                    color: AppColors.success,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              '${server.username}@${server.host}:${server.port}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: isDark
                                                    ? AppColors.textMuted
                                                    : AppColors.lightTextMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              hasCred
                                                  ? Icons.key_rounded
                                                  : Icons.key_off_rounded,
                                              size: 11,
                                              color: hasCred
                                                  ? AppColors.success
                                                  : AppColors.warning,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : (isDark
                                              ? AppColors.textMuted
                                              : AppColors.lightTextMuted),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        isIndo
                            ? 'Kelola Armada Server (+ Tambah Server)'
                            : 'Manage Fleet (+ Add Server)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        onNavigateToTab(4);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
