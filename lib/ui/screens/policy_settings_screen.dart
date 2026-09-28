import '../../core/security/biometric_service.dart';
import 'faq_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/policy_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/compliance_scanner_card.dart';

class PolicySettingsScreen extends StatelessWidget {
  const PolicySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final serverProvider = context.watch<ServerProvider>();
    final policyProvider = context.watch<PolicyProvider>();
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;
    final activeServer = serverProvider.activeServer;

    if (activeServer == null) {
      return Scaffold(
        appBar: AppBar(
          notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
          title: Text(isIndo ? 'KEBIJAKAN KEAMANAN & FIREWALL' : 'BASELINE SECURITY & FIREWALL'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: isIndo ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FaqScreen(initialCategory: FaqCategory.policy),
                  ),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Text(
            isIndo ? 'Belum ada server aktif terkonfigurasi' : 'No active server configured',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final policy = policyProvider.getPolicy(activeServer.id);

    return Scaffold(
      appBar: AppBar(
        notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
        title: Text(isIndo ? 'KEBIJAKAN KEAMANAN & FIREWALL' : 'BASELINE SECURITY & FIREWALL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: isIndo ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FaqScreen(initialCategory: FaqCategory.policy),
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
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Server Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isIndo ? 'Kebijakan untuk: ${activeServer.name} (${activeServer.host})' : 'Policy for: ${activeServer.name} (${activeServer.host})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // System Hardening & Compliance Scanner Card
                    ComplianceScannerCard(server: activeServer),

                    const SizedBox(height: 24),

                    // Trusted IPs Whitelist
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isIndo ? 'DAFTAR PUTIH IP TERPERCAYA' : 'TRUSTED IP WHITELIST',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                isIndo ? 'Login di luar daftar ini memicu peringatan "Orang Tak Dikenal"' : 'Logins outside this list trigger "Unknown Person" alerts',
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
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline,
                              color: theme.colorScheme.primary),
                          tooltip: isIndo ? 'Tambah IP Terpercaya' : 'Add Trusted IP',
                          onPressed: () => _showAddIpDialog(context, activeServer.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: policy.trustedIps.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                isIndo ? 'Belum ada IP terpercaya. Semua login eksternal akan memicu peringatan.' : 'No trusted IPs defined. All external logins will trigger alerts.',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: policy.trustedIps.map((ip) {
                                return Chip(
                                  backgroundColor: isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.lightSurfaceElevated,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isDark
                                          ? AppColors.darkBorderLight
                                          : AppColors.lightBorderLight,
                                    ),
                                  ),
                                  label: Text(
                                    ip,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  deleteIconColor: isDark
                                      ? AppColors.textMuted
                                      : AppColors.lightTextMuted,
                                  onDeleted: () {
                                    policyProvider.removeTrustedIp(activeServer.id, ip);
                                  },
                                );
                              }).toList(),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // Anomaly Thresholds
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          isIndo ? 'AMBANG BATAS BRUTE FORCE & ANOMALI' : 'BRUTE FORCE & ANOMALY THRESHOLDS',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_done_outlined,
                              size: 14,
                              color: isDark ? AppColors.success : AppColors.successLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isIndo ? 'Tersimpan ke Vault' : 'Saved to Vault',
                              style: TextStyle(
                                color: isDark ? AppColors.success : AppColors.successLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FaqScreen(initialCategory: FaqCategory.policy),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.help_outline_rounded,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isIndo ? 'Panduan FAQ' : 'FAQ Guide',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  isIndo ? 'Batas Maks Login Gagal Sebelum Peringatan' : 'Max Failed Logins Before Alert',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  isIndo ? '${policy.maxFailedAttemptsThreshold} kali' : '${policy.maxFailedAttemptsThreshold} attempts',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: policy.maxFailedAttemptsThreshold.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              activeColor: theme.colorScheme.primary,
                              inactiveColor: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated,
                              onChanged: (val) {
                                policyProvider.updatePolicy(
                                  activeServer.id,
                                  policy.copyWith(
                                      maxFailedAttemptsThreshold: val.toInt()),
                                );
                              },
                            ),
                            const Divider(),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  isIndo ? 'Jendela Kecepatan (Waktu Geser)' : 'Velocity Window (Sliding Time)',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${policy.timeWindowSeconds}s (${(policy.timeWindowSeconds / 60).toStringAsFixed(1)}m)',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: policy.timeWindowSeconds.toDouble().clamp(30.0, 600.0),
                              min: 30,
                              max: 600,
                              divisions: 19,
                              activeColor: theme.colorScheme.primary,
                              inactiveColor: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated,
                              onChanged: (val) {
                                policyProvider.updatePolicy(
                                  activeServer.id,
                                  policy.copyWith(timeWindowSeconds: val.toInt()),
                                );
                              },
                            ),
                            const Divider(),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                isIndo ? 'Peringatan Login Orang Tak Dikenal' : 'Alert on Unknown Person Login',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                isIndo ? 'Kirim notifikasi kritis jika login sukses berasal dari IP luar whitelist' : 'Push critical notification if a valid login occurs from untrusted IP',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textMuted
                                      : AppColors.lightTextMuted,
                                  fontSize: 11,
                                ),
                              ),
                              value: policy.alertOnUnknownSuccess,
                              activeTrackColor: theme.colorScheme.primary,
                              onChanged: (val) {
                                policyProvider.updatePolicy(
                                  activeServer.id,
                                  policy.copyWith(alertOnUnknownSuccess: val),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Server Firewall Engine Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            color: isDark ? AppColors.success : AppColors.successLight,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isIndo ? 'Firewall Server: fail2ban (Aktif) • filter iptables (Berjalan) • firewalld (Dimatikan)' : 'Server Firewall: fail2ban (Active) • iptables filter (Running) • firewalld (Masked/Off)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active Banned IPs Table Header with Sync from Fail2Ban Button
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          isIndo ? 'PEMBLOKIRAN FIREWALL AKTIF (${policy.bannedIps.length})' : 'ACTIVE FIREWALL BANS (${policy.bannedIps.length})',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(isIndo ? 'Menyinkronkan pemblokiran aktif dari Fail2Ban & iptables...' : 'Syncing active bans from Fail2Ban & iptables...'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            final serverBans = await serverProvider.fetchServerBannedIps(
                              serverId: activeServer.id,
                            );
                            if (serverBans.isNotEmpty) {
                              policyProvider.syncServerBannedIps(activeServer.id, serverBans);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      isIndo ? '✅ Berhasil menyinkronkan ${serverBans.length} IP terblokir dari Fail2Ban & iptables!' : '✅ Synced ${serverBans.length} active bans from Fail2Ban & iptables!'),
                                  backgroundColor: isDark
                                      ? AppColors.success
                                      : AppColors.successLight,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      isIndo ? 'Tidak ada pemblokiran baru ditemukan di Fail2Ban/iptables.' : 'No additional active bans found in Fail2Ban/iptables.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: Text(
                            isIndo ? 'SINKRONKAN FAIL2BAN' : 'SYNC FAIL2BAN',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (policy.bannedIps.isEmpty)
                      Card(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            isIndo ? 'Tidak ada IP yang sedang diblokir di firewall.' : 'No IPs currently banned on firewall.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.lightTextMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...policy.bannedIps.map((banned) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: (isDark
                                                  ? AppColors.danger
                                                  : AppColors.dangerLight)
                                              .withValues(alpha: isDark ? 0.15 : 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.block_rounded,
                                          color: isDark
                                              ? AppColors.danger
                                              : AppColors.dangerLight,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              banned.ip,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: theme.colorScheme.onSurface,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                            Text(
                                              '${banned.service.toUpperCase()} • ${banned.reason}',
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
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () async {
                                    final settings = context.read<SettingsProvider>();
                                    if (settings.biometricLock) {
                                      final ok = await BiometricService().authenticate(
context: context,
reason: isIndo
                                            ? 'Otorisasi biometrik untuk membuka blokir IP ${banned.ip}'
                                            : 'Biometric authorization required to unban IP ${banned.ip}',
                                      );
                                      if (!ok) {
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
                                    policyProvider.unbanIp(activeServer.id, banned.ip);
                                    // Remote unban via iptables & fail2ban
                                    unawaited(serverProvider.executeFirewallControl(
                                      ip: banned.ip,
                                      action: 'unban',
                                      service: banned.service,
                                      serverId: activeServer.id,
                                    ));

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              isIndo ? 'IP ${banned.ip} telah dibuka blokirnya dari firewall.' : 'IP ${banned.ip} unbanned from firewall.'),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    isIndo ? 'BUKA BLOKIR' : 'UNBAN',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

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

  void _showAddIpDialog(BuildContext context, String serverId) {
    final ipCtrl = TextEditingController();
    final isIndo = context.read<SettingsProvider>().isIndonesian;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIndo ? 'Tambah IP / Subnet Terpercaya' : 'Add Trusted IP / Subnet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipCtrl,
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: isIndo ? 'Alamat IP atau Pola Subnet' : 'IP Address or Subnet Pattern',
                hintText: isIndo ? 'cth. 103.142.21.195 atau 192.168.1.*' : 'e.g. 103.142.21.195 or 192.168.1.*',
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
            onPressed: () async {
              final val = ipCtrl.text.trim();
              if (val.isNotEmpty) {
                final settings = context.read<SettingsProvider>();
                if (settings.biometricLock) {
                  final ok = await BiometricService().authenticate(
context: context,
reason: isIndo
                        ? 'Otorisasi biometrik untuk menambahkan IP $val ke daftar putih'
                        : 'Biometric authorization required to whitelist IP $val',
                  );
                  if (!ok) {
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
                if (context.mounted) {
                  context.read<PolicyProvider>().addTrustedIp(serverId, val);
                  Navigator.of(ctx).pop();
                }
              }
            },
            child: Text(isIndo ? 'TAMBAH KE DAFTAR PUTIH' : 'ADD TO WHITELIST'),
          ),
        ],
      ),
    );
  }
}
