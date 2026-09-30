import 'dart:io';
import '../../core/security/secure_vault.dart';
import '../../providers/server_provider.dart';
import '../../providers/policy_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../services/app_restart_service.dart';
import 'onboarding_screen.dart';
import '../../core/security/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';
import 'package:flutter/services.dart';
import '../../services/notification_service.dart';
import '../../providers/theme_provider.dart';
import 'faq_screen.dart';
import 'pin_auth_screen.dart';
import '../widgets/aegis_logo.dart';
import '../../services/threat_intel_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
        title: Text(settings.t('settings_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: settings.isIndonesian ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: theme.colorScheme.primary,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 16,
                  vertical: 20,
                ),
                children: [
                  // 1. Security Operator Profile Card
                  _buildProfileCard(context, settings, isDark),
                  const SizedBox(height: 24),

                  // 2. Appearance & Theme Section
                  _buildSectionHeader(context, settings.t('appearance_heading'), isDark),
                  const SizedBox(height: 10),
                  _buildThemeSection(context, themeProvider, isDark),
                  const SizedBox(height: 24),

                  // 3. Language & Localization Section
                  _buildSectionHeader(context, settings.t('language_heading'), isDark),
                  const SizedBox(height: 10),
                  _buildLanguageSection(context, settings, isDark),
                  const SizedBox(height: 24),

                  // 4. Biometric Security Controls
                  _buildSectionHeader(
                    context,
                    settings.isIndonesian
                        ? 'KEAMANAN & AUTENTIKASI BIOMETRIK'
                        : 'SECURITY & BIOMETRIC AUTHENTICATION',
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildBiometricSection(context, settings, isDark),
                  const SizedBox(height: 24),

                  // 5. Polling & Monitoring Controls
                  _buildSectionHeader(context, settings.isIndonesian ? 'TELEMETRI & PEMANTAUAN' : 'TELEMETRY & POLLING CONTROLS', isDark),
                  const SizedBox(height: 10),
                  _buildTelemetryControls(context, settings, isDark),
                  const SizedBox(height: 24),

                  // 6. Threat Intelligence & External Integrations
                  _buildSectionHeader(
                    context,
                    settings.t('threat_intel_heading'),
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildThreatIntelSection(context, settings, isDark),
                  const SizedBox(height: 24),

                  // 7. Legal, Privacy & Compliance Links
                  _buildSectionHeader(context, settings.t('legal_heading'), isDark),
                  const SizedBox(height: 10),
                  _buildLegalSection(context, settings, isDark),
                  const SizedBox(height: 24),

                  // 8. Zona Bahaya & Reset Sistem
                  _buildSectionHeader(
                    context,
                    settings.isIndonesian ? 'ZONA BAHAYA & RESET SISTEM' : 'DANGER ZONE & SYSTEM RESET',
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDangerZoneSection(context, settings, isDark),
                  const SizedBox(height: 24),

                  // 9. Security Architecture & Version Footer
                  _buildSystemFooter(context, settings, isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, SettingsProvider settings, bool isDark) {
    final theme = Theme.of(context);
    final isGuest = settings.isGuest;
    final isIndo = settings.isIndonesian;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (isGuest ? AppColors.warning : theme.colorScheme.primary)
              .withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Operator Security Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: (isGuest ? AppColors.warning : theme.colorScheme.primary)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isGuest ? AppColors.warning : theme.colorScheme.primary)
                          .withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(settings.operatorName),
                      style: TextStyle(
                        color: isGuest ? AppColors.warning : theme.colorScheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            settings.operatorName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isGuest ? AppColors.warning : AppColors.success)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isGuest ? AppColors.warning : AppColors.success)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              isGuest
                                  ? 'GUEST OPERATOR'
                                  : (isIndo ? 'VERIFIED GUARDIAN' : 'VERIFIED GUARDIAN'),
                              style: TextStyle(
                                color: isGuest ? AppColors.warning : AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Email with icon
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 13,
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              settings.operatorEmail.isNotEmpty
                                  ? settings.operatorEmail
                                  : (isIndo ? 'Email belum diatur' : 'Email not configured'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Phone with icon
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              settings.operatorPhone.isNotEmpty
                                  ? settings.operatorPhone
                                  : (isIndo ? 'Telepon belum diatur' : 'Phone not configured'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Profile Metadata Badges (Tenant & Hardware Fingerprint - Role & Clearance Level Removed)
            // Wrap(
            //   spacing: 12,
            //   runSpacing: 8,
            //   children: [
            //     _buildMetaPill(
            //       context,
            //       Icons.business_rounded,
            //       settings.operatorTenant,
            //       isDark,
            //     ),
            //     _buildMetaPill(
            //       context,
            //       Icons.fingerprint_rounded,
            //       settings.hardwareFingerprint,
            //       isDark,
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 16),

            // Profile Actions (Edit Profile + Logout if not guest)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (!isGuest) ...[
                  OutlinedButton.icon(
                    onPressed: () => _showLogoutConfirmDialog(context, settings),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: Text(isIndo ? 'KELUAR AKUN' : 'LOGOUT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.danger : AppColors.dangerLight,
                      side: BorderSide(
                        color: (isDark ? AppColors.danger : AppColors.dangerLight).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: () => _showEditProfileDialog(context, settings),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(
                    isGuest
                        ? (isIndo ? 'SETUP PROFIL' : 'SETUP PROFILE')
                        : (isIndo ? 'UBAH PROFIL' : 'EDIT OPERATOR PROFILE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMetaPill(
    BuildContext context,
    IconData icon,
    String label,
    bool isDark, {
    Color? color,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color ?? (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, ThemeProvider themeProvider, bool isDark) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildThemeOption(
                    context: context,
                    title: 'Cyber Dark',
                    subtitle: 'Deep OLED / High-Contrast Cyan',
                    icon: Icons.dark_mode_rounded,
                    isSelected: isDark,
                    onTap: () {
                      if (!isDark) themeProvider.toggleTheme();
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThemeOption(
                    context: context,
                    title: 'Cyber Light',
                    subtitle: 'Clean Corporate Slate',
                    icon: Icons.light_mode_rounded,
                    isSelected: !isDark,
                    onTap: () {
                      if (isDark) themeProvider.toggleTheme();
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1)
              : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isSelected ? theme.colorScheme.primary : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                  size: 22,
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection(BuildContext context, SettingsProvider settings, bool isDark) {

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildLangOption(
                context: context,
                code: 'en',
                flag: '🇺🇸',
                title: 'English (US)',
                subtitle: 'Standard International',
                isSelected: settings.language == 'en',
                onTap: () => settings.setLanguage('en'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLangOption(
                context: context,
                code: 'id',
                flag: '🇮🇩',
                title: 'Bahasa Indonesia',
                subtitle: 'Terjemahan Lengkap',
                isSelected: settings.language == 'id',
                onTap: () => settings.setLanguage('id'),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangOption({
    required BuildContext context,
    required String code,
    required String flag,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1)
              : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(flag, style: const TextStyle(fontSize: 22)),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricSection(BuildContext context, SettingsProvider settings, bool isDark) {
    final theme = Theme.of(context);
    final isIndo = settings.isIndonesian;

    return FutureBuilder<bool>(
      future: BiometricService().isBiometricsAvailable(),
      builder: (context, snapshot) {
        final isAvailable = snapshot.data ?? false;
        final lockActive = settings.isSecurityLockActive;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (lockActive ? AppColors.success : theme.colorScheme.primary)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isAvailable ? Icons.fingerprint_rounded : Icons.pin_rounded,
                        color: lockActive ? AppColors.success : theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAvailable
                                ? (isIndo ? 'Kunci Biometrik & PIN' : 'Biometric & PIN Lock')
                                : (isIndo ? 'Kunci PIN Keamanan Konsol' : 'Console Security PIN Lock'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAvailable
                                ? (isIndo
                                    ? 'Wajibkan verifikasi sidik jari atau PIN saat membuka aplikasi dan aksi sensitif.'
                                    : 'Require fingerprint or PIN verification when opening app and for sensitive actions.')
                                : (isIndo
                                    ? 'Wajibkan verifikasi PIN 6-digit saat membuka aplikasi dan aksi sensitif.'
                                    : 'Require 6-digit PIN verification when opening app and for sensitive actions.'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: lockActive,
                      activeTrackColor: theme.colorScheme.primary,
                      onChanged: (val) async {
                        if (val) {
                          // If biometric is not available or user has no PIN yet, directly setup PIN!
                          if (!settings.hasPin) {
                            final pinCreated = await PinAuthScreen.setup(context);
                            if (pinCreated) {
                              await settings.setBiometricLock(true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isIndo
                                          ? '✅ Kunci keamanan PIN berhasil diaktifkan!'
                                          : '✅ Security PIN lock enabled!',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            }
                          } else {
                            await settings.setBiometricLock(true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isIndo
                                        ? '✅ Proteksi keamanan berhasil diaktifkan!'
                                        : '✅ Security protection enabled!',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          }
                        } else {
                          final ok = await BiometricService().authenticate(
                            context: context,
                            reason: isIndo
                                ? 'Verifikasi untuk menonaktifkan proteksi'
                                : 'Authenticate to disable security lock',
                          );
                          if (ok) {
                            await settings.setBiometricLock(false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isIndo
                                        ? 'Kunci keamanan dinonaktifkan.'
                                        : 'Security lock disabled.',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // PIN Setup / Change Tile
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    await PinAuthScreen.setup(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (settings.hasPin ? AppColors.success : theme.colorScheme.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.pin_outlined,
                            size: 18,
                            color: settings.hasPin ? AppColors.success : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isIndo ? 'PIN Keamanan Konsol (6 Digit)' : 'Console Security PIN (6 Digits)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settings.hasPin
                                    ? (isIndo ? 'PIN 6-digit aktif • Ketuk untuk ganti PIN' : '6-digit PIN active • Tap to change PIN')
                                    : (isIndo ? 'Belum diatur • Ketuk untuk membuat PIN' : 'Not set • Tap to create PIN'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: settings.hasPin
                                      ? AppColors.success
                                      : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                                  fontWeight: settings.hasPin ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Device Capability Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: (isAvailable ? AppColors.success : AppColors.info)
                        .withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isAvailable ? AppColors.success : AppColors.info)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                        size: 14,
                        color: isAvailable ? AppColors.success : AppColors.info,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAvailable
                              ? (isIndo
                                  ? 'Sensor sidik jari aktif. PIN juga dapat digunakan sebagai alternatif.'
                                  : 'Biometric sensor active & enrolled. PIN can be used as an alternative.')
                              : (isIndo
                                  ? 'Sensor sidik jari tidak terdeteksi. Autentikasi konsol menggunakan PIN 6-digit.'
                                  : 'Fingerprint reader not detected. Console authentication uses 6-digit PIN.'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isAvailable ? AppColors.success : AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryControls(BuildContext context, SettingsProvider settings, bool isDark) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Polling interval selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      settings.t('polling_rate'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      settings.isIndonesian
                          ? 'Frekuensi refresh otomatis untuk status server'
                          : 'Rate of background health probes',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: settings.autoPollingInterval,
                  dropdownColor: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15s (Fast)')),
                    DropdownMenuItem(value: 30, child: Text('30s (Default)')),
                    DropdownMenuItem(value: 60, child: Text('60s (Balanced)')),
                    DropdownMenuItem(value: 300, child: Text('5 min (Low Net)')),
                    DropdownMenuItem(value: 0, child: Text('Manual only')),
                  ],
                  onChanged: (val) {
                    if (val != null) settings.setAutoPollingInterval(val);
                  },
                ),
              ],
            ),
            const Divider(height: 24),

            // Sound alerts toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                settings.isIndonesian ? 'Peringatan Audio Serangan Kritis' : 'Critical Threat Audio Alerts',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                settings.isIndonesian
                    ? 'Bunyikan sinyal saat brute-force atau unknown login terdeteksi'
                    : 'Audible chime upon brute force or untrusted login',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                ),
              ),
              value: settings.soundAlerts,
              activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.5),
              onChanged: (v) => settings.setSoundAlerts(v),
            ),
            const Divider(height: 24),

            // Background FCM Sentinel Push Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 18,
                        color: isDark ? AppColors.primary : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          settings.isIndonesian
                              ? 'Notifikasi Latar Belakang (FCM Push)'
                              : 'Background Push Alerts (FCM)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          settings.isIndonesian ? 'AKTIF 24/7' : '24/7 ACTIVE',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    settings.isIndonesian
                        ? 'Memungkinkan penerimaan alarm instan saat serangan terdeteksi bahkan saat layar HP mati atau aplikasi ditutup (0% boros baterai).'
                        : 'Enables instant alerts for security incursions even when phone is locked or app is closed with zero battery drain.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          await NotificationService().sendTestAlert();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  settings.isIndonesian
                                      ? '🚨 Mengirim notifikasi alarm uji coba ke baki Android!'
                                      : '🚨 Triggered test alert notification to Android tray!',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: Text(
                          settings.isIndonesian ? 'UJI NOTIFIKASI ALARM' : 'TEST ALERT PUSH',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          final token = NotificationService().fcmToken ??
                              'FCM-DEVICE-TOKEN-AEGIS-SENTINEL-9A7F';
                          Clipboard.setData(ClipboardData(text: token));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                settings.isIndonesian
                                    ? '📋 Token FCM perangkat disalin ke clipboard!'
                                    : '📋 FCM device token copied to clipboard!',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: Text(
                          settings.isIndonesian ? 'SALIN TOKEN FCM' : 'COPY FCM TOKEN',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreatIntelSection(BuildContext context, SettingsProvider settings, bool isDark) {
    final theme = Theme.of(context);
    final isIndo = settings.isIndonesian;
    final isConfigured = settings.hasAbuseIpDbApiKey;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isConfigured
              ? (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isConfigured ? AppColors.success : (isDark ? AppColors.primary : AppColors.primaryLight))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.radar_rounded,
                    color: isConfigured ? AppColors.success : (isDark ? AppColors.primary : AppColors.primaryLight),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'AbuseIPDB Global Intelligence',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isConfigured ? AppColors.success : AppColors.warning)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: (isConfigured ? AppColors.success : AppColors.warning)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              isConfigured
                                  ? (isIndo ? 'TERHUBUNG (LIVE)' : 'CONNECTED (LIVE)')
                                  : (isIndo ? 'MODE EVALUASI' : 'DEMO MODE'),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isConfigured ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isIndo
                            ? 'Deteksi otomatis skor bahaya IP penyerang, laporan komunitas siber global, dan node Tor saat investigasi forensik.'
                            : 'Auto-detect attacker IP abuse scores, global cyber reports, and Tor exit nodes during forensic investigation.',
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

            // Key status banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isConfigured ? AppColors.success : AppColors.warning)
                    .withValues(alpha: isDark ? 0.08 : 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isConfigured ? AppColors.success : AppColors.warning)
                      .withValues(alpha: isDark ? 0.25 : 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConfigured ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                    color: isConfigured ? AppColors.success : AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConfigured
                              ? (isIndo
                                  ? 'API Key terenkripsi AES-256 di Secure Vault lokal.'
                                  : 'API key encrypted with AES-256 in local Secure Vault.')
                              : (isIndo
                                  ? 'Menggunakan simulasi ancaman bawaan (Gratis 1.000 cek/hari tersedia).'
                                  : 'Using simulated intelligence (Free 1,000 checks/day available).'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (isConfigured && settings.abuseIpDbApiKey != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Key: ${_maskKey(settings.abuseIpDbApiKey!)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showApiKeyDialog(context, settings),
                  icon: const Icon(Icons.vpn_key_rounded, size: 14),
                  label: Text(
                    isConfigured
                        ? (isIndo ? 'UBAH API KEY' : 'UPDATE API KEY')
                        : (isIndo ? 'PASANG API KEY' : 'CONFIGURE API KEY'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'https://www.abuseipdb.com/register'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isIndo
                              ? '📋 URL registrasi AbuseIPDB disalin ke clipboard!'
                              : '📋 AbuseIPDB registration URL copied to clipboard!',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    isIndo ? 'DAFTAR GRATIS (1.000/HARI)' : 'FREE KEY (1,000/DAY)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                if (isConfigured)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            isIndo
                                ? 'Memverifikasi koneksi API AbuseIPDB...'
                                : 'Testing AbuseIPDB API connection...',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      final ok = await ThreatIntelService().verifyApiKey(settings.abuseIpDbApiKey!);
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? (isIndo
                                      ? '✅ Koneksi API AbuseIPDB sukses! Kuota aktif.'
                                      : '✅ AbuseIPDB API connection successful! Quota active.')
                                  : (isIndo
                                      ? '⚠️ Gagal terhubung ke AbuseIPDB. Periksa koneksi atau key.'
                                      : '⚠️ Failed to connect to AbuseIPDB. Check key or network.'),
                            ),
                            backgroundColor: ok ? AppColors.success : (isDark ? AppColors.danger : AppColors.dangerLight),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 14),
                    label: Text(
                      isIndo ? 'TES KONEKSI' : 'TEST CONNECTION',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _maskKey(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••••••${key.substring(key.length - 4)}';
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
                        return;
                      }

                      setDialogState(() => isVerifying = true);
                      final isValid = await ThreatIntelService().verifyApiKey(inputKey);
                      setDialogState(() => isVerifying = false);

                      if (isValid) {
                        await settings.setAbuseIpDbApiKey(inputKey);
                        if (ctx.mounted) Navigator.pop(dialogCtx);
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

  Widget _buildLegalSection(BuildContext context, SettingsProvider settings, bool isDark) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          // App Walkthrough & Tour Replay Tile
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.slideshow_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            title: Text(
              settings.isIndonesian ? 'Panduan & Walkthrough Aplikasi' : 'App Walkthrough & Tour',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              settings.isIndonesian
                  ? 'Buka kembali pengenalan fitur & panduan awal sistem AEGIS'
                  : 'Replay feature walkthrough & introductory sentinel tour',
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen(isReplay: true)),
              );
            },
          ),
          const Divider(height: 1),
          // Help Center & FAQ Tile
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.help_outline_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            title: Text(
              settings.isIndonesian ? 'Pusat Bantuan & FAQ Teknis' : 'Help Center & Technical FAQ',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              settings.isIndonesian
                  ? 'Panduan parameter keamanan, jendela waktu geser, fail2ban, dan server daemon'
                  : 'Guide to sliding windows, failed login thresholds, fail2ban, and server agent',
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqScreen()),
              );
            },
          ),
          const Divider(height: 1),
          // Privacy Policy Tile
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.privacy_tip_outlined, color: theme.colorScheme.primary, size: 20),
            ),
            title: Text(
              settings.t('privacy_policy_title'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              settings.t('privacy_policy_sub'),
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _showPrivacyPolicyDialog(context, settings),
          ),
          const Divider(height: 1),

          // Terms of Service Tile
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined, color: AppColors.success, size: 20),
            ),
            title: Text(
              settings.t('terms_of_service_title'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              settings.t('terms_of_service_sub'),
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _showTermsDialog(context, settings),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemFooter(BuildContext context, SettingsProvider settings, bool isDark) {
    final year = DateTime.now().year;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AegisLogo(size: 16),
              const SizedBox(width: 6),
              Text(
                'AEGIS ${settings.appVersion}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Copyright © $year CethoKaryo. All rights reserved.',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Created by Austin Fascal',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hardware Vault: AES-256 GCM • Zero External Telemetry',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.trim().isEmpty) return 'GU';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _showEditProfileDialog(BuildContext context, SettingsProvider settings) {
    final nameCtrl = TextEditingController(text: settings.isGuest ? '' : settings.operatorName);
    final emailCtrl = TextEditingController(text: settings.operatorEmail);
    final phoneCtrl = TextEditingController(text: settings.operatorPhone);
    final formKey = GlobalKey<FormState>();
    final isIndo = settings.isIndonesian;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIndo ? 'Profil Operator Keamanan' : 'Security Operator Profile'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: isIndo ? 'Nama Lengkap Operator' : 'Operator Full Name',
                      hintText: isIndo ? 'contoh: Austin Fascal' : 'e.g. Austin Fascal',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isIndo ? 'Nama wajib diisi' : 'Name is required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: isIndo ? 'Alamat Email' : 'Email Address',
                      hintText: isIndo ? 'contoh: operator@cethokaryo.id' : 'e.g. operator@cethokaryo.id',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                        return isIndo ? 'Format email tidak valid' : 'Invalid email format';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: isIndo ? 'Nomor Telepon' : 'Phone Number',
                      hintText: isIndo ? 'contoh: +62 812-3456-7890' : 'e.g. +62 812-3456-7890',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isIndo ? 'BATAL' : 'CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await settings.updateProfile(
                name: nameCtrl.text,
                email: emailCtrl.text,
                phone: phoneCtrl.text,
              );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isIndo ? '✅ Profil berhasil disimpan!' : '✅ Operator profile updated!'),
                  ),
                );
              }
            },
            child: Text(isIndo ? 'SIMPAN PROFIL' : 'SAVE PROFILE'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        settings.t('privacy_policy_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicyItem(
                        '1. 100% Zero-Outbound Telemetry Policy',
                        'AEGIS Sentinel executes in strict localized sandbox mode. Under no circumstances are your SSH private keys, passwords, server logs, IP records, or forensic audit events transmitted to external cloud analytics or third-party servers. All processing occurs locally on your host machine.',
                      ),
                      _buildPolicyItem(
                        '2. Hardware-Backed Encryption Vault',
                        'Sensitive authentication credentials (SSH PEM/ED25519 keys and root passwords) are encrypted via AES-256 GCM through the platform hardware security module (Linux Secret Service / Gnome Keyring, Android Keystore, iOS Keychain). Keys are only decrypted ephemerally in RAM during active SSH socket connections.',
                      ),
                      _buildPolicyItem(
                        '3. Ephemeral Memory Lifecycle',
                        'Private keys are decrypted on demand and garbage collected immediately after SSH session termination. No plaintext key is ever written to disk, SQLite, or crash logs.',
                      ),
                      _buildPolicyItem(
                        '4. Local Log Retention & Audit Ring',
                        'Audit events and telemetry time-series are stored in a fixed ring buffer capped at 500 events to guarantee zero disk exhaustion. Log entries can be purged manually by the operator at any time.',
                      ),
                      _buildPolicyItem(
                        '5. Data Deletion Guarantee',
                        'Removing a server from the Server Fleet instantly wipes all associated hardware keys, cached telemetry, and security policies from device memory and hardware storage.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('I UNDERSTAND & AGREE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.description_outlined, color: AppColors.success),
                      SizedBox(width: 10),
                      Text(
                        'Terms of Service & Authorization',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicyItem(
                        '1. Authorization & Permitted Use',
                        'The operator explicitly warrants that they possess legitimate ownership, sysadmin rights, or formal written authorization to connect to, probe, and inspect the servers configured in AEGIS. Connecting to unauthorized third-party infrastructure is strictly prohibited.',
                      ),
                      _buildPolicyItem(
                        '2. Strictly Non-Destructive Probing Commitment',
                        'AEGIS Sentinel is engineered with strict read-only probes (e.g. uname, uptime, pgrep). The software will never install intrusive rootkits, alter remote system binaries, or disrupt production workloads without operator consent.',
                      ),
                      _buildPolicyItem(
                        '3. Anomaly Detection & Mitigation Disclaimers',
                        'Automated brute-force thresholds and IP mitigation actions are recommendations designed to augment human sysadmin decision-making. Operators should verify critical IPs before applying hard firewall bans.',
                      ),
                      _buildPolicyItem(
                        '4. Limitation of Liability',
                        'AEGIS Sentinel is provided as-is without warranty of uninterrupted operation. The developers shall not be liable for any operational downtime, network misconfigurations, or policy adjustments made by the operator.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ACCEPT TERMS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyItem(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }


  void _showLogoutConfirmDialog(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIndo = settings.isIndonesian;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: isDark ? AppColors.danger : AppColors.dangerLight,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isIndo ? 'Konfirmasi Keluar Akun' : 'Confirm Account Logout',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Apakah Anda yakin ingin keluar dari akun operator? Profil Anda akan di-reset menjadi Akun Tamu (Guest User).'
              : 'Are you sure you want to log out of your operator account? Your profile will revert to Guest User.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isIndo ? 'BATAL' : 'CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.danger : AppColors.dangerLight,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await settings.logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isIndo
                          ? '🚪 Berhasil keluar dari akun operator. Status saat ini: Guest User.'
                          : '🚪 Successfully logged out. Status is now Guest User.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(isIndo ? 'KELUAR' : 'LOGOUT'),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection(BuildContext context, SettingsProvider settings, bool isDark) {
    final theme = Theme.of(context);
    final isIndo = settings.isIndonesian;
    final dangerColor = isDark ? AppColors.danger : AppColors.dangerLight;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dangerColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: dangerColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_forever_rounded, color: dangerColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIndo ? 'Hapus Semua Data Aplikasi' : 'Clear All Application Data',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isIndo
                            ? 'Menghapus permanen seluruh server, kunci SSH di hardware vault, PIN keamanan, log audit, dan preferensi lokal, lalu me-restart aplikasi ke kondisi awal instalasi.'
                            : 'Permanently wipe all server profiles, SSH keys in hardware vault, security PIN, audit logs, and local preferences, then restart the app to initial install state.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dangerColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showClearAllDataConfirmDialog(context, settings),
                icon: const Icon(Icons.restore_page_rounded, size: 16),
                label: Text(
                  isIndo ? 'HAPUS SEMUA DATA & RESTART' : 'CLEAR ALL DATA & RESTART',
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearAllDataConfirmDialog(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIndo = settings.isIndonesian;
    final dangerColor = isDark ? AppColors.danger : AppColors.dangerLight;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: dangerColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'HAPUS SEMUA DATA & RESET?' : 'CLEAR ALL DATA & RESET?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Tindakan ini TIDAK DAPAT DIBATALKAN. Seluruh konfigurasi server, kredensial SSH di Secure Vault, PIN keamanan, riwayat audit forensik, dan data profil operator akan dihapus permanen. Aplikasi akan di-restart ke status awal instalasi.'
              : 'This action CANNOT BE UNDONE. All server profiles, SSH credentials in Secure Vault, security PIN, forensic audit history, and operator profile data will be permanently wiped. The application will restart in its initial install state.',
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isIndo ? 'BATAL' : 'CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final serverProvider = context.read<ServerProvider>();
              final policyProvider = context.read<PolicyProvider>();
              final telemetryProvider = context.read<TelemetryProvider>();

              // Show feedback loading indicator while clearing data and restarting
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => PopScope(
                  canPop: false,
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            isIndo
                                ? 'Menghapus data & me-restart aplikasi...'
                                : 'Wiping data & restarting application...',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              // 1. Wipe secure hardware storage
              await SecureVault().clearAll();

              // 2. Wipe config file directory on desktop
              try {
                final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
                if (home != null && home.isNotEmpty) {
                  final dir = Directory('$home/.config/aegis');
                  if (dir.existsSync()) {
                    dir.deleteSync(recursive: true);
                  }
                }
              } catch (e) {
                debugPrint('[SettingsScreen] Config directory wipe error: $e');
              }

              // 3. Clear providers in memory
              await serverProvider.clearAllServers();
              policyProvider.clearAllPolicies();
              telemetryProvider.clearAll();
              await settings.resetAllSettings();

              // Allow file deletion and memory states to settle
              await Future.delayed(const Duration(milliseconds: 200));

              // Dismiss loading dialog if still mounted before in-app reset
              if (context.mounted) {
                try {
                  Navigator.of(context, rootNavigator: true).pop();
                } catch (_) {}
              }

              // 4. Multi-platform application restart
              await AppRestartService.restart();
            },
            child: Text(isIndo ? 'YA, HAPUS SEMUA & RESTART' : 'YES, CLEAR ALL & RESTART'),
          ),
        ],
      ),
    );
  }
}
