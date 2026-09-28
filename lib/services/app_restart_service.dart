import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:restart_app/restart_app.dart';
import '../main.dart';

/// Multi-platform application restart service for Aegis.
///
/// Handles native process restarts on Desktop (Linux, Windows, macOS),
/// mobile activity/engine restarts (Android, iOS), Web reload, and
/// clean in-app state resets as universal fallback.
class AppRestartService {
  static bool get isTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Restarts the application on the current platform.
  static Future<void> restart() async {
    // 1. In test environments, never spawn external processes or exit; do in-app restart
    if (isTestEnvironment) {
      debugPrint('[AppRestartService] Test environment detected. Resetting in-app state.');
      AegisRoot.restartApp();
      return;
    }

    // 2. Web: Reload browser page at current URL
    if (kIsWeb) {
      try {
        await Restart.restartApp();
        return;
      } catch (e) {
        debugPrint('[AppRestartService] Web restart error: $e');
        AegisRoot.restartApp();
        return;
      }
    }

    // 3. Linux: Use native detached Process.start with resolved executable
    if (Platform.isLinux) {
      try {
        final executable = Platform.resolvedExecutable;
        final rawArgs = Platform.executableArguments;

        // Strip debugger/observatory flags if launched via flutter run
        final cleanArgs = rawArgs.where((arg) =>
          !arg.startsWith('--observatory-port') &&
          !arg.startsWith('--vm-service-port') &&
          !arg.startsWith('--vmservice-out-file') &&
          !arg.startsWith('--enable-checked-mode')
        ).toList();

        debugPrint('[AppRestartService] Restarting Linux process: $executable $cleanArgs');
        await Process.start(
          executable,
          cleanArgs,
          mode: ProcessStartMode.detached,
        );
        debugPrint('[AppRestartService] Linux child process spawned. Exiting current process.');
        exit(0);
      } catch (e) {
        debugPrint('[AppRestartService] Linux native process restart error: $e. Falling back to in-app reset.');
        AegisRoot.restartApp();
        return;
      }
    }

    // 4. Windows: Try restart_app plugin, fallback to detached Process.start
    if (Platform.isWindows) {
      try {
        final result = await Restart.restartApp(mode: RestartMode.process);
        if (result.success) return;
      } catch (e) {
        debugPrint('[AppRestartService] Windows Restart.restartApp error: $e');
      }

      try {
        final executable = Platform.resolvedExecutable;
        final rawArgs = Platform.executableArguments;
        final cleanArgs = rawArgs.where((arg) =>
          !arg.startsWith('--observatory-port') &&
          !arg.startsWith('--vm-service-port')
        ).toList();

        debugPrint('[AppRestartService] Restarting Windows process: $executable');
        await Process.start(
          executable,
          cleanArgs,
          mode: ProcessStartMode.detached,
        );
        exit(0);
      } catch (e) {
        debugPrint('[AppRestartService] Windows process fallback error: $e');
        AegisRoot.restartApp();
        return;
      }
    }

    // 5. macOS: Try restart_app plugin, fallback to 'open -n'
    if (Platform.isMacOS) {
      try {
        final result = await Restart.restartApp();
        if (result.success) return;
      } catch (e) {
        debugPrint('[AppRestartService] macOS Restart.restartApp error: $e');
      }

      try {
        final executable = Platform.resolvedExecutable;
        debugPrint('[AppRestartService] Restarting macOS process via open -n: $executable');
        await Process.start(
          'open',
          ['-n', executable],
          mode: ProcessStartMode.detached,
        );
        exit(0);
      } catch (e) {
        debugPrint('[AppRestartService] macOS open -n fallback error: $e');
        AegisRoot.restartApp();
        return;
      }
    }

    // 6. Android: Use restart_app process restart
    if (Platform.isAndroid) {
      try {
        final result = await Restart.restartApp(
          mode: RestartMode.process,
          forceKill: true,
        );
        if (result.success) return;
      } catch (e) {
        debugPrint('[AppRestartService] Android restart error: $e');
      }
      AegisRoot.restartApp();
      return;
    }

    // 7. iOS: Use restart_app or in-app restart (App Store prohibits exit(0))
    if (Platform.isIOS) {
      try {
        final result = await Restart.restartApp();
        if (result.success) return;
      } catch (e) {
        debugPrint('[AppRestartService] iOS restart error: $e');
      }
      AegisRoot.restartApp();
      return;
    }

    // 8. General Fallback
    debugPrint('[AppRestartService] General fallback: resetting in-app state.');
    AegisRoot.restartApp();
  }
}
