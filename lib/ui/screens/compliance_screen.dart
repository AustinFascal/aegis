import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/compliance_check.dart';
import '../../models/server_profile.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/compliance_service.dart';
import 'faq_screen.dart';

class ComplianceScreen extends StatefulWidget {
  final ServerProfile? server;

  const ComplianceScreen({
    super.key,
    this.server,
  });

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  final ComplianceService _complianceService = ComplianceService();
  ComplianceScanReport? _report;
  bool _isScanning = false;
  ComplianceCategory? _selectedCategory;
  bool _showFailedOnly = false;
  final Set<String> _expandedItemIds = {};

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
    });

    final serverProvider = context.read<ServerProvider>();
    final targetServer = widget.server ?? serverProvider.activeServer;

    if (targetServer == null) {
      setState(() {
        _isScanning = false;
      });
      return;
    }

    try {
      final credential = await serverProvider.getCredentialForServer(targetServer);
      final report = await _complianceService.runComplianceScan(
        server: targetServer,
        credential: credential,
      );

      if (mounted) {
        setState(() {
          _report = report;
          _isScanning = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _showPlaybookDialog(bool isIndo) {
    if (_report == null) return;
    final playbook = _complianceService.generateRemediationPlaybook(_report!);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.terminal_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(isIndo ? 'Playbook Remediasi Otomatis' : 'Automated Remediation Playbook'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isIndo
                      ? 'Skrip bash terpadu untuk memperbaiki semua celah kepatuhan dan hardening server yang terdeteksi:'
                      : 'Consolidated bash hardening playbook to patch all detected non-compliant settings:',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: SelectableText(
                    playbook,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.success,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isIndo ? 'Tutup' : 'Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: playbook));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.success,
                  content: Text(isIndo ? '✅ Playbook disalin ke clipboard!' : '✅ Hardening playbook copied to clipboard!'),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(isIndo ? 'Salin Skrip' : 'Copy Script'),
          ),
        ],
      ),
    );
  }

  void _exportReport(bool isIndo) {
    if (_report == null) return;
    final markdown = _complianceService.generateMarkdownReport(_report!, isIndo);
    Clipboard.setData(ClipboardData(text: markdown));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(isIndo ? '✅ Laporan audit Markdown disalin ke clipboard!' : '✅ Markdown audit report copied to clipboard!'),
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
    final targetServer = widget.server ?? serverProvider.activeServer;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isIndo ? 'HARDENING & KEPATUHAN' : 'HARDENING & COMPLIANCE',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (targetServer != null)
              Text(
                '${targetServer.name} (${targetServer.host})',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isIndo ? 'Pindai Ulang Kepatuhan' : 'Rescan Compliance',
            onPressed: _isScanning ? null : _startScan,
          ),
          IconButton(
            icon: const Icon(Icons.code_rounded),
            tooltip: isIndo ? 'Playbook Remediasi' : 'Remediation Playbook',
            onPressed: _report != null ? () => _showPlaybookDialog(isIndo) : null,
          ),
          if (MediaQuery.sizeOf(context).width >= 500) ...[
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: isIndo ? 'Salin Laporan Audit' : 'Export Audit Report',
              onPressed: _report != null ? () => _exportReport(isIndo) : null,
            ),
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: isIndo ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FaqScreen(initialCategory: FaqCategory.server),
                  ),
                );
              },
            ),
          ] else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: isIndo ? 'Opsi Tambahan' : 'More Options',
              onSelected: (value) {
                if (value == 'export') {
                  _exportReport(isIndo);
                } else if (value == 'faq') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FaqScreen(initialCategory: FaqCategory.server),
                    ),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'export',
                  enabled: _report != null,
                  child: Row(
                    children: [
                      const Icon(Icons.share_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(isIndo ? 'Salin Laporan Audit' : 'Export Audit Report'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'faq',
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(isIndo ? 'Pusat Bantuan & FAQ' : 'Help Center & FAQ'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: targetServer == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.dns_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    isIndo ? 'Belum ada server aktif terkonfigurasi.' : 'No active server configured.',
                    style: TextStyle(
                      color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _isScanning
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isIndo
                            ? 'Menjalankan audit hardening sistem pada ${targetServer.name}...'
                            : 'Running system hardening audit on ${targetServer.name}...',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isIndo
                            ? 'Memeriksa konfigurasi SSH, sysctl kernel, firewall, dan izin berkas...'
                            : 'Checking SSH configs, kernel sysctl, firewalls, and file perms...',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _report == null
                  ? Center(
                      child: ElevatedButton.icon(
                        onPressed: _startScan,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(isIndo ? 'Mulai Pemindaian Kepatuhan' : 'Start Compliance Scan'),
                      ),
                    )
                  : _buildReportContent(theme, isDark, isIndo),
    );
  }

  Widget _buildReportContent(ThemeData theme, bool isDark, bool isIndo) {
    final report = _report!;
    final filteredItems = report.items.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (_showFailedOnly && item.status == ComplianceStatus.passed) {
        return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Executive Score Card
              _buildScoreCard(report, isDark, isIndo),
              const SizedBox(height: 16),

              // Filter Controls
              _buildFilterToolbar(report, isDark, isIndo),
              const SizedBox(height: 16),

              // Findings Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isIndo
                          ? 'TEMUAN AUDIT HARDENING (${filteredItems.length})'
                          : 'HARDENING AUDIT FINDINGS (${filteredItems.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (report.failedCount > 0 || report.warningCount > 0) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => _showPlaybookDialog(isIndo),
                      icon: const Icon(Icons.build_circle_rounded, size: 15, color: AppColors.primary),
                      label: Text(
                        isIndo ? 'Perbaiki Semua' : 'Fix All Issues',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Findings List
              if (filteredItems.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Center(
                    child: Text(
                      isIndo ? 'Tidak ada temuan yang cocok dengan filter.' : 'No findings match the current filter.',
                      style: TextStyle(color: isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                    ),
                  ),
                )
              else
                ...filteredItems.map((item) => _buildFindingCard(item, isDark, isIndo)),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(ComplianceScanReport report, bool isDark, bool isIndo) {
    Color gradeColor;
    if (report.score >= 85) {
      gradeColor = AppColors.success;
    } else if (report.score >= 70) {
      gradeColor = AppColors.warning;
    } else {
      gradeColor = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gradeColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradeColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Score Gauge
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border.all(color: gradeColor, width: 3.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${report.score}%',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: gradeColor,
                    fontFamily: 'monospace',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'GRADE ${report.grade}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: gradeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // Breakdown statistics
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIndo ? 'Skor Kepatuhan CIS & Hardening' : 'CIS & Hardening Compliance Score',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isIndo
                      ? '${report.passedCount} dari ${report.totalCount} pengujian berhasil memenuhi standar keamanan.'
                      : '${report.passedCount} of ${report.totalCount} audit benchmarks meet security baselines.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 12),

                // Stat badges row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildStatPill('Lolos: ${report.passedCount}', AppColors.success, Icons.check_circle_rounded),
                    _buildStatPill('Peringatan: ${report.warningCount}', AppColors.warning, Icons.warning_rounded),
                    _buildStatPill('Gagal: ${report.failedCount}', AppColors.danger, Icons.cancel_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(ComplianceScanReport report, bool isDark, bool isIndo) {
    final categories = [
      (null, isIndo ? 'Semua' : 'All'),
      (ComplianceCategory.ssh, 'OpenSSH'),
      (ComplianceCategory.sysctl, 'Kernel Sysctl'),
      (ComplianceCategory.firewall, 'Firewall'),
      (ComplianceCategory.identity, isIndo ? 'Identitas' : 'Identity'),
      (ComplianceCategory.filesystem, isIndo ? 'Berkas' : 'Filesystem'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filter Chips
          for (final (cat, label) in categories)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label),
                selected: _selectedCategory == cat,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _selectedCategory == cat ? FontWeight.w800 : FontWeight.w500,
                  color: _selectedCategory == cat ? AppColors.primary : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat),
              ),
            ),

          const SizedBox(width: 6),

          // Failed Only Toggle
          FilterChip(
            label: Text(isIndo ? 'Hanya Pelanggaran' : 'Issues Only'),
            selected: _showFailedOnly,
            selectedColor: AppColors.danger.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: _showFailedOnly ? FontWeight.w800 : FontWeight.w500,
              color: _showFailedOnly ? AppColors.danger : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
            ),
            onSelected: (val) => setState(() => _showFailedOnly = val),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingCard(ComplianceCheckItem item, bool isDark, bool isIndo) {
    final isExpanded = _expandedItemIds.contains(item.id);

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (item.status) {
      case ComplianceStatus.passed:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = isIndo ? 'LOLOS' : 'PASSED';
        break;
      case ComplianceStatus.warning:
        statusColor = AppColors.warning;
        statusIcon = Icons.warning_rounded;
        statusLabel = isIndo ? 'PERINGATAN' : 'WARNING';
        break;
      case ComplianceStatus.failed:
        statusColor = AppColors.danger;
        statusIcon = Icons.cancel_rounded;
        statusLabel = isIndo ? 'GAGAL' : 'FAILED';
        break;
      case ComplianceStatus.skipped:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.help_outline_rounded;
        statusLabel = 'SKIPPED';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.status != ComplianceStatus.passed
              ? statusColor.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: item.status != ComplianceStatus.passed ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Header Row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedItemIds.remove(item.id);
                } else {
                  _expandedItemIds.add(item.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: statusColor),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _getSeverityColor(item.severity).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.severity.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: _getSeverityColor(item.severity),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.standard,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isIndo ? item.titleId : item.titleEn,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                ],
              ),
            ),
          ),

          // Expandable Details
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIndo ? item.descriptionId : item.descriptionEn,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Security Rationale
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIndo ? '🛡️ Rasional Keamanan:' : '🛡️ Security Rationale:',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isIndo ? item.rationaleId : item.rationaleEn,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Expected vs Actual
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isIndo ? 'Kondisi Diharapkan:' : 'Expected Condition:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.expected,
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isIndo ? 'Kondisi Terdeteksi:' : 'Detected State:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.actual ?? (isIndo ? 'Tidak diketahui' : 'Unknown'),
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Remediation Script Box
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isIndo ? 'Skrip Perbaikan (Remediasi):' : 'Remediation Command:',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item.remediationScript));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.success,
                                  content: Text(isIndo ? '✅ Skrip perbaikan disalin!' : '✅ Remediation script copied!'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 13, color: AppColors.primary),
                            label: Text(
                              isIndo ? 'Salin Perbaikan' : 'Copy Fix',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: SelectableText(
                          item.remediationScript,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: AppColors.primary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getSeverityColor(ComplianceSeverity severity) {
    switch (severity) {
      case ComplianceSeverity.critical:
        return AppColors.danger;
      case ComplianceSeverity.high:
        return AppColors.warning;
      case ComplianceSeverity.medium:
        return const Color(0xFFFACC15);
      case ComplianceSeverity.low:
        return AppColors.info;
    }
  }
}
