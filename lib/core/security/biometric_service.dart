import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/settings_provider.dart';
import '../../ui/screens/pin_auth_screen.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  GlobalKey<NavigatorState>? navigatorKey;
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;
  DateTime? _lastAuthTime;

  bool get isCoolingDown {
    if (_lastAuthTime == null) return false;
    return DateTime.now().difference(_lastAuthTime!) < const Duration(milliseconds: 250);
  }

  void resetCooldown() {
    _lastAuthTime = null;
  }

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    if (Platform.isLinux) {
      return false; // Native local_auth plugin not present on Linux desktop
    }
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb || Platform.isLinux) {
      return [];
    }
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isBiometricsAvailable() async {
    if (kIsWeb || Platform.isLinux) {
      return false;
    }
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty || canCheck;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate({
    BuildContext? context,
    required String reason,
  }) async {
    if (_isAuthenticating) {
      debugPrint('[BiometricService] Suppressing duplicate concurrent authentication call.');
      return false;
    }
    _isAuthenticating = true;
    try {
      return await _executeAuthenticate(context: context, reason: reason);
    } finally {
      _lastAuthTime = DateTime.now();
      _isAuthenticating = false;
    }
  }

  Future<bool> _executeAuthenticate({
    BuildContext? context,
    required String reason,
  }) async {
    final bioAvailable = await isBiometricsAvailable();

    // 1. Native local_auth on supported mobile & desktop platforms with hardware sensor
    if (bioAvailable && !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows)) {
      try {
        final result = await _auth.authenticate(
          localizedReason: reason,
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        return result;
      } catch (bioOnlyErr) {
        debugPrint('[BiometricService] biometricOnly failed ($bioOnlyErr).');
        final errStr = bioOnlyErr.toString().toLowerCase();
        if (errStr.contains('usercanceled') ||
            errStr.contains('cancel') ||
            errStr.contains('authinprogress') ||
            errStr.contains('notavailable')) {
          return false;
        }
        try {
          final result = await _auth.authenticate(
            localizedReason: reason,
            biometricOnly: false,
            persistAcrossBackgrounding: true,
          );
          return result;
        } catch (fallbackErr) {
          debugPrint('[BiometricService] Device credential fallback failed: $fallbackErr');
          return false;
        }
      }
    }

    // 2. If fingerprint reader is NOT available:
    // DO NOT show modal verifikasi sidik jari! Directly use PIN!
    final targetContext = context ?? navigatorKey?.currentContext ?? rootNavigatorKey.currentContext;
    if (targetContext != null && targetContext.mounted) {
      try {
        final settings = Provider.of<SettingsProvider>(targetContext, listen: false);
        if (settings.hasPin) {
          return await PinAuthScreen.verify(targetContext, reason: reason);
        } else {
          return await PinAuthScreen.setup(targetContext);
        }
      } catch (e) {
        debugPrint('[BiometricService] PIN Screen error: $e');
        return false;
      }
    }

    // 3. Fallback for headless CLI unit tests where no UI context is mounted
    return true;
  }
}
