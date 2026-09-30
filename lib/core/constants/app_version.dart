import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Centralized application version utility.
/// Dynamically resolves the version from:
/// 1. Compile-time `--dart-define=APP_VERSION=...` (injected in CI / build)
/// 2. Platform package metadata via `package_info_plus` (reads pubspec.yaml / native manifest)
/// 3. Safe fallback ('v1.0.0')
class AppVersion {
  // Compile-time environment variable (e.g. --dart-define=APP_VERSION=v1.0.1)
  static const String _envVersion = String.fromEnvironment('APP_VERSION');

  static String _version = '1.0.0';
  static String _buildNumber = '1';
  static bool _initialized = false;

  /// Returns version formatted with leading 'v' (e.g. 'v1.0.0' or 'v1.1.2')
  static String get formatted {
    if (_envVersion.isNotEmpty) {
      return _envVersion.startsWith('v') ? _envVersion : 'v$_envVersion';
    }
    return _version.startsWith('v') ? _version : 'v$_version';
  }

  /// Raw version string without leading 'v' (e.g. '1.0.0')
  static String get rawVersion {
    final v = formatted;
    return v.startsWith('v') ? v.substring(1) : v;
  }

  /// Application build number (e.g. '1' or '42')
  static String get buildNumber => _buildNumber;

  /// Full display string including build number (e.g. 'v1.0.0+1')
  static String get fullDisplay => '$formatted+$_buildNumber';

  /// Asynchronously loads version and build number from platform package info.
  static Future<void> init() async {
    if (_initialized) return;

    if (_envVersion.isNotEmpty) {
      _version = _envVersion.startsWith('v') ? _envVersion.substring(1) : _envVersion;
    }

    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        if (_envVersion.isEmpty) {
          _version = info.version;
        }
        _buildNumber = info.buildNumber;
      }
    } catch (e) {
      debugPrint('[AppVersion] Platform PackageInfo unavailable, using fallback: $e');
    } finally {
      _initialized = true;
    }
  }
}
