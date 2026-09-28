import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/server_profile.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../screens/compliance_screen.dart';

class ComplianceScannerCard extends StatelessWidget {
  final ServerProfile? server;

  const ComplianceScannerCard({
    super.key,
    this.server,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    final serverProvider = context.watch<ServerProvider>();
    final targetServer = server ?? serverProvider.activeServer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIndo ? 'HARDENING SISTEM & KEPATUHAN' : 'SYSTEM HARDENING & COMPLIANCE',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isIndo
                          ? 'Audit keamanan berbasis standar CIS Benchmark & OpenSSH'
                          : 'Security baseline audits based on CIS Benchmark & OpenSSH standards',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Standard badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge('CIS Linux Level 1 & 2', AppColors.primary, isDark),
              _buildBadge('OpenSSH 5.2 Hardening', AppColors.purple, isDark),
              _buildBadge('Kernel Sysctl ASLR/SYN', AppColors.success, isDark),
              _buildBadge('NIST SP 800-53', AppColors.info, isDark),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            isIndo
                ? 'Pindai otomatis 17 parameter hardening meliputi larangan login root, autentikasi kunci publik, proteksi memori kernel ASLR, TCP SYN cookies, izin ketat /etc/shadow, dan isolasi antarmuka database.'
                : 'Automated 17-point hardening audit covering root login bans, public-key authentication, kernel ASLR memory protection, TCP SYN cookies, strict /etc/shadow perms, and database socket isolation.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.primaryLight.withValues(alpha: 0.15),
                foregroundColor: isDark
                    ? AppColors.primary
                    : AppColors.primaryLight,
                side: BorderSide(
                  color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.5),
                  width: 1.1,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComplianceScreen(server: targetServer),
                  ),
                );
              },
              icon: const Icon(Icons.shield_rounded, size: 18),
              label: Text(
                isIndo ? 'BUKA PEMINDAI KEPATUHAN' : 'OPEN COMPLIANCE SCANNER',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
