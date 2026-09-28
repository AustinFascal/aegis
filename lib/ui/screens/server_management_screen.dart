import '../../providers/telemetry_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/security/biometric_service.dart';
import 'package:flutter/material.dart';
import '../widgets/two_factor_auth_dialog.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/server_profile.dart';
import '../../providers/server_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import 'compliance_screen.dart';
import 'faq_screen.dart';
import 'sftp_screen.dart';
import 'terminal_screen.dart';

class ServerManagementScreen extends StatefulWidget {
  const ServerManagementScreen({super.key});

  static void showServerDialog(
    BuildContext context, [
    ServerProfile? existingServer,
  ]) {
    _ServerManagementScreenState.showServerConfigDialog(
      context,
      existingServer,
    );
  }

  @override
  State<ServerManagementScreen> createState() => _ServerManagementScreenState();
}

class _ServerManagementScreenState extends State<ServerManagementScreen> {
  String? _testingServerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    final serverProvider = context.watch<ServerProvider>();
    final servers = serverProvider.servers;
    final activeServer = serverProvider.activeServer;

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        title: Text(isIndo ? 'ARMADA SERVER & VAULT' : 'SERVER FLEET & VAULT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: isIndo ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const FaqScreen(initialCategory: FaqCategory.server),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
            tooltip: isIndo ? 'Tambah Server Baru' : 'Add New Server',
            onPressed: () => _showServerDialog(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (servers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 54,
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.lightTextMuted,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isIndo
                        ? 'Belum Ada Server Dikonfigurasi'
                        : 'No Servers Configured',
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isIndo
                        ? 'Tambahkan VPS Linux atau host database Anda untuk mulai memantau.'
                        : 'Add your Linux VPS or database host to begin monitoring.',
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.lightTextMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _showServerDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(isIndo ? 'TAMBAH SERVER' : 'ADD SERVER'),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 16,
                  vertical: 16,
                ),
                itemCount: servers.length,
                itemBuilder: (context, index) {
                  final server = servers[index];
                  final isActive = server.id == activeServer?.id;
                  final hasKey = serverProvider.hasStoredCredential(server.id);
                  final isTestingThis = _testingServerId == server.id;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isActive
                            ? theme.colorScheme.primary
                            : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            (server.isConnected
                                                    ? (isDark
                                                          ? AppColors.success
                                                          : AppColors
                                                                .successLight)
                                                    : (isDark
                                                          ? AppColors.textMuted
                                                          : AppColors
                                                                .lightTextMuted))
                                                .withValues(
                                                  alpha: isDark ? 0.12 : 0.08,
                                                ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.dns_rounded,
                                        color: server.isConnected
                                            ? (isDark
                                                  ? AppColors.success
                                                  : AppColors.successLight)
                                            : (isDark
                                                  ? AppColors.textMuted
                                                  : AppColors.lightTextMuted),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            server.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color:
                                                  theme.colorScheme.onSurface,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${server.username}@${server.host}:${server.port}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark
                                                  ? AppColors.textSecondary
                                                  : AppColors
                                                        .lightTextSecondary,
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.15 : 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(
                                            alpha: isDark ? 0.4 : 0.3,
                                          ),
                                    ),
                                  ),
                                  child: Text(
                                    isIndo ? 'AKTIF' : 'ACTIVE',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              // Vault Status Tag
                              _buildInfoTag(
                                context,
                                hasKey
                                    ? Icons.lock_rounded
                                    : Icons.warning_amber_rounded,
                                hasKey
                                    ? (server.authType == AuthType.privateKey
                                          ? (isIndo
                                                ? 'Kunci SSH Tersimpan di Vault'
                                                : 'SSH Key Secured in Vault')
                                          : (isIndo
                                                ? 'Password Tersimpan di Vault'
                                                : 'Password Secured in Vault'))
                                    : (isIndo
                                          ? 'Belum Ada Kredensial (Ketuk untuk Konfigurasi)'
                                          : 'No Credential (Tap to Configure)'),
                                isDark,
                                textColor: hasKey
                                    ? (isDark
                                          ? AppColors.success
                                          : AppColors.successLight)
                                    : (isDark
                                          ? AppColors.warning
                                          : AppColors.warningLight),
                                iconColor: hasKey
                                    ? (isDark
                                          ? AppColors.success
                                          : AppColors.successLight)
                                    : (isDark
                                          ? AppColors.warning
                                          : AppColors.warningLight),
                                onTap: hasKey
                                    ? null
                                    : () => _showServerDialog(context, server),
                              ),
                              _buildInfoTag(
                                context,
                                Icons.sync_rounded,
                                server.lastChecked != null
                                    ? (isIndo
                                          ? 'Diperiksa ${Formatters.timeAgo(server.lastChecked!)}'
                                          : 'Checked ${Formatters.timeAgo(server.lastChecked!)}')
                                    : (isIndo
                                          ? 'Belum diperiksa'
                                          : 'Not checked'),
                                isDark,
                              ),
                              if (server.serviceStatuses.isNotEmpty)
                                _buildInfoTag(
                                  context,
                                  Icons.layers_rounded,
                                  'mysqld: ${server.serviceStatuses['mysqld'] == true ? (isIndo ? 'UP' : 'UP') : (isIndo ? 'DOWN' : 'DOWN')} • sshd: ${server.serviceStatuses['sshd'] == true ? (isIndo ? 'UP' : 'UP') : (isIndo ? 'DOWN' : 'DOWN')}',
                                  isDark,
                                  textColor: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              // Test SSH Button
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: isTestingThis
                                    ? null
                                    : () async {
                                        if (!hasKey) {
                                          _showMissingKeyDialog(
                                            context,
                                            server,
                                          );
                                          return;
                                        }

                                        setState(
                                          () => _testingServerId = server.id,
                                        );
                                        final result = await serverProvider
                                            .testServer(
                                              server,
                                              onPrompt2FA: (prompt) =>
                                                  TwoFactorAuthDialog.show(
                                                    context,
                                                    username: server.username,
                                                    serverName: server.name,
                                                    promptText: prompt,
                                                  ),
                                            );
                                        setState(() => _testingServerId = null);

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                result.success
                                                    ? (isIndo
                                                          ? '✅ Koneksi SSH berhasil ke ${server.name}!\nUptime: ${result.uptime} • OS: ${result.osInfo}'
                                                          : '✅ SSH connection successful to ${server.name}!\nUptime: ${result.uptime} • OS: ${result.osInfo}')
                                                    : (isIndo
                                                          ? '⚠️ Koneksi gagal: ${result.errorMessage}'
                                                          : '⚠️ Connection failed: ${result.errorMessage}'),
                                              ),
                                              backgroundColor: result.success
                                                  ? (isDark
                                                        ? AppColors.darkCard
                                                        : AppColors
                                                              .lightTextPrimary)
                                                  : (isDark
                                                        ? AppColors.danger
                                                        : AppColors
                                                              .dangerLight),
                                              duration: const Duration(
                                                seconds: 4,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                icon: isTestingThis
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.flash_on_rounded,
                                        size: 16,
                                      ),
                                label: Text(
                                  isTestingThis
                                      ? (isIndo ? 'MENGUJI...' : 'TESTING...')
                                      : (isIndo ? 'UJI SSH' : 'TEST SSH'),
                                ),
                              ),

                              // Configure / Edit Button
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () =>
                                    _showServerDialog(context, server),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: Text(
                                  isIndo ? 'KONFIGURASI' : 'CONFIGURE',
                                ),
                              ),

                              // Interactive SSH Terminal Button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.primary.withValues(alpha: 0.18)
                                      : AppColors.primaryLight.withValues(alpha: 0.15),
                                  foregroundColor: isDark
                                      ? AppColors.primary
                                      : AppColors.primaryLight,
                                  side: BorderSide(
                                    color: (isDark ? AppColors.primary : AppColors.primaryLight)
                                        .withValues(alpha: 0.5),
                                    width: 1.1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TerminalScreen(server: server),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.terminal_rounded, size: 16),
                                label: Text(isIndo ? 'TERMINAL' : 'TERMINAL'),
                              ),

                              // SFTP Remote File Manager Button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.purple.withValues(alpha: 0.18)
                                      : AppColors.purpleLight.withValues(alpha: 0.15),
                                  foregroundColor: isDark
                                      ? AppColors.purple
                                      : AppColors.purpleLight,
                                  side: BorderSide(
                                    color: (isDark ? AppColors.purple : AppColors.purpleLight)
                                        .withValues(alpha: 0.5),
                                    width: 1.1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SftpScreen(server: server),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.folder_shared_rounded, size: 16),
                                label: const Text('SFTP'),
                              ),

