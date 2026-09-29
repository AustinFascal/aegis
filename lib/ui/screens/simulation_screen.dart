import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/server_profile.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/penetration_test_card.dart';
import 'audit_explorer_screen.dart';
import 'faq_screen.dart';

class SimulationScreen extends StatelessWidget {
  final ServerProfile? server;

  const SimulationScreen({super.key, this.server});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    final serverProvider = context.watch<ServerProvider>();
    final activeServer = server ?? serverProvider.activeServer;

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        title: Text(
          isIndo
              ? 'SIMULASI SIBER & PENETRATION TEST'
              : 'CYBER SIMULATION & PENTEST',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted_rounded),
            tooltip: isIndo ? 'Buka Log Audit' : 'Open Audit Log',
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

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 16,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Server Banner
                    if (activeServer != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.danger.withValues(
                              alpha: isDark ? 0.35 : 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(
                                  alpha: isDark ? 0.15 : 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.security_rounded,
                                color: AppColors.danger,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isIndo
                                        ? 'NODE TARGET SIMULASI KEAMANAN'
                                        : 'SECURITY SIMULATION TARGET NODE',
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${activeServer.name} (${activeServer.host}:${activeServer.port})',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.danger.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                isIndo ? 'LAB AKTIF' : 'LAB ACTIVE',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Context description
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: isDark ? 0.25 : 0.15,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isIndo
                                  ? 'Laboratorium ini menyimulasikan vektor serangan nyata (Brute Force SSH, Port Scanning, SQL Injection, dan Probing Anomali) untuk menguji respons deteksi Aegis, penentuan skor risiko, serta otomatisasi blokir IP firewall.'
                                  : 'This adversary lab simulates real-world attack vectors (SSH Brute Force, Port Scanning, SQL Injection, and Anomaly Probing) to stress-test Aegis real-time intrusion alarms, risk scoring heuristics, and automated firewall banning rules.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Interactive Penetration Test Card
                    const PenetrationTestCard(),
                    const SizedBox(height: 24),

                    // Link to Audit Explorer to review aftermath
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(
                                alpha: isDark ? 0.15 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.format_list_bulleted_rounded,
                              color: AppColors.warning,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isIndo
                                      ? 'Verifikasi Alarm di Log Audit Forensik'
                                      : 'Verify Alarms in Forensic Audit Log',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isIndo
                                      ? 'Lihat bagaimana insiden hasil simulasi tercatat dalam timeline forensik SIEM.'
                                      : 'Examine how simulated incident payloads were ingested into the SIEM timeline.',
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
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning.withValues(
                                alpha: isDark ? 0.18 : 0.12,
                              ),
                              foregroundColor: AppColors.warning,
                              side: BorderSide(
                                color: AppColors.warning.withValues(alpha: 0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuditExplorerScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isIndo ? 'Buka Log' : 'Open Log',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
