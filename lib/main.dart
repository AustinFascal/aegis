import 'core/constants/app_colors.dart';
import 'core/security/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/app_theme.dart';
import 'providers/server_provider.dart';
import 'providers/policy_provider.dart';
import 'providers/telemetry_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/screens/onboarding_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BiometricService().navigatorKey = rootNavigatorKey;

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init: $e');
  }

  // Initialize Notification Service (FCM & Local Notifications)
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Pre-load settings to prevent any momentary onboarding screen flash/glitch
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(AegisRoot(
    key: AegisRoot.rootKey,
    initialSettingsProvider: settingsProvider,
    initialOnboardingCompleted: settingsProvider.isOnboardingCompleted,
  ));
}

class AegisRoot extends StatefulWidget {
  final SettingsProvider? initialSettingsProvider;
  final bool? initialOnboardingCompleted;

  static final GlobalKey<AegisRootState> rootKey = GlobalKey<AegisRootState>();

  const AegisRoot({
    super.key,
    this.initialSettingsProvider,
    this.initialOnboardingCompleted,
  });

  static void restartApp([BuildContext? context]) {
    final state = rootKey.currentState ??
        context?.findAncestorStateOfType<AegisRootState>();
    if (state != null) {
      state.restartApp();
    } else {
      final navContext = context ?? rootNavigatorKey.currentContext;
      if (navContext != null) {
        Navigator.of(navContext, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AegisApp(initialOnboardingCompleted: false)),
          (route) => false,
        );
      }
    }
  }

  @override
  State<AegisRoot> createState() => AegisRootState();
}

class AegisRootState extends State<AegisRoot> {
  Key _key = UniqueKey();
  SettingsProvider? _settingsProvider;
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _settingsProvider = widget.initialSettingsProvider;
    _onboardingCompleted = widget.initialOnboardingCompleted;
  }

  void restartApp() {
    setState(() {
      _key = UniqueKey();
      _settingsProvider = null;
      _onboardingCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: AegisApp(
        initialSettingsProvider: _settingsProvider,
        initialOnboardingCompleted: _onboardingCompleted,
      ),
    );
  }
}

class AegisApp extends StatelessWidget {
  final bool? initialOnboardingCompleted;
  final SettingsProvider? initialSettingsProvider;
  const AegisApp({
    super.key,
    this.initialOnboardingCompleted,
    this.initialSettingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
        ChangeNotifierProvider(create: (_) => PolicyProvider()),
        ChangeNotifierProvider(create: (_) => TelemetryProvider()),
        initialSettingsProvider != null
            ? ChangeNotifierProvider<SettingsProvider>.value(value: initialSettingsProvider!)
            : ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
      ],
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settingsProvider, child) {
          // Prevent onboarding flash while settings are loading
          if (!settingsProvider.isLoaded && initialOnboardingCompleted == null) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: Scaffold(
                backgroundColor: themeProvider.isDarkMode
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
                body: const SizedBox.expand(),
              ),
            );
          }

          return MaterialApp(
            title: 'AEGIS - Infrastructure Security Sentinel',
            navigatorKey: rootNavigatorKey,
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                final isCompleted = (initialOnboardingCompleted == true) || settings.isOnboardingCompleted;

                return isCompleted
                    ? const MainNavigationScreen()
                    : const OnboardingScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
