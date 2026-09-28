import 'server_management_screen.dart';
import '../../models/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/telemetry_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/server_provider.dart';
import '../widgets/two_factor_auth_dialog.dart';
import '../widgets/event_tile.dart';
import 'faq_screen.dart';

class AuditExplorerScreen extends StatelessWidget {
  const AuditExplorerScreen({super.key});

  Future<void> _handleRefresh(BuildContext context) async {
    final serverProvider = context.read<ServerProvider>();
    final telemetryProvider = context.read<TelemetryProvider>();
    final activeServer = serverProvider.activeServer;
    if (activeServer != null) {
      await serverProvider.testActiveServer(
        onPrompt2FA: (prompt) => TwoFactorAuthDialog.show(
          context,
          username: activeServer.username,
          serverName: activeServer.name,
          promptText: prompt,
        ),
      );
    }
    await telemetryProvider.refreshTelemetry();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    final serverProvider = context.watch<ServerProvider>();
    final activeServer = serverProvider.activeServer;

    if (activeServer == null || serverProvider.servers.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.vertical,
          title: Text(
            isIndo
                ? 'EKSPLORASI FORENSIK & AUDIT'
                : 'AUDIT & FORENSIC EXPLORER',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: isIndo ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const FaqScreen(initialCategory: FaqCategory.detection),
                  ),
                );
              },
            ),
          ],
        ),
        body: Center(
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    size: 60,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isIndo ? 'BELUM ADA SERVER TERHUBUNG' : 'NO SERVER CONNECTED',
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
                    isIndo
                        ? 'Hubungkan server VPS atau SSH terlebih dahulu untuk mulai memantau dan mengaudit log forensik keamanan.'
                        : 'Connect a Linux VPS or SSH server first to begin monitoring and auditing security forensic logs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ServerManagementScreen.showServerDialog(context);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    isIndo ? 'SETUP SERVER BARU' : 'SETUP NEW SERVER',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final telemetry = context.watch<TelemetryProvider>();
    final events =
        List<AuthEvent>.from(
            telemetry.filteredEvents,
          ).where((e) => e.serverId == activeServer.id).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        title: Text(
          isIndo ? 'EKSPLORASI FORENSIK & AUDIT' : 'AUDIT & FORENSIC EXPLORER',
        ),
        actions: [
          IconButton(
            icon: Icon(
              telemetry.isLiveMonitoring
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              color: telemetry.isLiveMonitoring
                  ? (isDark ? AppColors.success : AppColors.successLight)
                  : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
            ),
            tooltip: telemetry.isLiveMonitoring
                ? (isIndo ? 'Jeda Streaming Langsung' : 'Pause Live Stream')
                : (isIndo
                      ? 'Lanjutkan Streaming Langsung'
                      : 'Resume Live Stream'),
            onPressed: () => telemetry.toggleLiveMonitoring(),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: isIndo ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const FaqScreen(initialCategory: FaqCategory.detection),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return Column(
            children: [
              // Search & Filter Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 16,
                  vertical: 12,
                ),
                color: theme.colorScheme.surface,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      children: [
                        // Search Input
                        TextField(
                          onChanged: (val) => telemetry.setSearchQuery(val),
                          decoration: InputDecoration(
                            hintText: isIndo
                                ? 'Cari IP (cth. 185.), User, atau Alasan...'
                                : 'Search IP (e.g. 185.), User, or Reason...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.lightTextMuted,
                            ),
                            suffixIcon: telemetry.searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () =>
                                        telemetry.setSearchQuery(''),
                                  )
                                : null,
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Service Filter Chips (Expanded to all available infrastructure services)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildChip(
                                context: context,
                                label: isIndo
                                    ? 'SEMUA LAYANAN'
                                    : 'ALL SERVICES',
                                isSelected: telemetry.serviceFilter == 'all',
                                isDark: isDark,
                                onTap: () => telemetry.setServiceFilter('all'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'MYSQLD',
                                isSelected: telemetry.serviceFilter == 'mysqld',
                                accentColor: AppColors.mysql,
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('mysqld'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'SSHD',
                                isSelected: telemetry.serviceFilter == 'sshd',
                                accentColor: AppColors.ssh,
                                isDark: isDark,
                                onTap: () => telemetry.setServiceFilter('sshd'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'HTTPD / APACHE',
                                isSelected: telemetry.serviceFilter == 'httpd',
                                accentColor: const Color(0xFFEF4444),
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('httpd'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'NGINX',
                                isSelected: telemetry.serviceFilter == 'nginx',
                                accentColor: const Color(0xFF10B981),
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('nginx'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'DOVECOT (MAIL)',
                                isSelected:
                                    telemetry.serviceFilter == 'dovecot',
                                accentColor: const Color(0xFF8B5CF6),
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('dovecot'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'EXIM',
                                isSelected: telemetry.serviceFilter == 'exim',
                                accentColor: const Color(0xFFEC4899),
                                isDark: isDark,
                                onTap: () => telemetry.setServiceFilter('exim'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'PURE-FTPD',
                                isSelected:
                                    telemetry.serviceFilter == 'pure-ftpd',
                                accentColor: const Color(0xFFF59E0B),
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('pure-ftpd'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'REDIS',
                                isSelected:
                                    telemetry.serviceFilter == 'redis-server',
                                accentColor: const Color(0xFFDC2626),
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('redis-server'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'PHP-FPM',
                                isSelected:
                                    telemetry.serviceFilter == 'php-fpm',
                                accentColor: const Color(0xFF6366F1),
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('php-fpm'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'CROND',
                                isSelected: telemetry.serviceFilter == 'crond',
                                accentColor: const Color(0xFF14B8A6),
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('crond'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: 'OLLAMA / AI',
                                isSelected: telemetry.serviceFilter == 'ollama',
                                accentColor: const Color(0xFF06B6D4),
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setServiceFilter('ollama'),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                height: 16,
                                width: 1,
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                              const SizedBox(width: 14),
                              // Status Filters
                              _buildChip(
                                context: context,
                                label: isIndo ? 'SEMUA STATUS' : 'ALL STATUS',
                                isSelected: telemetry.statusFilter == 'all',
                                isDark: isDark,
                                onTap: () => telemetry.setStatusFilter('all'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: isIndo
                                    ? 'AKUN ANOMALI'
                                    : 'UNKNOWN ENTITY',
                                isSelected: telemetry.statusFilter == 'unknown',
                                accentColor: isDark
                                    ? AppColors.warning
                                    : AppColors.warningLight,
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setStatusFilter('unknown'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: isIndo ? 'GAGAL / BLOK' : 'FAILED',
                                isSelected: telemetry.statusFilter == 'failed',
                                accentColor: isDark
                                    ? AppColors.danger
                                    : AppColors.dangerLight,
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setStatusFilter('failed'),
                              ),
                              const SizedBox(width: 8),
                              _buildChip(
                                context: context,
                                label: isIndo ? 'DIIZINKAN' : 'AUTHORIZED',
                                isSelected: telemetry.statusFilter == 'success',
                                accentColor: isDark
                                    ? AppColors.success
                                    : AppColors.successLight,
                                isDark: isDark,
                                onTap: () =>
                                    telemetry.setStatusFilter('success'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Count & Status Bar
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 16,
                  vertical: 8,
                ),
                color: theme.scaffoldBackgroundColor,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          isIndo
                              ? 'MENAMPILKAN ${events.length} REKAMAN LOG'
                              : 'SHOWING ${events.length} LOG EVENTS',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.lightTextMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (telemetry.searchQuery.isNotEmpty ||
                            telemetry.serviceFilter != 'all' ||
                            telemetry.statusFilter != 'all')
                          GestureDetector(
                            onTap: () {
                              telemetry.setSearchQuery('');
                              telemetry.setServiceFilter('all');
                              telemetry.setStatusFilter('all');
                            },
                            child: Text(
                              isIndo ? 'RESET FILTER' : 'RESET FILTERS',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Events List with Pull-to-Refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _handleRefresh(context),
                  child: events.isEmpty
                      ? LayoutBuilder(
                          builder: (context, boxConstraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: boxConstraints.maxHeight,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 48,
                                        color:
                                            (isDark
                                                    ? AppColors.textMuted
                                                    : AppColors.lightTextMuted)
                                                .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        isIndo
                                            ? 'Tidak ada rekaman log akses yang cocok\n(Tarik ke bawah untuk memuat ulang)'
                                            : 'No matching access logs found\n(Pull down to refresh)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.textSecondary
                                              : AppColors.lightTextSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: isWide ? 32 : 16,
                                vertical: 12,
                              ),
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                return EventTile(event: events[index]);
                              },
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    Color? accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.12)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? color
                : (isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
