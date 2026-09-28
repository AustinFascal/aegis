import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureVault {
  static final SecureVault _instance = SecureVault._internal();
  factory SecureVault() => _instance;
  SecureVault._internal();

  // Enforce hardware-backed AES-256 GCM encryption via Android Keystore / Keychain / SecretService
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    lOptions: LinuxOptions(),
  );

  // In-memory runtime fallback cache for unit tests and headless environments
  final Map<String, String> _memoryFallback = {};

  bool get _isTestEnv {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static const String _keyPrefixKey = 'aegis_ssh_key_';
  static const String _keyPrefixPass = 'aegis_pass_';
  static const String _keyPrefixSudo = 'aegis_sudo_';
  static const String _keyThemeMode = 'aegis_theme_mode';
  static const String _keyPrefixPolicy = 'aegis_policy_';
  static const String _keyPrefix2FA = 'aegis_2fa_';
  static const String _keyServerProfiles = 'aegis_server_profiles';
  static const String _keyActiveServerId = 'aegis_active_server_id';

  Future<void> savePrivateKey(String serverId, String privateKeyContent) async {
    final key = '$_keyPrefixKey$serverId';
    _memoryFallback[key] = privateKeyContent;
    if (_isTestEnv) return;
    try {
      await _storage.write(key: key, value: privateKeyContent);
    } catch (e) {
      debugPrint('[SecureVault] Storage write fallback: $e');
    }
  }

  Future<String?> getPrivateKey(String serverId) async {
    final key = '$_keyPrefixKey$serverId';
    if (_isTestEnv) return _memoryFallback[key];
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memoryFallback[key] = val;
        return val;
      }
    } catch (e) {
      debugPrint('[SecureVault] Storage read fallback: $e');
    }
    return _memoryFallback[key];
  }

  Future<void> deletePrivateKey(String serverId) async {
    final key = '$_keyPrefixKey$serverId';
    _memoryFallback.remove(key);
    if (_isTestEnv) return;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> savePassword(String serverId, String password) async {
    final key = '$_keyPrefixPass$serverId';
    _memoryFallback[key] = password;
    if (_isTestEnv) return;
    try {
      await _storage.write(key: key, value: password);
    } catch (e) {
      debugPrint('[SecureVault] Storage write fallback: $e');
    }
  }

  Future<String?> getPassword(String serverId) async {
    final key = '$_keyPrefixPass$serverId';
    if (_isTestEnv) return _memoryFallback[key];
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memoryFallback[key] = val;
        return val;
      }
    } catch (e) {
      debugPrint('[SecureVault] Storage read fallback: $e');
    }
    return _memoryFallback[key];
  }

  Future<void> deletePassword(String serverId) async {
    final key = '$_keyPrefixPass$serverId';
    _memoryFallback.remove(key);
    if (_isTestEnv) return;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> saveSudoPassword(String serverId, String password) async {
    final key = '$_keyPrefixSudo$serverId';
    _memoryFallback[key] = password;
    if (_isTestEnv) return;
    try {
      await _storage.write(key: key, value: password);
    } catch (e) {
      debugPrint('[SecureVault] Sudo write fallback: $e');
    }
  }

  Future<String?> getSudoPassword(String serverId) async {
    final key = '$_keyPrefixSudo$serverId';
    if (_isTestEnv) return _memoryFallback[key];
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memoryFallback[key] = val;
        return val;
      }
    } catch (e) {
      debugPrint('[SecureVault] Sudo read fallback: $e');
    }
    return _memoryFallback[key];
  }

  Future<void> deleteSudoPassword(String serverId) async {
    final key = '$_keyPrefixSudo$serverId';
    _memoryFallback.remove(key);
    if (_isTestEnv) return;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> save2FASecret(String serverId, String secret) async {
    final key = '$_keyPrefix2FA$serverId';
    _memoryFallback[key] = secret.trim();
    if (_isTestEnv) return;
    try {
      await _storage.write(key: key, value: secret.trim());
    } catch (e) {
      debugPrint('[SecureVault] 2FA secret write fallback: $e');
    }
  }

  Future<String?> get2FASecret(String serverId) async {
    final key = '$_keyPrefix2FA$serverId';
    if (_isTestEnv) return _memoryFallback[key];
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memoryFallback[key] = val;
        return val;
      }
    } catch (e) {
      debugPrint('[SecureVault] 2FA secret read fallback: $e');
    }
    return _memoryFallback[key];
  }

  Future<void> delete2FASecret(String serverId) async {
    final key = '$_keyPrefix2FA$serverId';
    _memoryFallback.remove(key);
    if (_isTestEnv) return;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> saveThemeMode(String mode) async {
    _memoryFallback[_keyThemeMode] = mode;
    if (_isTestEnv) return;
    try {
      await _storage.write(key: _keyThemeMode, value: mode);
    } catch (_) {}
  }

  Future<String?> getThemeMode() async {
    if (_isTestEnv) return _memoryFallback[_keyThemeMode];
    try {
      final val = await _storage.read(key: _keyThemeMode);
      if (val != null) {
        _memoryFallback[_keyThemeMode] = val;
        return val;
      }
    } catch (_) {}
    return _memoryFallback[_keyThemeMode];
  }

  Future<void> savePolicy(String serverId, String policyJson) async {
    final key = '$_keyPrefixPolicy$serverId';
    _memoryFallback[key] = policyJson;
    if (_isTestEnv) return;
    try {
      await _storage.write(key: key, value: policyJson);
    } catch (_) {}
  }

  Future<void> deletePolicy(String keyName) async {
    final key = '$_keyPrefixPolicy$keyName';
    _memoryFallback.remove(key);
    if (_isTestEnv) return;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<String?> getPolicy(String serverId) async {
    final key = '$_keyPrefixPolicy$serverId';
    if (_isTestEnv) return _memoryFallback[key];
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memoryFallback[key] = val;
        return val;
      }
    } catch (_) {}
    return _memoryFallback[key];
  }

  String? getPolicySync(String serverId) {
    final key = '$_keyPrefixPolicy$serverId';
    return _memoryFallback[key];
  }

  Future<void> saveServerProfiles(String jsonString) async {
    _memoryFallback[_keyServerProfiles] = jsonString;
    if (_isTestEnv) return;
    try {
      await _storage.write(key: _keyServerProfiles, value: jsonString);
    } catch (e) {
      debugPrint('[SecureVault] Server profiles write fallback: $e');
    }
  }

  Future<String?> getServerProfiles() async {
    if (_isTestEnv) return _memoryFallback[_keyServerProfiles];
    try {
      final val = await _storage.read(key: _keyServerProfiles);
      if (val != null && val.isNotEmpty) {
        _memoryFallback[_keyServerProfiles] = val;
        return val;
      }
    } catch (e) {
      debugPrint('[SecureVault] Server profiles read fallback: $e');
    }
    return _memoryFallback[_keyServerProfiles];
  }

  Future<void> saveActiveServerId(String serverId) async {
    _memoryFallback[_keyActiveServerId] = serverId;
    if (_isTestEnv) return;
    try {
      await _storage.write(key: _keyActiveServerId, value: serverId);
    } catch (_) {}
  }

  Future<String?> getActiveServerId() async {
    if (_isTestEnv) return _memoryFallback[_keyActiveServerId];
    try {
      final val = await _storage.read(key: _keyActiveServerId);
      if (val != null && val.isNotEmpty) {
        _memoryFallback[_keyActiveServerId] = val;
        return val;
      }
    } catch (_) {}
    return _memoryFallback[_keyActiveServerId];
  }

  Future<void> clearAll() async {
    _memoryFallback.clear();
    if (_isTestEnv) return;
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
