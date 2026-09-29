import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/security/biometric_service.dart';
import '../../providers/theme_provider.dart';
import 'dart:async';
import '../../providers/settings_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/policy_provider.dart';
import '../../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'service_detail_screen.dart';
import 'audit_explorer_screen.dart';
import 'policy_settings_screen.dart';
import 'server_management_screen.dart';
import '../widgets/aegis_logo.dart';
import 'package:uuid/uuid.dart';
import '../../models/auth_event.dart';
import '../../providers/telemetry_provider.dart';
import '../../providers/hardware_telemetry_provider.dart';
import 'pin_auth_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<NotificationActionData>? _actionSub;
  StreamSubscription<Map<String, dynamic>>? _fcmSub;
  bool _isBackgrounded = false;
  bool _isLocked = false;
  bool _isPromptingBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final settings = context.read<SettingsProvider>();
    if (settings.isSecurityLockActive) {
      _isLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final bioAvailable = await BiometricService().isBiometricsAvailable();
        if (bioAvailable && settings.biometricLock) {
          _authenticateAppResume();
        }
      });
    }

    // Configure live telemetry polling when an active server connection is already established
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final telemetry = context.read<TelemetryProvider>();
      final serverProvider = context.read<ServerProvider>();
      final policyProvider = context.read<PolicyProvider>();

      telemetry.onLivePollRequested = () async {
        if (!mounted) return;
        final active = serverProvider.activeServer;
        if (active != null && serverProvider.isServerConnected(active.id)) {
          final policy = policyProvider.getPolicy(active.id);
          final liveEvents = await serverProvider.fetchRealTimeLogs(server: active);
          if (liveEvents.isNotEmpty) {
            telemetry.ingestBatchEvents(liveEvents, policy, notifyAlerts: true);
          }
          final serverBans = await serverProvider.fetchServerBannedIps(serverId: active.id);
          if (serverBans.isNotEmpty) {
            policyProvider.syncServerBannedIps(active.id, serverBans);
          }
          if (mounted) {
            final hw = context.read<HardwareTelemetryProvider>();
            await hw.sampleServer(serverProvider: serverProvider, server: active, notify: false);
          }
        }
      };
    });

    // Ingest incoming live FCM alerts directly into TelemetryProvider
    _fcmSub = NotificationService().onFcmEvent.listen((data) {
      if (!mounted) return;
      final telemetry = context.read<TelemetryProvider>();
      final policy = context.read<PolicyProvider>();
      final serverProvider = context.read<ServerProvider>();

      final serverId = data['server_id']?.toString().isNotEmpty == true
          ? data['server_id'].toString()
          : (serverProvider.activeServer?.id ?? 'srv_rumahweb_01');
      final ip = data['ip']?.toString() ?? '';
      final service = data['service']?.toString() ?? 'sshd';
      final title = data['title']?.toString() ?? 'Security Incursion Alert';
      final body = data['body']?.toString() ?? '';
      final user = data['user']?.toString() ?? 'unknown';

      final event = AuthEvent(
        id: const Uuid().v4(),
        serverId: serverId,
        service: service,
        timestamp: DateTime.now(),
        clientIp: ip.isNotEmpty ? ip : 'Unknown IP',
        user: user,
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 92,
        isUnknownPerson: title.toUpperCase().contains('UNKNOWN'),
        failureReason: body,
        rawLog: body,
        evidenceLogs: [body],
      );

      telemetry.ingestEvent(event, policy.getPolicy(serverId));
    });

    _actionSub = NotificationService().onNotificationAction.listen((data) {
      if (!mounted) return;
      final serverProvider = context.read<ServerProvider>();
      final policyProvider = context.read<PolicyProvider>();
      final activeServerId = serverProvider.activeServer?.id;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final isIndo = context.read<SettingsProvider>().isIndonesian;

      if (data.actionId == 'block_ip' && data.payload.isNotEmpty) {
        if (activeServerId != null) {
          policyProvider.banIp(
            activeServerId,
            data.payload,
            'Blocked via Android Notification Quick Action',
            'sshd',
          );
          unawaited(serverProvider.executeFirewallControl(
            ip: data.payload,
            action: 'ban',
            service: 'sshd',
            serverId: activeServerId,
          ));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo
                  ? '🛡️ IP ${data.payload} telah DIBLOKIR di firewall server!'
                  : '🛡️ IP ${data.payload} has been BANNED on server firewall!',
            ),
            backgroundColor: isDark ? AppColors.danger : AppColors.dangerLight,
          ),
        );
      } else if (data.actionId == 'trust_ip' && data.payload.isNotEmpty) {
        if (activeServerId != null) {
          policyProvider.addTrustedIp(activeServerId, data.payload);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo
                  ? '✅ IP ${data.payload} ditambahkan ke Daftar Putih!'
                  : '✅ IP ${data.payload} added to Trusted Whitelist!',
            ),
            backgroundColor: isDark ? AppColors.success : AppColors.successLight,
          ),
        );
      } else {
        // Tapped notification body -> Navigate to Audit Log tab
        setState(() {
          _currentIndex = 2; // Audit Explorer
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actionSub?.cancel();
    _fcmSub?.cancel();
    try {
      context.read<TelemetryProvider>().onLivePollRequested = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final settings = context.read<SettingsProvider>();
    if (!settings.isSecurityLockActive) return;

    // Only paused state represents true backgrounding.
    // Inactive occurs for system dialogs, notification shade, and native biometric prompts.
    if (state == AppLifecycleState.paused) {
      if (!BiometricService().isAuthenticating && !_isPromptingBiometric) {
        _isBackgrounded = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isBackgrounded && !BiometricService().isAuthenticating && !_isPromptingBiometric) {
        _isBackgrounded = false;
        setState(() {
          _isLocked = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final bioAvailable = await BiometricService().isBiometricsAvailable();
          if (bioAvailable && settings.biometricLock) {
            _authenticateAppResume();
          }
        });
      }
    }
  }

  Future<void> _authenticateAppResume() async {
    if (_isPromptingBiometric || BiometricService().isAuthenticating) return;
    _isPromptingBiometric = true;
    final isIndo = context.read<SettingsProvider>().isIndonesian;
    try {
      final success = await BiometricService().authenticate(
        context: context,
        reason: isIndo
            ? 'Verifikasi biometrik untuk membuka konsol AEGIS'
            : 'Biometric verification required to unlock AEGIS console',
      );
      if (mounted) {
        setState(() {
          if (success) {
            _isLocked = false;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPromptingBiometric = false;
        });
      } else {
        _isPromptingBiometric = false;
      }
    }
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildLockOverlay(BuildContext context, bool isDark, bool isIndo, ThemeData theme) {
    return PinAuthScreen(
      mode: PinAuthMode.verify,
      onUnlocked: () {
        setState(() {
          _isLocked = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final settings = context.watch<SettingsProvider>();
    final isIndo = settings.isIndonesian;

    final screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const ServiceDetailScreen(),
      const AuditExplorerScreen(),
      const PolicySettingsScreen(),
      const ServerManagementScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 840;

        Widget scaffold;
        if (isWideScreen) {
          // Responsive Desktop / Tablet Layout with NavigationRail
          scaffold = Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  backgroundColor: theme.colorScheme.surface,
                  indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
                  unselectedIconTheme: IconThemeData(
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                  selectedLabelTextStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const AegisLogo(size: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'AEGIS',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.radar_rounded),
                      selectedIcon: const Icon(Icons.radar_rounded),
                      label: Text(settings.t('nav_dashboard')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.analytics_outlined),
                      selectedIcon: const Icon(Icons.analytics_rounded),
                      label: Text(settings.t('nav_services')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.format_list_bulleted_rounded),
                      selectedIcon: const Icon(Icons.format_list_bulleted_rounded),
                      label: Text(settings.t('nav_audit')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.shield_outlined),
                      selectedIcon: const Icon(Icons.shield_rounded),
                      label: Text(settings.t('nav_policies')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.dns_outlined),
                      selectedIcon: const Icon(Icons.dns_rounded),
                      label: Text(settings.t('nav_servers')),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile Layout with BottomNavigationBar
          scaffold = Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: theme.colorScheme.primary,
                unselectedItemColor: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                selectedFontSize: 10,
                unselectedFontSize: 9,
                iconSize: 20,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.radar_rounded),
                    activeIcon: const Icon(Icons.radar_rounded),
                    label: settings.t('nav_dashboard'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.analytics_outlined),
                    activeIcon: const Icon(Icons.analytics_rounded),
                    label: settings.t('nav_services'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.format_list_bulleted_rounded),
                    activeIcon: const Icon(Icons.format_list_bulleted_rounded),
                    label: settings.t('nav_audit'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.shield_outlined),
                    activeIcon: const Icon(Icons.shield_rounded),
                    label: settings.t('nav_policies'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.dns_outlined),
                    activeIcon: const Icon(Icons.dns_rounded),
                    label: settings.t('nav_servers'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!_isLocked) {
          return scaffold;
        }

        return Stack(
          children: [
            scaffold,
            _buildLockOverlay(context, isDark, isIndo, theme),
          ],
        );
      },
    );
  }
}
