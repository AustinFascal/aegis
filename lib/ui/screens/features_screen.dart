import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/server_profile.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import 'terminal_screen.dart';
import 'sftp_screen.dart';
import 'compliance_screen.dart';
import 'simulation_screen.dart';
import 'audit_explorer_screen.dart';
import 'server_management_screen.dart';
import 'faq_screen.dart';

enum FeatureCategory { all, access, defense, adversary }

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  FeatureCategory _selectedCategory = FeatureCategory.all;

  void _showNoServerNotice(BuildContext context, bool isIndo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.warning,
        content: Text(
          isIndo
              ? '⚠️ Silakan hubungkan atau pilih server terlebih dahulu.'
              : '⚠️ Please connect or select an active server first.',
        ),
      ),
    );
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

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        title: Text(
          isIndo ? 'FITUR & ALAT KEAMANAN' : 'SECURITY SUITE & FEATURES',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted_rounded),
            tooltip: isIndo ? 'Buka Log Audit Forensik' : 'Open Forensic Audit Log',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AuditExplorerScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: isIndo ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const FaqScreen(initialCategory: FaqCategory.security),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 16,
              vertical: 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Target Node Banner
                    _buildActiveNodeBanner(
                      context: context,
                      server: activeServer,
                      serverProvider: serverProvider,
                      isDark: isDark,
                      isIndo: isIndo,
                      theme: theme,
                    ),
                    const SizedBox(height: 18),

                    // Filter category chips
                    _buildCategoryChips(
                      isDark: isDark,
                      isIndo: isIndo,
                      theme: theme,
                    ),
                    const SizedBox(height: 20),

                    // Feature Cards Grid / Column
                    _buildFeatureCards(
                      context: context,
                      activeServer: activeServer,
                      isWide: isWide,
                      isDark: isDark,
                      isIndo: isIndo,
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveNodeBanner({
    required BuildContext context,
    required ServerProfile? server,
    required ServerProvider serverProvider,
    required bool isDark,
    required bool isIndo,
    required ThemeData theme,
  }) {
    final isConnected = server != null && serverProvider.isServerConnected(server.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected
              ? (isDark ? AppColors.success : AppColors.successLight).withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isConnected ? AppColors.success : AppColors.primary)
                  .withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              server != null ? Icons.dns_rounded : Icons.dns_outlined,
              color: isConnected ? AppColors.success : theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      isIndo ? 'SERVER AKTIF' : 'ACTIVE TARGET NODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isConnected ? AppColors.success : AppColors.warning)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isConnected
                            ? (isIndo ? 'TERHUBUNG' : 'CONNECTED')
                            : (server != null
                                ? (isIndo ? 'SIAP' : 'STANDBY')
                                : (isIndo ? 'BELUM ADA' : 'NO SERVER')),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isConnected ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  server != null
                      ? '${server.name} (${server.host}:${server.port})'
                      : (isIndo
                          ? 'Belum ada server dipilih.'
                          : 'No server selected.'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ServerManagementScreen.showServerDialog(context);
            },
            child: Text(
              isIndo ? 'Ganti' : 'Switch',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips({
    required bool isDark,
    required bool isIndo,
    required ThemeData theme,
  }) {
    final chips = [
      {'cat': FeatureCategory.all, 'label': isIndo ? 'SEMUA FITUR' : 'ALL FEATURES'},
      {'cat': FeatureCategory.access, 'label': isIndo ? 'AKSES & TRANSFER' : 'ACCESS & TRANSFER'},
      {'cat': FeatureCategory.defense, 'label': isIndo ? 'AUDIT & HARDENING' : 'AUDIT & HARDENING'},
      {'cat': FeatureCategory.adversary, 'label': isIndo ? 'SIMULASI PENETRASI' : 'SIMULATION & PENTEST'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) {
          final cat = c['cat'] as FeatureCategory;
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c['label'] as String),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
              ),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatureCards({
    required BuildContext context,
    required ServerProfile? activeServer,
    required bool isWide,
    required bool isDark,
    required bool isIndo,
    required ThemeData theme,
  }) {
    final List<Widget> cards = [];

    // 1. SSH Interactive Terminal
    if (_selectedCategory == FeatureCategory.all || _selectedCategory == FeatureCategory.access) {
      cards.add(
        _FeatureCardItem(
          accentColor: AppColors.primary,
          icon: Icons.terminal_rounded,
          badge: 'SSH SHELL',
          title: isIndo ? 'Terminal SSH Interaktif' : 'Interactive SSH Terminal',
          description: isIndo
              ? 'Konsol shell interaktif langsung dengan dukungan multi-tema (Cyber OLED, Matrix, Monokai), keystroke cepat, dan sesi terenkripsi penuh.'
              : 'Direct interactive shell console with multi-theme support (Cyber OLED, Matrix, Monokai), quick DevOps shortcuts, and fully encrypted sessions.',
          tags: const ['XTerm v5', 'PTY Session', '4 Themes', 'Direct Exec'],
          actionLabel: isIndo ? 'BUKA TERMINAL' : 'LAUNCH TERMINAL',
          onAction: () {
            if (activeServer == null) {
              _showNoServerNotice(context, isIndo);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TerminalScreen(server: activeServer),
              ),
            );
          },
        ),
      );
    }

    // 2. SFTP Remote File Manager
    if (_selectedCategory == FeatureCategory.all || _selectedCategory == FeatureCategory.access) {
      cards.add(
        _FeatureCardItem(
          accentColor: AppColors.purple,
          icon: Icons.folder_shared_rounded,
          badge: 'SFTP CLIENT',
          title: isIndo ? 'Manajer Berkas SFTP Jarak Jauh' : 'SFTP Remote File Manager',
          description: isIndo
              ? 'Eksplorasi hierarki direktori server Linux, unggah dan unduh berkas, periksa izin hak akses (chmod), serta audit konfigurasi layanan.'
              : 'Browse Linux server directory trees, upload and download files, inspect permission bits (chmod), and audit system service configs.',
          tags: ['SFTP Subsystem', 'Upload/Download', 'Permission Audit', 'Multi-Sort'],
          actionLabel: isIndo ? 'BUKA SFTP' : 'LAUNCH SFTP',
          onAction: () {
            if (activeServer == null) {
              _showNoServerNotice(context, isIndo);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SftpScreen(server: activeServer),
              ),
            );
          },
        ),
      );
    }

    // 3. System Hardening & CIS Compliance
    if (_selectedCategory == FeatureCategory.all || _selectedCategory == FeatureCategory.defense) {
      cards.add(
        _FeatureCardItem(
          accentColor: AppColors.success,
          icon: Icons.verified_user_rounded,
          badge: 'CIS BENCHMARK',
          title: isIndo ? 'Hardening Sistem & Kepatuhan CIS' : 'System Hardening & CIS Compliance',
          description: isIndo
              ? 'Pemeriksaan kepatuhan standar CIS Linux Level 1 & 2, audit konfigurasi SSH/sysctl, serta pembuatan otomatis skrip playbook remediasi.'
              : 'CIS Linux Level 1 & 2 security benchmark auditing, SSH/sysctl posture scoring, and automated remediation playbook generation.',
          tags: ['CIS Level 1 & 2', 'NIST 800-53', '45+ Checks', 'Playbook Export'],
          actionLabel: isIndo ? 'AUDIT & HARDENING' : 'RUN HARDENING AUDIT',
          onAction: () {
            if (activeServer == null) {
              _showNoServerNotice(context, isIndo);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ComplianceScreen(server: activeServer),
              ),
            );
          },
        ),
      );
    }

    // 4. Cyber Simulation & Penetration Testing
    if (_selectedCategory == FeatureCategory.all || _selectedCategory == FeatureCategory.adversary) {
      cards.add(
        _FeatureCardItem(
          accentColor: AppColors.danger,
          icon: Icons.security_rounded,
          badge: 'ADVERSARY LAB',
          title: isIndo ? 'Simulasi Siber & Uji Penetrasi' : 'Cyber Simulation & Penetration Test',
          description: isIndo
              ? 'Laboratorium pengujian serangan siber terkontrol (Brute Force SSH, Port Flood, SQLi, Payload anomali) untuk menguji respons alarm real-time Aegis.'
              : 'Controlled adversary simulation lab (SSH Brute Force, Port Flood, SQLi, Anomaly Probing) to stress-test Aegis real-time intrusion alarms.',
          tags: ['4 Attack Scenarios', 'Origin Spoofing', 'Realtime Terminal', 'SIEM Ingestion'],
          actionLabel: isIndo ? 'BUKA LAB SIMULASI' : 'OPEN SIMULATION LAB',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SimulationScreen(server: activeServer),
              ),
            );
          },
        ),
      );
    }

    // 5. Forensic Audit Explorer (SIEM)
    if (_selectedCategory == FeatureCategory.all || _selectedCategory == FeatureCategory.defense) {
      cards.add(
        _FeatureCardItem(
          accentColor: AppColors.warning,
          icon: Icons.format_list_bulleted_rounded,
          badge: 'SIEM & AUDIT',
          title: isIndo ? 'Penjelajah Forensik & Log Audit' : 'Forensic Explorer & Audit Log',
          description: isIndo
              ? 'Pusat timeline forensik komprehensif seluruh sistem: streaming log real-time, pencarian IP multi-vektor, korelasi ancaman, dan mitigasi firewall satu-klik.'
              : 'System-wide comprehensive forensic timeline: live event streaming, multi-vector IP search, threat correlation, and one-click firewall bans.',
          tags: ['Live Stream', 'Global Filters', 'Threat Intel', 'One-Click Ban'],
          actionLabel: isIndo ? 'JELAJAHI LOG AUDIT' : 'EXPLORE AUDIT LOGS',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuditExplorerScreen(),
              ),
            );
          },
        ),
      );
    }

    if (isWide) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards.map((card) {
          return SizedBox(
            width: (constraintsWidth(context) - 64 - 16) / 2 > 380
                ? (constraintsWidth(context) - 64 - 16) / 2
                : 380,
            child: card,
          );
        }).toList(),
      );
    }

    return Column(
      children: cards
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: c,
              ))
          .toList(),
    );
  }

  double constraintsWidth(BuildContext context) {
    return MediaQuery.of(context).size.width.clamp(320.0, 1200.0);
  }
}

class _FeatureCardItem extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String badge;
  final String title;
  final String description;
  final List<String> tags;
  final String actionLabel;
  final VoidCallback onAction;

  const _FeatureCardItem({
    required this.accentColor,
    required this.icon,
    required this.badge,
    required this.title,
    required this.description,
    required this.tags,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with Icon and Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: isDark ? 0.4 : 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Capability Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      foregroundColor: accentColor,
                      elevation: 0,
                      side: BorderSide(
                        color: accentColor.withValues(alpha: isDark ? 0.5 : 0.35),
                        width: 1.1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