                              // System Hardening & Compliance Scanner Button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.success.withValues(alpha: 0.18)
                                      : AppColors.successLight.withValues(alpha: 0.15),
                                  foregroundColor: isDark
                                      ? AppColors.success
                                      : AppColors.successLight,
                                  side: BorderSide(
                                    color: (isDark ? AppColors.success : AppColors.successLight)
                                        .withValues(alpha: 0.5),
                                    width: 1.1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ComplianceScreen(server: server),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.verified_user_rounded, size: 16),
                                label: const Text('HARDENING'),
                              ),

                              // Reboot Server Button
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: BorderSide(
                                    color: AppColors.danger.withValues(
                                      alpha: isDark ? 0.6 : 0.4,
                                    ),
                                    width: 1.1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () =>
                                    _confirmRebootServer(context, server),
                                icon: const Icon(
                                  Icons.restart_alt_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  isIndo ? 'RESTART SERVER' : 'REBOOT SERVER',
                                ),
                              ),

                              // Select as Active Button
                              if (!isActive)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final settings = context
                                        .read<SettingsProvider>();
                                    if (settings.biometricLock) {
                                      final authOk = await BiometricService()
                                          .authenticate(
                                            context: context,
                                            reason: isIndo
                                                ? 'Otorisasi biometrik untuk menghubungkan ke server ${server.name}'
                                                : 'Biometric authorization required to connect to server ${server.name}',
                                          );
                                      if (!authOk) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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
                                    serverProvider.selectServer(server.id);
                                  },
                                  child: Text(isIndo ? 'PILIH' : 'SELECT'),
                                ),

                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: isDark
                                      ? AppColors.textMuted
                                      : AppColors.lightTextMuted,
                                ),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showServerDialog(context, server);
                                  } else if (val == 'reboot') {
                                    _confirmRebootServer(context, server);
                                  } else if (val == 'delete') {
                                    _confirmDelete(context, server);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit_rounded,
                                          color: isDark
                                              ? AppColors.textSecondary
                                              : AppColors.lightTextSecondary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isIndo
                                              ? 'Edit Server & Kunci'
                                              : 'Edit Server & Key',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'reboot',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.restart_alt_rounded,
                                          size: 16,
                                          color: AppColors.danger,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isIndo
                                              ? 'Restart Server'
                                              : 'Reboot Server',
                                          style: const TextStyle(
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          color: isDark
                                              ? AppColors.danger
                                              : AppColors.dangerLight,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isIndo
                                              ? 'Hapus Server'
                                              : 'Remove Server',
                                          style: TextStyle(
                                            color: isDark
                                                ? AppColors.danger
                                                : AppColors.dangerLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTag(
    BuildContext context,
    IconData icon,
    String label,
    bool isDark, {
    Color? textColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final widget = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color:
                iconColor ??
                (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    textColor ??
                    (isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary),
                fontSize: 11,
                fontWeight: textColor != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: widget,
        ),
      );
    }
    return widget;
  }

  void _showMissingKeyDialog(BuildContext context, ServerProfile server) {
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(isIndo ? 'Kredensial Tidak Ditemukan' : 'No Credential Found'),
          ],
        ),
        content: Text(
          isIndo
              ? 'Tidak ada kunci privat SSH atau password yang tersimpan di vault aman untuk "${server.name}".\n\nApakah Anda ingin mengonfigurasinya sekarang?'
              : 'No SSH private key or password is saved in the secure vault for "${server.name}".\n\nWould you like to configure it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isIndo ? 'BATAL' : 'CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showServerDialog(context, server);
            },
            child: Text(isIndo ? 'KONFIGURASI KUNCI' : 'CONFIGURE KEY'),
          ),
        ],
      ),
    );
  }

  void _showServerDialog(
    BuildContext context, [
    ServerProfile? existingServer,
  ]) {
    ServerManagementScreen.showServerDialog(context, existingServer);
  }

  static void showServerConfigDialog(
    BuildContext context, [
    ServerProfile? existingServer,
  ]) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    final formKey = GlobalKey<FormState>();

    final isEdit = existingServer != null;
    final serverProvider = context.read<ServerProvider>();
    final hasStored =
        isEdit && serverProvider.hasStoredCredential(existingServer.id);

    final nameCtrl = TextEditingController(text: existingServer?.name ?? '');
    final hostCtrl = TextEditingController(text: existingServer?.host ?? '');
    final portCtrl = TextEditingController(
      text: (existingServer?.port ?? 22).toString(),
    );
    final userCtrl = TextEditingController(
      text: existingServer?.username ?? 'root',
    );
    final credCtrl = TextEditingController();

    AuthType authType = existingServer?.authType ?? AuthType.privateKey;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540),
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isEdit
                                    ? Icons.tune_rounded
                                    : Icons.add_to_queue_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isEdit
                                    ? (isIndo
                                          ? 'KONFIGURASI SERVER & VAULT'
                                          : 'CONFIGURE SERVER & VAULT')
                                    : (isIndo
                                          ? 'TAMBAH SERVER BARU'
                                          : 'ADD NEW SERVER'),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(
                              Icons.close,
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 14),

                      // Stored status banner for existing servers
                      if (isEdit) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (hasStored
                                        ? AppColors.success
                                        : AppColors.warning)
                                    .withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  (hasStored
                                          ? AppColors.success
                                          : AppColors.warning)
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasStored
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.info_outline_rounded,
                                size: 18,
                                color: hasStored
                                    ? (isDark
                                          ? AppColors.success
                                          : AppColors.successLight)
                                    : (isDark
                                          ? AppColors.warning
                                          : AppColors.warningLight),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasStored
                                      ? (isIndo
                                            ? 'Kredensial saat ini terenkripsi & tersimpan di vault perangkat. Masukkan kunci baru di bawah hanya jika ingin memperbaruinya.'
                                            : 'Credential currently encrypted & stored in device vault. Enter a new key below only if you wish to overwrite it.')
                                      : (isIndo
                                            ? 'Belum ada kredensial tersimpan di vault. Tempel atau muat kunci Anda di bawah untuk mengaktifkan koneksi SSH.'
                                            : 'No credential stored in vault yet. Please paste or load your key below to enable SSH connection.'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.textPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Server Label
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: isIndo
                              ? 'Nama Pengenal Server'
                              : 'Server Friendly Name',
                          hintText: isIndo
                              ? 'cth. RumahWeb VPS (CethoKaryo)'
                              : 'e.g. RumahWeb VPS (CethoKaryo)',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? (isIndo ? 'Wajib diisi' : 'Required')
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Host & Port
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: hostCtrl,
                              decoration: InputDecoration(
                                labelText: isIndo
                                    ? 'IP Host atau Domain'
                                    : 'Host IP or Domain',
                                hintText: 'e.g. 202.10.46.4',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? (isIndo ? 'Wajib diisi' : 'Required')
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: portCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                hintText: '22',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? (isIndo ? 'Wajib diisi' : 'Required')
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Username
                      TextFormField(
                        controller: userCtrl,
                        decoration: InputDecoration(
                          labelText: isIndo ? 'Username SSH' : 'SSH Username',
                          hintText: 'e.g. cethokaryo or wito_general',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? (isIndo ? 'Wajib diisi' : 'Required')
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Authentication Type Selector
                      Text(
                        isIndo ? 'METODE AUTENTIKASI' : 'AUTHENTICATION METHOD',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(
                                () => authType = AuthType.privateKey,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: authType == AuthType.privateKey
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: isDark ? 0.15 : 0.1,
                                        )
                                      : (isDark
                                            ? AppColors.darkSurfaceElevated
                                            : AppColors.lightSurfaceElevated),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: authType == AuthType.privateKey
                                        ? theme.colorScheme.primary
                                        : (isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.vpn_key_rounded,
                                      size: 16,
                                      color: authType == AuthType.privateKey
                                          ? theme.colorScheme.primary
                                          : (isDark
                                                ? AppColors.textSecondary
                                                : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isIndo
                                          ? 'Kunci Privat (Key)'
                                          : 'Private Key',
                                      style: TextStyle(
                                        color: authType == AuthType.privateKey
                                            ? theme.colorScheme.primary
                                            : (isDark
                                                  ? AppColors.textSecondary
                                                  : AppColors
                                                        .lightTextSecondary),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => authType = AuthType.password),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: authType == AuthType.password
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: isDark ? 0.15 : 0.1,
                                        )
                                      : (isDark
                                            ? AppColors.darkSurfaceElevated
                                            : AppColors.lightSurfaceElevated),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: authType == AuthType.password
                                        ? theme.colorScheme.primary
                                        : (isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.password_rounded,
                                      size: 16,
                                      color: authType == AuthType.password
                                          ? theme.colorScheme.primary
                                          : (isDark
                                                ? AppColors.textSecondary
                                                : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        color: authType == AuthType.password
                                            ? theme.colorScheme.primary
                                            : (isDark
                                                  ? AppColors.textSecondary
                                                  : AppColors
                                                        .lightTextSecondary),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Browse & Load Local Private Key File
                      if (authType == AuthType.privateKey) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              try {
                                final files = await FilePicker.pickFiles(
                                  dialogTitle: isIndo
                                      ? 'Pilih Berkas Private Key (id_rsa, id_ed25519, pem)'
                                      : 'Select Private Key File (id_rsa, id_ed25519, pem)',
                                  type: FileType.any,
                                );
                                if (files.isNotEmpty) {
                                  final picked = files.first;
                                  final fileContent = await picked.xFile
                                      .readAsString();
                                  if (fileContent.trim().isNotEmpty) {
                                    credCtrl.text = fileContent.trim();
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isIndo
                                                ? '📂 Kunci privat berhasil dimuat dari ${picked.name}!'
                                                : '📂 Private key successfully loaded from ${picked.name}!',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                debugPrint('Load local key error: ');
                              }
                            },
                            icon: const Icon(
                              Icons.file_open_outlined,
                              size: 14,
                            ),
                            label: Text(
                              isIndo
                                  ? 'Muat dari file lokal'
                                  : 'Load from local',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],

                      // Credential Input Field
                      TextFormField(
                        controller: credCtrl,
                        maxLines: authType == AuthType.privateKey ? 5 : 1,
                        obscureText: authType == AuthType.password,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          labelText: authType == AuthType.privateKey
                              ? (hasStored
                                    ? (isIndo
                                          ? 'Kunci Privat Baru (Opsional - kosongkan jika tidak diubah)'
                                          : 'New Private Key (Optional - leave empty to keep)')
                                    : (isIndo
                                          ? 'Tempel Kunci Privat (PEM / OpenSSH)'
                                          : 'Paste Private Key (PEM / OpenSSH)'))
                              : (hasStored
                                    ? (isIndo
                                          ? 'Password Baru (Opsional - kosongkan jika tidak diubah)'
                                          : 'New Password (Optional - leave empty to keep)')
                                    : (isIndo
                                          ? 'Password SSH'
                                          : 'SSH Password')),
                          hintText: authType == AuthType.privateKey
                              ? '-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----'
                              : '••••••••',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) {
                          final val = v?.trim() ?? '';
                          if (!hasStored && val.isEmpty) {
                            return isIndo
                                ? 'Kredensial diperlukan untuk koneksi SSH'
                                : 'Credential required to establish SSH connection';
                          }
                          if (val.isNotEmpty &&
                              authType == AuthType.privateKey &&
                              !val.contains('PRIVATE KEY')) {
                            return isIndo
                                ? 'Harus berupa kunci privat OpenSSH/PEM yang valid'
                                : 'Must be a valid OpenSSH/PEM private key';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Encrypt & Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setState(() => isSaving = true);

                                  try {
                                    if (isEdit) {
                                      final updated = existingServer.copyWith(
                                        name: nameCtrl.text.trim(),
                                        host: hostCtrl.text.trim(),
                                        port: int.parse(portCtrl.text.trim()),
                                        username: userCtrl.text.trim(),
                                        authType: authType,
                                      );
                                      await serverProvider.updateServer(
                                        updated,
                                        credCtrl.text.trim().isNotEmpty
                                            ? credCtrl.text.trim()
                                            : null,
                                        null,
                                      );
                                    } else {
                                      await serverProvider.addServer(
                                        name: nameCtrl.text.trim(),
                                        host: hostCtrl.text.trim(),
                                        port: int.parse(portCtrl.text.trim()),
                                        username: userCtrl.text.trim(),
                                        authType: authType,
                                        credential: credCtrl.text.trim(),
                                        has2FA: false,
                                        twoFactorSecret: null,
                                      );
                                    }

                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isIndo
                                                ? '✅ Server "${nameCtrl.text}" berhasil disimpan & dienkripsi di vault!'
                                                : '✅ Server "${nameCtrl.text}" saved & encrypted in vault!',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isSaving = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isIndo ? 'Gagal: $e' : 'Failed: $e',
                                          ),
                                          backgroundColor: isDark
                                              ? AppColors.danger
                                              : AppColors.dangerLight,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.security_rounded),
                          label: Text(
                            isEdit
                                ? (isIndo
                                      ? 'PERBARUI & AMANKAN DI VAULT'
                                      : 'UPDATE & SECURE IN VAULT')
                                : (isIndo
                                      ? 'ENKRIPSI & SIMPAN KE VAULT'
                                      : 'ENCRYPT & SAVE TO VAULT'),
                          ),
                        ),
                      ),
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

  void _confirmDelete(BuildContext context, ServerProfile server) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIndo = context.read<SettingsProvider>().isIndonesian;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIndo ? 'Hapus Server?' : 'Remove Server?'),
        content: Text(
          isIndo
              ? 'Apakah Anda yakin ingin menghapus "${server.name}"? Kredensial terenkripsi akan dihapus permanen dari vault perangkat.'
              : 'Are you sure you want to remove "${server.name}"? Encrypted credentials will be securely wiped from the device vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isIndo ? 'BATAL' : 'CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.danger
                  : AppColors.dangerLight,
            ),
            onPressed: () {
              final serverProvider = context.read<ServerProvider>();
              final telemetry = context.read<TelemetryProvider>();
              serverProvider.deleteServer(server.id);
              telemetry.clearEventsForServer(server.id);
              if (serverProvider.servers.isEmpty) {
                telemetry.clearAll();
              }
              Navigator.of(ctx).pop();
            },
            child: Text(isIndo ? 'HAPUS' : 'DELETE'),
          ),
        ],
      ),
    );
  }

  void _confirmRebootServer(BuildContext context, ServerProfile server) async {
    final settings = context.read<SettingsProvider>();
    final serverProvider = context.read<ServerProvider>();
    final isIndo = settings.isIndonesian;

    final savedSudo = await serverProvider.getSavedSudoPassword(server.id);
    final sudoCtrl = TextEditingController(text: savedSudo ?? '');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.restart_alt_rounded,
                color: AppColors.danger,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isIndo ? 'Restart Host Server?' : 'Reboot Server Host?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                isIndo
                    ? 'PERINGATAN: Perintah reboot sistem akan merestart mesin fisik/VPS ${server.name} (${server.host}). Seluruh layanan (MySQL, SSH, Web, dll.) dan koneksi aktif akan terputus selama proses reboot.'
                    : 'WARNING: The system reboot signal will restart the host ${server.name} (${server.host}). All daemon services (MySQL, SSH, Web, etc.) and active client sessions will drop.',
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: sudoCtrl,
              obscureText: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                labelText: isIndo
                    ? 'Kata Sandi Sudo (opsional jika root)'
                    : 'Sudo Password (optional if root)',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isIndo ? 'BATAL' : 'CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();

              if (settings.biometricLock) {
                final authOk = await BiometricService().authenticate(
                  context: context,
                  reason: isIndo
                      ? 'Otorisasi biometrik untuk merestart server ${server.name}'
                      : 'Biometric authorization required to reboot server ${server.name}',
                );
                if (!authOk) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isIndo
                              ? 'Autentikasi biometrik dibatalkan.'
                              : 'Biometric verification cancelled.',
                        ),
                      ),
                    );
                  }
                  return;
                }
              }

              final enteredSudo = sudoCtrl.text.trim();
              if (enteredSudo.isNotEmpty) {
                await serverProvider.saveSudoPassword(server.id, enteredSudo);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isIndo
                          ? 'Mengirim sinyal reboot ke ${server.name} (${server.host})...'
                          : 'Sending reboot signal to ${server.name} (${server.host})...',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }

              final res = await serverProvider.rebootServer(
                serverId: server.id,
                sudoPassword: enteredSudo.isNotEmpty ? enteredSudo : null,
                onPrompt2FA: (prompt) => TwoFactorAuthDialog.show(
                  context,
                  username: server.username,
                  serverName: server.name,
                  promptText: prompt,
                ),
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res.success
                          ? (isIndo
                                ? '✅ Sinyal restart berhasil dikirim ke ${server.name}!'
                                : '✅ Reboot signal dispatched to ${server.name}!')
                          : (isIndo
                                ? '❌ Gagal merestart: ${res.errorMessage}'
                                : '❌ Reboot failed: ${res.errorMessage}'),
                    ),
                    backgroundColor: res.success
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                );
              }
            },
            child: Text(isIndo ? 'RESTART SERVER' : 'REBOOT SERVER'),
          ),
        ],
      ),
    );
  }
}
