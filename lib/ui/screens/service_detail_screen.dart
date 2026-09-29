import 'server_management_screen.dart';
import 'audit_explorer_screen.dart';
import '../../core/security/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/service_registry.dart';
import '../../providers/server_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import 'faq_screen.dart';
import '../../services/ssh_service.dart';
import '../../models/auth_event.dart';
import '../widgets/event_tile.dart';
import '../widgets/two_factor_auth_dialog.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String? initialServiceId;

  const ServiceDetailScreen({super.key, this.initialServiceId});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  String? _currentServiceId;

  String get _selectedServiceId =>
      _currentServiceId ?? widget.initialServiceId ?? 'mysqld';

  set _selectedServiceId(String val) {
    _currentServiceId = val;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceId != null) {
      _currentServiceId = widget.initialServiceId;
    }
  }

  @override
  void didUpdateWidget(covariant ServiceDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialServiceId != null &&
        widget.initialServiceId != oldWidget.initialServiceId) {
      _currentServiceId = widget.initialServiceId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();

    final serverProvider = context.watch<ServerProvider>();
    final activeServer = serverProvider.activeServer;
    final telemetry = context.watch<TelemetryProvider>();
    final allEvents = telemetry.allEvents;

    final services = ServiceRegistry.knownServices;
    final selectedDef = ServiceRegistry.getById(_selectedServiceId);

    final serviceStatuses = activeServer?.serviceStatuses ?? {};
    final isOnline =
        serviceStatuses[selectedDef.id] ??
        (activeServer?.isConnected == true &&
            (selectedDef.id == 'mysqld' || selectedDef.id == 'sshd'));

    // Filter events strictly for active server and selected service
    final serverEvents = activeServer != null
        ? allEvents.where((e) => e.serverId == activeServer.id).toList()
        : <AuthEvent>[];

    final events = serverEvents.where((e) {
      final s = e.service.toLowerCase();
      final target = selectedDef.id.toLowerCase();
      return s.contains(target) || target.contains(s);
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        title: Text(
          settings.isIndonesian
              ? 'FORENSIK & KONTROL LAYANAN'
              : 'SERVICE FORENSICS & CONTROL',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted_rounded),
            tooltip: settings.isIndonesian
                ? 'Buka Log Audit Forensik'
                : 'Open Forensic Audit Log',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuditExplorerScreen(
                    initialServiceFilter: _selectedServiceId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: settings.isIndonesian
                ? 'Pusat Bantuan & FAQ'
                : 'Help Center & FAQ',
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
            tooltip: settings.isIndonesian
                ? 'Periksa Status Layanan'
                : 'Probe Service Status',
            onPressed: serverProvider.isLoading
                ? null
                : () async {
                    if (activeServer != null) {
                      await serverProvider.testServer(
                        activeServer,
                        onPrompt2FA: (prompt) => TwoFactorAuthDialog.show(
                          context,
                          username: activeServer.username,
                          serverName: activeServer.name,
                          promptText: prompt,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

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
                            ? 'Pilih atau hubungkan server terlebih dahulu untuk melihat status layanan dan kontrol forensik.'
                            : 'Select or connect a server first to monitor service statuses and forensic controls.',
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
                        settings.isIndonesian
                            ? 'SETUP SERVER BARU'
                            : 'SETUP NEW SERVER',
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
            );
          }

          return Column(
            children: [
              // Horizontal Scrollable Service Filter Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: services.map((def) {
                      final isSelected = def.id == _selectedServiceId;
                      final up =
                          serviceStatuses[def.id] ??
                          (activeServer.isConnected == true &&
                              (def.id == 'mysqld' || def.id == 'sshd'));

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(
                            def.icon,
                            size: 14,
                            color: isSelected ? Colors.white : def.color,
                          ),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(def.name),
                              const SizedBox(width: 5),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: up
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedServiceId = def.id;
                            });
                          },
                          selectedColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Service Deep Dive View
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 32 : 16,
                        vertical: 16,
                      ),
                      children: [
                        // Service Overview Header Card
                        _buildServiceOverviewCard(
                          context,
                          selectedDef,
                          isOnline,
                          isDark,
                          settings,
                        ),
                        const SizedBox(height: 18),

                        // Service Lifecycle Control Panel (Start, Stop, Restart)
                        _buildServiceControlPanel(
                          context,
                          selectedDef,
                          isOnline,
                          isDark,
                          settings,
                        ),
                        const SizedBox(height: 20),

                        // Mini KPI Metrics Grid
                        _buildServiceStats(
                          context,
                          events,
                          selectedDef,
                          isDark,
                          settings,
                        ),
                        const SizedBox(height: 20),

                        // Targeted User Accounts distribution
                        _buildTargetedUsersSection(
                          context,
                          events,
                          selectedDef,
                          isDark,
                          settings,
                        ),
                        const SizedBox(height: 22),

                        // Incident Log Feed for this service
                        _buildAuditTrailSection(
                          context,
                          events,
                          selectedDef,
                          isDark,
                          settings,
                        ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildServiceOverviewCard(
    BuildContext context,
    ServiceDefinition def,
    bool isOnline,
    bool isDark,
    SettingsProvider settings,
  ) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: def.color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: def.color.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(def.icon, color: def.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            def.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${def.portDisplay} • ${def.category}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isOnline ? AppColors.success : AppColors.danger)
                        .withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isOnline ? AppColors.success : AppColors.danger)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline
                            ? (settings.isIndonesian
                                  ? 'AKTIF & TERPANTAU'
                                  : 'ACTIVE & MONITORED')
                            : (settings.isIndonesian
                                  ? 'NONAKTIF / MATI'
                                  : 'OFFLINE / INACTIVE'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isOnline
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            Text(
              def.description,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildSmallTag(
                  context,
                  Icons.terminal_rounded,
                  'Daemon: ${def.pgrepPattern}',
                  isDark,
                ),
                if (def.defaultLogPath.isNotEmpty)
                  _buildSmallTag(
                    context,
                    Icons.description_outlined,
                    'Log: ${def.defaultLogPath}',
                    isDark,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive lifecycle control panel with Start, Stop, and Restart actions
  Widget _buildServiceControlPanel(
    BuildContext context,
    ServiceDefinition def,
    bool isOnline,
    bool isDark,
    SettingsProvider settings,
  ) {
    final theme = Theme.of(context);
    final isIndo = settings.isIndonesian;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isIndo
                      ? 'KONTROL & MANAJEMEN LAYANAN'
                      : 'SERVICE LIFECYCLE & CONTROL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isIndo
                ? 'Kirim sinyal start, stop, atau restart secara aman ke daemon server via koneksi SSH terenkripsi.'
                : 'Safely dispatch start, stop, or restart signals to the server daemon via encrypted SSH.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Start, Stop, Restart
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // START BUTTON (Only shown when service is INACTIVE/STOPPED)
              if (!isOnline)
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(isIndo ? 'Mulai Layanan' : 'Start Service'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(
                      color: AppColors.success,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: AppColors.success.withValues(
                      alpha: isDark ? 0.1 : 0.05,
                    ),
                  ),
                  onPressed: () => _showControlConfirmationDialog(
                    context,
                    def,
                    'start',
                    isOnline,
                  ),
                ),

              // STOP BUTTON (Only shown when service is ACTIVE/ONLINE)
              if (isOnline)
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: Text(isIndo ? 'Hentikan Layanan' : 'Stop Service'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: AppColors.danger.withValues(
                      alpha: isDark ? 0.1 : 0.05,
                    ),
                  ),
                  onPressed: () => _showControlConfirmationDialog(
                    context,
                    def,
                    'stop',
                    isOnline,
                  ),
                ),

              // RESTART BUTTON (Always shown)
              ElevatedButton.icon(
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(
                  isIndo ? 'Muat Ulang (Restart)' : 'Restart Service',
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                onPressed: () => _showControlConfirmationDialog(
                  context,
                  def,
                  'restart',
                  isOnline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showControlConfirmationDialog(
    BuildContext context,
    ServiceDefinition def,
    String action,
    bool isOnline,
  ) async {
    final serverProvider = context.read<ServerProvider>();
    final settings = context.read<SettingsProvider>();
    final isIndo = settings.isIndonesian;
    final activeServer = serverProvider.activeServer;

    if (activeServer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isIndo
                ? 'Tidak ada server aktif. Pilih server di menu Server Fleet.'
                : 'No active server selected. Select one in Server Fleet.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final String actionTitle;
    final Color actionColor;
    final IconData actionIcon;
    switch (action) {
      case 'start':
        actionTitle = isIndo ? 'Mulai Layanan' : 'Start Service';
        actionColor = AppColors.success;
        actionIcon = Icons.play_arrow_rounded;
        break;
      case 'stop':
        actionTitle = isIndo ? 'Hentikan Layanan' : 'Stop Service';
        actionColor = AppColors.danger;
        actionIcon = Icons.stop_rounded;
        break;
      case 'restart':
      default:
        actionTitle = isIndo ? 'Muat Ulang Layanan' : 'Restart Service';
        actionColor = const Color(0xFF00E5FF);
        actionIcon = Icons.restart_alt_rounded;
        break;
    }

    final savedSudo = await serverProvider.getSavedSudoPassword(
      activeServer.id,
    );
    final sudoController = TextEditingController(text: savedSudo ?? '');
    String? validationError;
    bool obscurePassword = true;
    bool isRunning = false;
    ServiceActionResult? executionResult;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: !isRunning,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: actionColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(actionIcon, color: actionColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${def.name} (${def.id})',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target server badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.dns_outlined,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${activeServer.name} • ${activeServer.username}@${activeServer.host}:${activeServer.port}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Warning / notice banner
                      if (action == 'stop')
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isIndo
                                      ? 'PERINGATAN: Menghentikan daemon ini akan memutus koneksi klien aktif dan menghentikan operasional terkait.'
                                      : 'WARNING: Stopping this daemon will disconnect active clients and interrupt associated operations.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (action == 'restart')
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00E5FF,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF00E5FF,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF00E5FF),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isIndo
                                      ? 'Daemon akan dimuat ulang. Modifikasi konfigurasi akan langsung diterapkan.'
                                      : 'Daemon will reload gracefully. Updated configuration files will take effect.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),

                      // Sudo password input
                      if (executionResult == null) ...[
                        if (activeServer.username != 'root') ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isIndo
                                        ? 'Pengguna aktif (${activeServer.username}) bukan root. Kontrol service memerlukan kata sandi sudo dari akun administratif (seperti wito_general / root).'
                                        : 'Active user (${activeServer.username}) is non-root. Service management requires a sudo password from an administrative user (e.g. wito_general / root).',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          isIndo
                              ? 'Kata Sandi Sudo (Eskalasi Hak Akses):'
                              : 'Sudo Password (Privilege Escalation):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: sudoController,
                          obscureText: obscurePassword,
                          enabled: !isRunning,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                          onChanged: (_) {
                            if (validationError != null) {
                              setDialogState(() {
                                validationError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            errorText: validationError,
                            hintText: isIndo
                                ? (activeServer.username == 'root'
                                      ? 'Masukkan kata sandi sudo (opsional jika root)'
                                      : 'Wajib: Masukkan kata sandi sudo untuk ${activeServer.username}')
                                : (activeServer.username == 'root'
                                      ? 'Enter sudo password (optional if root)'
                                      : 'Required: Enter sudo password for ${activeServer.username}'),
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.lightTextMuted,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (sudoController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 13,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  isIndo
                                      ? 'Kata sandi pengguna ${activeServer.username} dimuat dari Secure Vault.'
                                      : 'Password for ${activeServer.username} loaded from Secure Vault.',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          isIndo
                              ? 'Disimpan terenkripsi dengan AES-256 di Secure Vault perangkat Anda.'
                              : 'Encrypted via hardware AES-256 in your device Secure Vault.',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],

                      // Running spinner
                      if (isRunning) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          color: actionColor,
                          backgroundColor: actionColor.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            isIndo
                                ? 'Mengirim perintah $action ke ${activeServer.host}...'
                                : 'Executing $action signal on ${activeServer.host}...',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ],

                      // Execution Result
                      if (executionResult != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: executionResult!.success
                                ? (isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard)
                                : AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: executionResult!.success
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    executionResult!.success
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.error_outline_rounded,
                                    size: 16,
                                    color: executionResult!.success
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      executionResult!.success
                                          ? (isIndo
                                                ? 'Operasi Berhasil Dijalankan'
                                                : 'Operation Completed Successfully')
                                          : (isIndo
                                                ? 'Operasi Mengalami Kendala'
                                                : 'Operation Encountered Error'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: executionResult!.success
                                            ? AppColors.success
                                            : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                    ),
                                    tooltip: isIndo ? 'Salin Log' : 'Copy Log',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: executionResult!.output,
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isIndo
                                                ? 'Log disalin ke papan klip'
                                                : 'Log copied to clipboard',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              if (executionResult!.errorMessage != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  executionResult!.errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: SelectableText(
                                  executionResult!.output.trim().isEmpty
                                      ? (isIndo
                                            ? 'Perintah selesai tanpa keluaran konsol.'
                                            : 'Command executed without stdout output.')
                                      : executionResult!.output.trim(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF00FF66),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (executionResult == null && !isRunning)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(isIndo ? 'Batal' : 'Cancel'),
                  ),
                if (executionResult == null && !isRunning)
                  ElevatedButton.icon(
                    icon: Icon(actionIcon, size: 16),
                    label: Text(actionTitle),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: action == 'restart'
                          ? Colors.black
                          : Colors.white,
                    ),
                    onPressed: () async {
                      final enteredPass = sudoController.text.trim();
                      if (activeServer.username != 'root' &&
                          enteredPass.isEmpty) {
                        setDialogState(() {
                          validationError = isIndo
                              ? 'Kata sandi akun/sudo ${activeServer.username} wajib diisi.'
                              : 'Password for ${activeServer.username} is required for sudo.';
                        });
                        return;
                      }

                      final settingsProvider = context.read<SettingsProvider>();
                      if (settingsProvider.biometricLock) {
                        final authOk = await BiometricService().authenticate(
                          context: context,
                          reason: isIndo
                              ? 'Otorisasi biometrik untuk menjalankan $actionTitle pada ${def.name}'
                              : 'Biometric authorization required to execute $actionTitle on ${def.name}',
                        );
                        if (!authOk) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isIndo
                                      ? 'Autentikasi biometrik dibatalkan.'
                                      : 'Biometric authentication was canceled.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                      }

                      setDialogState(() {
                        isRunning = true;
                        validationError = null;
                      });

                      if (enteredPass.isNotEmpty) {
                        await serverProvider.saveSudoPassword(
                          activeServer.id,
                          enteredPass,
                        );
                      }

                      final res = await serverProvider.executeServiceControl(
                        serviceId: def.id,
                        action: action,
                        sudoPassword: enteredPass,
                        onPrompt2FA: (prompt) => TwoFactorAuthDialog.show(
                          context,
                          username: activeServer.username,
                          serverName: activeServer.name,
                          promptText: prompt,
                        ),
                      );

                      if (context.mounted) {
                        setDialogState(() {
                          isRunning = false;
                          executionResult = res;
                        });
                      }
                    },
                  )
                else if (executionResult != null)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(isIndo ? 'Selesai' : 'Dismiss'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSmallTag(
    BuildContext context,
    IconData icon,
    String label,
    bool isDark,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStats(
    BuildContext context,
    List<AuthEvent> events,
    ServiceDefinition def,
    bool isDark,
    SettingsProvider settings,
  ) {
    final total = events.length;
    final failed = events.where((e) => e.status == EventStatus.failed).length;
    final unknown = events.where((e) => e.isUnknownPerson).length;
    final success = events.where((e) => e.status == EventStatus.success).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 600 ? 2 : 4;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _buildMiniStat(
              settings.isIndonesian ? 'TOTAL AKSES' : 'TOTAL ATTEMPTS',
              total.toString(),
              def.color,
              isDark,
            ),
            _buildMiniStat(
              settings.isIndonesian ? 'GAGAL / BLOK' : 'FAILED / DROPPED',
              failed.toString(),
              AppColors.danger,
              isDark,
            ),
            _buildMiniStat(
              settings.isIndonesian ? 'AKUN ANOMALI' : 'UNKNOWN ENTITIES',
              unknown.toString(),
              AppColors.warning,
              isDark,
            ),
            _buildMiniStat(
              settings.isIndonesian ? 'BERHASIL' : 'AUTHENTICATED',
              success.toString(),
              AppColors.success,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTargetedUsersSection(
    BuildContext context,
    List<AuthEvent> events,
    ServiceDefinition def,
    bool isDark,
    SettingsProvider settings,
  ) {
    final theme = Theme.of(context);
    final Map<String, int> targetUsers = {};
    for (final e in events) {
      targetUsers[e.user] = (targetUsers[e.user] ?? 0) + 1;
    }

    if (targetUsers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settings.isIndonesian
              ? 'DISTRIBUSI AKUN SASARAN'
              : 'TARGETED ACCOUNTS & USERNAMES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            children: targetUsers.entries.map((entry) {
              final isCriticalUser =
                  entry.key.toLowerCase() == 'root' ||
                  entry.key.toLowerCase() == 'admin';
              final percent = events.isNotEmpty
                  ? (entry.value / events.length) * 100
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                isCriticalUser
                                    ? Icons.warning_rounded
                                    : Icons.account_circle_outlined,
                                size: 14,
                                color: isCriticalUser
                                    ? (isDark
                                          ? AppColors.danger
                                          : AppColors.dangerLight)
                                    : (isDark
                                          ? AppColors.textSecondary
                                          : AppColors.lightTextSecondary),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCriticalUser
                                        ? (isDark
                                              ? AppColors.danger
                                              : AppColors.dangerLight)
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.value} (${percent.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.lightTextMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.lightSurfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCriticalUser
                              ? (isDark
                                    ? AppColors.danger
                                    : AppColors.dangerLight)
                              : def.color,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAuditTrailSection(
    BuildContext context,
    List<AuthEvent> events,
    ServiceDefinition def,
    bool isDark,
    SettingsProvider settings,
  ) {
    const int previewLimit = 5;
    final displayEvents = events.take(previewLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.isIndonesian
                        ? 'JEJAK AUDIT & KEJADIAN KEAMANAN ${def.name.toUpperCase()}'
                        : '${def.name.toUpperCase()} SECURITY AUDIT TRAIL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      settings.isIndonesian
                          ? 'Pratinjau diagnostik ${displayEvents.length} kejadian terkini dari total ${events.length}'
                          : 'Diagnostic preview of ${displayEvents.length} latest events of ${events.length} total',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (events.length > previewLimit)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: def.color,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AuditExplorerScreen(
                        initialServiceFilter: def.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: Text(
                  settings.isIndonesian ? 'Buka Semua' : 'View All',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
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
            child: Column(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 32,
                  color: isDark ? AppColors.success : AppColors.successLight,
                ),
                const SizedBox(height: 8),
                Text(
                  settings.isIndonesian
                      ? 'Semua parameter normal. Daemon ${def.name} beroperasi sesuai kebijakan dasar.'
                      : 'All parameters normal. Daemon ${def.name} operating within baseline policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.lightTextMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...displayEvents.map((e) => EventTile(event: e)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: def.color.withValues(alpha: isDark ? 0.35 : 0.25),
              ),
              color: def.color.withValues(alpha: isDark ? 0.08 : 0.04),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AuditExplorerScreen(
                        initialServiceFilter: def.id,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.travel_explore_rounded, size: 18, color: def.color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          settings.isIndonesian
                              ? 'Eksplorasi Riwayat Forensik Lengkap (${events.length} Kejadian) →'
                              : 'Explore Full Forensic Audit Trail (${events.length} Events) →',
                          style: TextStyle(
                            color: def.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
