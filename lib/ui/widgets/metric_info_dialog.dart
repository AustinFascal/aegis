import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum MetricType {
  failedLogins,
  unknownLogins,
  blockedAttempts,
  securityIndex,
}

class MetricInfoDialog extends StatelessWidget {
  final MetricType type;
  final String currentValue;
  final Color accentColor;
  final bool isIndo;
  final bool isDark;
  final VoidCallback? onExploreAudit;

  const MetricInfoDialog({
    super.key,
    required this.type,
    required this.currentValue,
    required this.accentColor,
    required this.isIndo,
    required this.isDark,
    this.onExploreAudit,
  });

  static Future<void> show(
    BuildContext context, {
    required MetricType type,
    required String currentValue,
    required Color accentColor,
    required bool isIndo,
    required bool isDark,
    VoidCallback? onExploreAudit,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 650) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => MetricInfoDialog(
          type: type,
          currentValue: currentValue,
          accentColor: accentColor,
          isIndo: isIndo,
          isDark: isDark,
          onExploreAudit: onExploreAudit,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: MetricInfoDialog(
              type: type,
              currentValue: currentValue,
              accentColor: accentColor,
              isIndo: isIndo,
              isDark: isDark,
              onExploreAudit: onExploreAudit,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobileSheet = MediaQuery.of(context).size.width < 650;

    final IconData iconData;
    final String title;
    final String subtitle;
    final String overview;
    final String dataSource;
    final String actionGuide;
    final String statusLabel;
    final Color statusColor;

    switch (type) {
      case MetricType.failedLogins:
        iconData = Icons.cancel_outlined;
        title = isIndo ? 'Percobaan Login Gagal' : 'Failed Login Attempts';
        subtitle = isIndo ? 'Metrik Autentikasi 24 Jam' : '24-Hour Auth Telemetry';
        final intCount = int.tryParse(currentValue.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (intCount > 5) {
          statusLabel = isIndo ? 'Perlu Perhatian (Tinggi)' : 'Elevated Risk';
          statusColor = isDark ? AppColors.danger : AppColors.dangerLight;
        } else {
          statusLabel = isIndo ? 'Kondisi Normal' : 'Normal Posture';
          statusColor = isDark ? AppColors.success : AppColors.successLight;
        }
        overview = isIndo
            ? 'Mencatat seluruh kegagalan autentikasi (salah password, user invalid, atau probe credential) pada layanan SSH daemon, MySQL database, dan Web admin selama 24 jam terakhir.'
            : 'Tracks all authentication failures (wrong password, invalid user, or credential stuffing) across SSH daemon, MySQL database, and Web endpoints over the last 24 hours.';
        dataSource = isIndo
            ? 'Dihitung secara real-time dari log sistem: /var/log/secure (CentOS/RHEL) atau /var/log/auth.log (Ubuntu/Debian), /var/log/mysqld.log, dan access-logs (HTTP 401/403).'
            : 'Extracted in real-time from server logs: /var/log/secure or /var/log/auth.log, /var/log/mysqld.log, and HTTP access-logs (status 401/403).';
        actionGuide = isIndo
            ? 'Ambang batas wajar adalah < 5 percobaan/hari. Jika angka melonjak drastis, periksa Audit Explorer untuk menelusuri IP penyerang dan gunakan 1-Tap Block untuk menambahkan aturan ke Fail2Ban / iptables.'
            : 'Healthy baseline is < 5 attempts/day. If this count surges, inspect Audit Explorer to trace origin IPs and apply 1-Tap Block to instantly drop attacker traffic.';
        break;

      case MetricType.unknownLogins:
        iconData = Icons.person_search_rounded;
        title = isIndo ? 'Login dari IP Tak Dikenal' : 'Untrusted IP Logins';
        subtitle = isIndo ? 'Deteksi Anomali Jaringan' : 'Network Anomaly Detection';
        final intCount = int.tryParse(currentValue.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (intCount > 0) {
          statusLabel = isIndo ? 'Anomali Terdeteksi' : 'Anomaly Detected';
          statusColor = isDark ? AppColors.danger : AppColors.dangerLight;
        } else {
          statusLabel = isIndo ? 'Semua IP Tepercaya' : 'All IPs Trusted';
          statusColor = isDark ? AppColors.success : AppColors.successLight;
        }
        overview = isIndo
            ? 'Mendeteksi login SSH yang berhasil atau sesi koneksi MySQL dari alamat IP yang TIDAK terdaftar di Whitelist IP Tepercaya organisasi Anda.'
            : 'Detects successful SSH sessions or MySQL client connections originating from IP addresses NOT included in your organization\'s Trusted IP Whitelist.';
        dataSource = isIndo
            ? 'Menganalisis baris "Accepted password/publickey" di SSH dan "Connect user@ip" di MySQL, kemudian mencocokkannya dengan daftar IP Tepercaya di Kebijakan Keamanan.'
            : 'Evaluates "Accepted password/publickey" SSH events and MySQL "Connect" records, checking each against the whitelist configured in Policy Settings.';
        actionGuide = isIndo
            ? 'Nilai normal adalah 0. Jika muncul anomali, tanyakan apakah anggota tim login dari jaringan baru. Jika sah, tambahkan ke Whitelist. Jika tidak dikenal, segera putus sesi dan blokir IP.'
            : 'Normal target is 0. If anomalies appear, verify if operators are on new VPN/home networks. If authorized, add to Whitelist; otherwise, isolate and block the IP immediately.';
        break;

      case MetricType.blockedAttempts:
        iconData = Icons.gpp_good_rounded;
        title = isIndo ? 'Percobaan Akses Terblokir' : 'Mitigated & Blocked Attempts';
        subtitle = isIndo ? 'Pertahanan Firewall Aktif' : 'Active Firewall Shield';
        statusLabel = isIndo ? 'Perisai Aktif' : 'Shield Active';
        statusColor = isDark ? AppColors.success : AppColors.successLight;
        overview = isIndo
            ? 'Jumlah ancaman, pemindai bot otomatis, atau penyerang brute-force yang berhasil dicegat dan dimitigasi oleh sistem pertahanan firewall server.'
            : 'Total malicious scanners, bot probes, or brute-force attackers successfully intercepted and neutralized by server firewall policies.';
        dataSource = isIndo
            ? 'Disinkronkan langsung dari aturan filter DROP kernel Linux (iptables) dan daftar IP yang aktif dihukum di jail Fail2Ban (sshd, mysqld-auth, web-probe).'
            : 'Synchronized directly from Linux kernel DROP chains (iptables) and active jail telemetry from Fail2Ban (sshd, mysqld-auth, web).';
        actionGuide = isIndo
            ? 'Angka yang bertambah menunjukkan sistem pertahanan bekerja efektif menangkis serangan. Anda dapat memeriksa daftar seluruh IP yang diblokir di menu Kebijakan -> "SINKRONKAN FAIL2BAN".'
            : 'An increasing metric confirms your firewall is actively filtering threats. Review the full list of banned IPs or manage unbans via Policy Settings -> "SYNC FAIL2BAN".';
        break;

      case MetricType.securityIndex:
        iconData = Icons.speed_rounded;
        title = isIndo ? 'Indeks Integritas Keamanan' : 'Security Integrity Index';
        subtitle = isIndo ? 'Skor Postur Keamanan Server' : 'Server Security Posture Score';
        final intScore = int.tryParse(currentValue.replaceAll(RegExp(r'[^0-9]'), '')) ?? 100;
        if (intScore >= 80) {
          statusLabel = isIndo ? 'Kondisi Sehat (Healthy)' : 'Healthy Posture';
          statusColor = isDark ? AppColors.success : AppColors.successLight;
        } else {
          statusLabel = isIndo ? 'Risiko Meningkat (Elevated)' : 'Elevated Risk';
          statusColor = isDark ? AppColors.danger : AppColors.dangerLight;
        }
        overview = isIndo
            ? 'Skor kesehatan komprehensif (0–100%) yang menggambarkan ketahanan postur keamanan server Anda secara keseluruhan terhadap ancaman aktif.'
            : 'A comprehensive health score (0–100%) measuring your server\'s overall security resilience against live threats and service status.';
        dataSource = isIndo
            ? 'Dihitung secara dinamis berdasarkan formula tertimbang: 100 - (Login Gagal × 2) - (Login IP Asing × 15) - (Layanan Down × 10). Skor pulih seiring berlalunya jendela waktu tanpa insiden.'
            : 'Computed dynamically via weighted algorithm: 100 - (Failed Logins × 2) - (Untrusted Logins × 15) - (Offline Services × 10). Naturally recovers over incident-free windows.';
        actionGuide = isIndo
            ? 'Pertahankan indeks di atas 80%. Jika skor menurun, pastikan seluruh layanan keamanan (SSH, Firewall, Database) dalam kondisi aktif dan netralkan IP penyerang di Audit Explorer.'
            : 'Aim to keep the index above 80%. If it drops, verify critical security daemons in the Services Section and neutralize attacker IPs in Audit Explorer.';
        break;
    }

    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: isMobileSheet
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom Sheet drag handle
              if (isMobileSheet) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
                      ),
                    ),
                    child: Icon(iconData, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Current Value & Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground.withValues(alpha: 0.7)
                      : AppColors.lightBackground.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIndo ? 'NILAI SAAT INI' : 'CURRENT VALUE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentValue,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: isDark ? 0.15 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withValues(alpha: isDark ? 0.4 : 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section 1: Overview & Definition
              _buildInfoSection(
                context,
                icon: Icons.article_outlined,
                title: isIndo ? 'Deskripsi & Definisi' : 'Description & Definition',
                content: overview,
                isDark: isDark,
                accentColor: accentColor,
              ),

              const SizedBox(height: 12),

              // Section 2: Data Source & Calculation
              _buildInfoSection(
                context,
                icon: Icons.data_usage_rounded,
                title: isIndo ? 'Sumber Log & Formula' : 'Telemetry Source & Calculation',
                content: dataSource,
                isDark: isDark,
                accentColor: accentColor,
              ),

              const SizedBox(height: 12),

              // Section 3: Action Guide & Mitigation
              _buildInfoSection(
                context,
                icon: Icons.shield_outlined,
                title: isIndo ? 'Panduan Ambang Batas & Tindakan' : 'Thresholds & Action Guide',
                content: actionGuide,
                isDark: isDark,
                accentColor: accentColor,
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: borderColor),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        isIndo ? 'Tutup' : 'Close',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  ),
                  if (onExploreAudit != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.travel_explore_rounded, size: 18),
                        label: Text(
                          isIndo ? 'Buka Audit Explorer' : 'Explore Audit Log',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onExploreAudit?.call();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    required bool isDark,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
