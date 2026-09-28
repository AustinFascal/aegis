import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/service_registry.dart';
import '../../providers/policy_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../services/penetration_test_service.dart';
import 'forensic_dialog.dart';

class PenetrationTestCard extends StatefulWidget {
  const PenetrationTestCard({super.key});

  @override
  State<PenetrationTestCard> createState() => _PenetrationTestCardState();
}

class _PenetrationTestCardState extends State<PenetrationTestCard> {
  ServiceDefinition _selectedService = ServiceRegistry.knownServices[1]; // sshd default
  PenTestScenario _selectedScenario = PenTestScenario.bruteForce;
  int _originIndex = 0;
  String? _customIp;
  bool _isRunning = false;
  double _progress = 0.0;
  List<PenTestStep> _terminalLogs = [];
  PenTestResult? _lastResult;

  Map<String, String> get _currentOrigin {
    if (_customIp != null && _customIp!.isNotEmpty) {
      return PenetrationTestService.resolveOrigin(_customIp!);
    }
    return PenetrationTestService.threatOrigins[_originIndex];
  }

  void _cycleThreatOrigin() {
    setState(() {
      _customIp = null;
      _originIndex = (_originIndex + 1) % PenetrationTestService.threatOrigins.length;
    });
  }

  void _showIpSelectionModal(BuildContext context, bool isIndo, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IpSelectionSheet(
        currentIp: _currentOrigin['ip']!,
        isIndo: isIndo,
        isDark: isDark,
        onSelect: (selectedIp) {
          setState(() {
            _customIp = null;
            final idx = PenetrationTestService.threatOrigins
                .indexWhere((o) => o['ip'] == selectedIp);
            if (idx != -1) {
              _originIndex = idx;
            } else {
              _customIp = selectedIp;
            }
          });
        },
        onCustomIp: (customIp) {
          setState(() {
            _customIp = customIp;
          });
        },
      ),
    );
  }

  Future<void> _runPenetrationTest() async {
    if (_isRunning) return;

    final settings = context.read<SettingsProvider>();
    final isIndo = settings.isIndonesian;
    final serverProvider = context.read<ServerProvider>();
    final policyProvider = context.read<PolicyProvider>();
    final telemetryProvider = context.read<TelemetryProvider>();

    final activeServer = serverProvider.activeServer;
    final serverId = activeServer?.id ?? 'srv-local-01';
    final policy = policyProvider.getPolicy(serverId);
    final origin = _currentOrigin;

    setState(() {
      _isRunning = true;
      _progress = 0.0;
      _terminalLogs = [];
      _lastResult = null;
    });

    try {
      final result = await PenetrationTestService().executePenTest(
        service: _selectedService,
        scenario: _selectedScenario,
        policy: policy,
        serverId: serverId,
        customIp: origin['ip'],
        onStep: (step, prog) {
          if (mounted) {
            setState(() {
              _terminalLogs.add(step);
              _progress = prog;
            });
          }
        },
      );

      // Ingest the simulated attack into real-time telemetry
      telemetryProvider.ingestEvent(result.event, policy);

      if (mounted) {
        setState(() {
          _isRunning = false;
          _progress = 1.0;
          _lastResult = result;
        });

        HapticFeedback.heavyImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIndo
                            ? '🚨 Alarm Sistem Diaktifkan (${_selectedService.name})'
                            : '🚨 Alert System Triggered (${_selectedService.name})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      Text(
                        isIndo
                            ? 'Serangan dari ${origin['ip']} berhasil diuji & tercatat di Telemetri.'
                            : 'Attack from ${origin['ip']} tested & logged to Telemetry.',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: isIndo ? 'FORENSIK' : 'FORENSICS',
              textColor: Colors.white,
              onPressed: () {
                _openForensicDialog(result);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pen-test simulation error: $e')),
        );
      }
    }
  }

  void _openForensicDialog(PenTestResult result) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ForensicDialog(event: result.event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;
    final serverProvider = context.watch<ServerProvider>();
    final hasServer = serverProvider.servers.isNotEmpty && serverProvider.activeServer != null;
    final activeServer = serverProvider.activeServer;
    final origin = _currentOrigin;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _lastResult != null
              ? AppColors.danger.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: _lastResult != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (_isRunning)
            BoxShadow(
              color: AppColors.danger.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header & Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.security_update_warning_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIndo
                          ? 'LABORATORIUM UJI PENETRASI & ALARM'
                          : 'PENETRATION TESTING & ALERT LAB',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isIndo
                          ? 'Simulasikan serangan siber terkontrol untuk menguji alarm & respon insiden'
                          : 'Simulate controlled cyber attacks to stress-test alerts & incident response',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isIndo ? 'SIMULASI LIVE' : 'LIVE SIM',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Server Dependency Status Banner
          if (!hasServer) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.dns_rounded, size: 20, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIndo ? 'SERVER BELUM DIKONFIGURASI' : 'NO SERVER CONFIGURED',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.warning,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isIndo
                              ? 'Fitur uji penetrasi dinonaktifkan karena belum ada server yang ditambahkan. Silakan tambahkan server aktif di menu Server untuk mengaktifkan simulasi.'
                              : 'Penetration testing is disabled because no server has been added yet. Please add an active server in the Server menu to enable simulations.',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.dns_rounded,
                    size: 15,
                    color: isDark ? AppColors.primary : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TARGET: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.primary : AppColors.primaryLight,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${activeServer!.name} (${activeServer.host}:${activeServer.port})',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isIndo ? 'AKTIF' : 'ACTIVE',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. Choose Target Service
          Opacity(
            opacity: hasServer ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIndo ? '1. PILIH LAYANAN TARGET (SERVICE TO TEST)' : '1. SELECT TARGET SERVICE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ServiceDefinition>(
                      value: _selectedService,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: ServiceRegistry.knownServices.map((service) {
                        return DropdownMenuItem<ServiceDefinition>(
                          value: service,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: service.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(service.icon, size: 16, color: service.color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  service.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: Text(
                                  service.portDisplay,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (hasServer && !_isRunning)
                          ? (newService) {
                              if (newService != null) {
                                setState(() {
                                  _selectedService = newService;
                                });
                              }
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Select Attack Scenario
          Opacity(
            opacity: hasServer ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIndo ? '2. SKENARIO SERANGAN (ATTACK VECTOR)' : '2. ATTACK VECTOR SCENARIO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PenTestScenario.values.map((scenario) {
                    final isSelected = _selectedScenario == scenario;
                    final color = scenario.color;

                    return InkWell(
                      onTap: (hasServer && !_isRunning)
                          ? () {
                              setState(() {
                                _selectedScenario = scenario;
                              });
                            }
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: isDark ? 0.2 : 0.12)
                              : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(scenario.icon, size: 15, color: isSelected ? color : AppColors.textMuted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isIndo ? scenario.displayNameId : scenario.displayNameEn,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? color : theme.colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Select Threat Actor IP (with modal list and custom input)
          Opacity(
            opacity: hasServer ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isIndo
                            ? '3. PROFIL IP PENYERANG (${PenetrationTestService.threatOrigins.length}+ IP)'
                            : '3. THREAT ACTOR IP (${PenetrationTestService.threatOrigins.length}+ IPS)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: (hasServer && !_isRunning)
                          ? () => _showIpSelectionModal(context, isIndo, isDark)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.list_alt_rounded,
                              size: 14,
                              color: hasServer ? theme.colorScheme.primary : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isIndo ? 'PILIH IP LAIN' : 'CHOOSE IP',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: hasServer ? theme.colorScheme.primary : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _customIp != null
                          ? AppColors.purple.withValues(alpha: 0.5)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        origin['flag'] ?? '🌐',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  origin['ip']!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.warning,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.warning.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    origin['category'] ?? 'Threat Actor',
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                                if (_customIp != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.purple.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isIndo ? 'KUSTOM' : 'CUSTOM',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.purple,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${origin['city']}, ${origin['country']} • ${origin['asn']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 19),
                        tooltip: isIndo ? 'IP Berikutnya' : 'Next IP',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        padding: EdgeInsets.zero,
                        onPressed: (hasServer && !_isRunning) ? _cycleThreatOrigin : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted_rounded, size: 19),
                        tooltip: isIndo ? 'Buka Daftar Lengkap IP' : 'Browse All IPs',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        padding: EdgeInsets.zero,
                        onPressed: (hasServer && !_isRunning)
                            ? () => _showIpSelectionModal(context, isIndo, isDark)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Action Button (Launch Pen-Test)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasServer ? AppColors.danger : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                foregroundColor: hasServer ? Colors.white : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                disabledBackgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                disabledForegroundColor: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: (_isRunning || !hasServer) ? 0 : 2,
              ),
              onPressed: (hasServer && !_isRunning) ? _runPenetrationTest : null,
              icon: _isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      hasServer ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
                      size: 20,
                    ),
              label: Text(
                _isRunning
                    ? (isIndo ? 'MELANCARKAN SIMULASI PEN-TEST...' : 'EXECUTING PENETRATION TEST...')
                    : (!hasServer
                        ? (isIndo ? 'LANCARKAN UJI PENETRASI (TAMBAH SERVER DAHULU)' : 'RUN PENETRATION TEST (ADD SERVER FIRST)')
                        : (isIndo ? 'LANCARKAN UJI PENETRASI' : 'RUN PENETRATION TEST')),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: hasServer ? Colors.white : (isDark ? AppColors.textMuted : AppColors.lightTextMuted),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          if (_isRunning) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.danger.withValues(alpha: 0.15),
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(4),
              minHeight: 4,
            ),
          ],

          // 5. Terminal Console Output
          if (_terminalLogs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF070B12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFF1E293B),
                ),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _terminalLogs.map((step) {
                    Color textColor = const Color(0xFF94A3B8);
                    if (step.isAlert) {
                      textColor = AppColors.danger;
                    } else if (step.isSuccess) {
                      textColor = AppColors.success;
                    } else if (step.message.startsWith('[PAYLOAD')) {
                      textColor = AppColors.warning;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        step.message,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          height: 1.35,
                          color: textColor,
                          fontWeight: step.isAlert ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // 6. Success & Action Shortcuts upon completion
          if (_lastResult != null) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isIndo
                                        ? 'SIMULASI BERHASIL: ALARM AKTIF'
                                        : 'SIMULATION PASSED: ALERT TRIGGERED',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isIndo
                                  ? 'Alarm push dan getaran terkirim. Anda dapat membuka investigasi forensik instan.'
                                  : 'Push alert and sound dispatched. You can inspect real-time forensics now.',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _openForensicDialog(_lastResult!),
                                icon: const Icon(Icons.troubleshoot_rounded, size: 14),
                                label: Text(
                                  isIndo ? 'BUKA FORENSIK' : 'OPEN FORENSICS',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isIndo
                                        ? 'SIMULASI BERHASIL: ALARM AKTIF & TERTANGKAP'
                                        : 'SIMULATION PASSED: ALERT TRIGGERED & RECORDED',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    isIndo
                                        ? 'Alarm push dan getaran terkirim. Anda dapat membuka investigasi forensik instan.'
                                        : 'Push alert and sound dispatched. You can inspect real-time forensics now.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _openForensicDialog(_lastResult!),
                              icon: const Icon(Icons.troubleshoot_rounded, size: 14),
                              label: Text(
                                isIndo ? 'BUKA FORENSIK' : 'OPEN FORENSICS',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _IpSelectionSheet extends StatefulWidget {
  final String currentIp;
  final bool isIndo;
  final bool isDark;
  final Function(String ip) onSelect;
  final Function(String ip) onCustomIp;

  const _IpSelectionSheet({
    required this.currentIp,
    required this.isIndo,
    required this.isDark,
    required this.onSelect,
    required this.onCustomIp,
  });

  @override
  State<_IpSelectionSheet> createState() => _IpSelectionSheetState();
}

class _IpSelectionSheetState extends State<_IpSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customIpController = TextEditingController();
  String _filter = '';
  bool _isEnteringCustom = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origins = PenetrationTestService.threatOrigins;

    final filtered = origins.where((o) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return (o['ip']?.toLowerCase().contains(q) ?? false) ||
          (o['city']?.toLowerCase().contains(q) ?? false) ||
          (o['country']?.toLowerCase().contains(q) ?? false) ||
          (o['category']?.toLowerCase().contains(q) ?? false) ||
          (o['asn']?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F1522) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.public_rounded, color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isIndo
                            ? 'PILIH IP PENYERANG (${origins.length} PROFIL SIBER)'
                            : 'SELECT THREAT ACTOR IP (${origins.length} PROFILES)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        widget.isIndo
                            ? 'Pilih profil ancaman global atau masukkan IP kustom'
                            : 'Choose global threat profile or enter custom IP address',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Search & Custom IP bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.isIndo
                        ? 'Cari IP, negara, kota, atau tipe ancaman...'
                        : 'Search IP, country, city, or threat type...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: widget.isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.lightSurfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _filter = val);
                  },
                ),

                const SizedBox(height: 10),

                // Custom IP Toggle / Input field
                if (!_isEnteringCustom)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isEnteringCustom = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.purple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.isIndo
                                  ? '+ Masukkan IP Kustom Sendiri (Uji IP Lokal/Spesifik)'
                                  : '+ Enter Custom IP Address (Test Local/Specific IP)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.purple,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.purple),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.purple.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customIpController,
                            autofocus: true,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              hintText: 'e.g. 192.168.1.100 atau 203.0.113.5',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            final ip = _customIpController.text.trim();
                            if (ip.isNotEmpty) {
                              widget.onCustomIp(ip);
                              Navigator.pop(context);
                            }
                          },
                          child: Text(widget.isIndo ? 'Gunakan' : 'Use IP'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable IP List
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemBuilder: (context, index) {
                final o = filtered[index];
                final isSelected = widget.currentIp == o['ip'];

                return InkWell(
                  onTap: () {
                    widget.onSelect(o['ip']!);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Text(
                          o['flag'] ?? '🌐',
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    o['ip']!,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      o['category'] ?? 'Threat',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${o['city']}, ${o['country']} • ${o['asn']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                        else
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
