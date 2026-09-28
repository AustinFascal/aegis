import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../core/security/secure_vault.dart';

class SettingsProvider extends ChangeNotifier {
  final SecureVault _vault = SecureVault();

  // Indonesian as the primary default language
  String _language = 'id'; // 'id' (Default) or 'en'
  String _operatorName = 'Guest User';
  String _operatorEmail = '';
  String _operatorPhone = '';
  bool _isGuest = true;
  bool _isOnboardingCompleted = false;

  final String _operatorTenant = 'Company';
  int _autoPollingInterval = 30; // seconds, 0 = manual
  bool _soundAlerts = true;
  bool _biometricLock = false;
  String? _appPin;
  String? _abuseIpDbApiKey;
  bool _isLoaded = false;
  final String _hardwareFingerprint = 'N/A';
  final DateTime _sessionStart = DateTime.now();

  String get language => _language;
  bool get isIndonesian => _language == 'id';
  String get operatorName => _operatorName;
  String get operatorEmail => _operatorEmail;
  String get operatorPhone => _operatorPhone;
  bool get isGuest => _isGuest;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  String get operatorTenant => _operatorTenant;
  int get autoPollingInterval => _autoPollingInterval;
  bool get soundAlerts => _soundAlerts;
  bool get biometricLock => _biometricLock;
  bool get hasPin => _appPin != null && _appPin!.isNotEmpty;
  bool get isSecurityLockActive => (_biometricLock || hasPin);
  bool get isLoaded => _isLoaded;
  String? get appPin => _appPin;
  String? get abuseIpDbApiKey => _abuseIpDbApiKey;
  bool get hasAbuseIpDbApiKey =>
      _abuseIpDbApiKey != null && _abuseIpDbApiKey!.trim().isNotEmpty;
  String get hardwareFingerprint => _hardwareFingerprint;
  DateTime get sessionStart => _sessionStart;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final savedLang = await _vault.getPolicy('settings_lang');
      if (savedLang != null && (savedLang == 'en' || savedLang == 'id')) {
        _language = savedLang;
      }

      final savedOnboard = await _vault.getPolicy(
        'settings_onboarding_completed',
      );
      if (savedOnboard == 'true') {
        _isOnboardingCompleted = true;
      }

      final savedName = await _vault.getPolicy('settings_name');
      if (savedName != null && savedName.isNotEmpty) {
        _operatorName = savedName;
      }

      final savedEmail = await _vault.getPolicy('settings_email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _operatorEmail = savedEmail;
      }

      final savedPhone = await _vault.getPolicy('settings_phone');
      if (savedPhone != null && savedPhone.isNotEmpty) {
        _operatorPhone = savedPhone;
      }

      final savedGuest = await _vault.getPolicy('settings_is_guest');
      if (savedGuest != null) {
        _isGuest = savedGuest == 'true';
      } else {
        _isGuest = _operatorName == 'Guest User';
      }

      final savedPoll = await _vault.getPolicy('settings_poll_rate');
      if (savedPoll != null) {
        final parsed = int.tryParse(savedPoll);
        if (parsed != null) _autoPollingInterval = parsed;
      }

      final savedSound = await _vault.getPolicy('settings_sound');
      if (savedSound != null) {
        _soundAlerts = savedSound == 'true';
      }

      final savedBio = await _vault.getPolicy('settings_biometric');
      if (savedBio != null) {
        _biometricLock = savedBio == 'true';
      }

      final savedPin = await _vault.getPolicy('settings_app_pin');
      if (savedPin != null && savedPin.isNotEmpty) {
        _appPin = savedPin;
      }

      final savedAbuseKey = await _vault.getPolicy('settings_abuseipdb_key');
      if (savedAbuseKey != null && savedAbuseKey.trim().isNotEmpty) {
        _abuseIpDbApiKey = savedAbuseKey.trim();
      }

      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      _isLoaded = true;
    }
  }

  Future<void> init() async {
    await _loadSettings();
  }

  Future<bool> setAppPin(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.length != 6 || int.tryParse(cleanPin) == null) {
      return false;
    }
    final hash = sha256.convert(utf8.encode(cleanPin)).toString();
    _appPin = hash;
    await _vault.savePolicy('settings_app_pin', hash);
    notifyListeners();
    return true;
  }

  Future<bool> verifyAppPin(String pin) async {
    if (_appPin == null || _appPin!.isEmpty) return false;
    final hash = sha256.convert(utf8.encode(pin.trim())).toString();
    return hash == _appPin;
  }

  Future<void> removeAppPin() async {
    _appPin = null;
    await _vault.savePolicy('settings_app_pin', '');
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (lang != _language && (lang == 'en' || lang == 'id')) {
      _language = lang;
      await _vault.savePolicy('settings_lang', lang);
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final trimmedName = name.trim();
    _operatorName = trimmedName.isEmpty ? 'Guest User' : trimmedName;
    _operatorEmail = email.trim();
    _operatorPhone = phone.trim();
    _isGuest = _operatorName == 'Guest User';
    notifyListeners();

    await _vault.savePolicy('settings_name', _operatorName);
    await _vault.savePolicy('settings_email', _operatorEmail);
    await _vault.savePolicy('settings_phone', _operatorPhone);
    await _vault.savePolicy('settings_is_guest', _isGuest.toString());
  }

  Future<void> logout() async {
    _operatorName = 'Guest User';
    _operatorEmail = '';
    _operatorPhone = '';
    _isGuest = true;
    notifyListeners();

    await _vault.deletePolicy('settings_name');
    await _vault.deletePolicy('settings_email');
    await _vault.deletePolicy('settings_phone');
    await _vault.deletePolicy('settings_is_guest');
  }

  Future<void> resetAllSettings() async {
    _language = 'id';
    _operatorName = 'Guest User';
    _operatorEmail = '';
    _operatorPhone = '';
    _isGuest = true;
    _isOnboardingCompleted = false;
    _autoPollingInterval = 30;
    _soundAlerts = true;
    _biometricLock = false;
    _appPin = null;
    _abuseIpDbApiKey = null;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String name,
    required String email,
    required String phone,
  }) async {
    final trimmedName = name.trim();
    _operatorName = trimmedName.isEmpty ? 'Guest User' : trimmedName;
    _operatorEmail = email.trim();
    _operatorPhone = phone.trim();
    _isGuest = _operatorName == 'Guest User';
    _isOnboardingCompleted = true;
    notifyListeners();

    await _vault.savePolicy('settings_onboarding_completed', 'true');
    await _vault.savePolicy('settings_name', _operatorName);
    await _vault.savePolicy('settings_email', _operatorEmail);
    await _vault.savePolicy('settings_phone', _operatorPhone);
    await _vault.savePolicy('settings_is_guest', _isGuest.toString());
  }

  Future<void> skipOnboarding() async {
    _operatorName = 'Guest User';
    _operatorEmail = '';
    _operatorPhone = '';
    _isGuest = true;
    _isOnboardingCompleted = true;
    notifyListeners();

    await _vault.savePolicy('settings_onboarding_completed', 'true');
    await _vault.savePolicy('settings_name', 'Guest User');
    await _vault.savePolicy('settings_email', '');
    await _vault.savePolicy('settings_phone', '');
    await _vault.savePolicy('settings_is_guest', 'true');
  }

  Future<void> resetOnboarding() async {
    _isOnboardingCompleted = false;
    await _vault.savePolicy('settings_onboarding_completed', 'false');
    notifyListeners();
  }

  Future<void> setAutoPollingInterval(int seconds) async {
    _autoPollingInterval = seconds;
    await _vault.savePolicy('settings_poll_rate', seconds.toString());
    notifyListeners();
  }

  Future<void> setSoundAlerts(bool enabled) async {
    _soundAlerts = enabled;
    await _vault.savePolicy('settings_sound', enabled.toString());
    notifyListeners();
  }

  Future<void> setBiometricLock(bool enabled) async {
    _biometricLock = enabled;
    await _vault.savePolicy('settings_biometric', enabled.toString());
    notifyListeners();
  }

  Future<void> setAbuseIpDbApiKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) {
      _abuseIpDbApiKey = null;
      await _vault.deletePolicy('settings_abuseipdb_key');
    } else {
      _abuseIpDbApiKey = clean;
      await _vault.savePolicy('settings_abuseipdb_key', clean);
    }
    notifyListeners();
  }

  Future<void> removeAbuseIpDbApiKey() async {
    _abuseIpDbApiKey = null;
    await _vault.deletePolicy('settings_abuseipdb_key');
    notifyListeners();
  }

  /// Bilingual dictionary translation lookup
  String t(String key) {
    final Map<String, Map<String, String>> dict = {
      'nav_dashboard': {'id': 'Dashboard', 'en': 'Dashboard'},
      'nav_services': {'id': 'Layanan', 'en': 'Services'},
      'nav_audit': {'id': 'Log Audit', 'en': 'Audit Log'},
      'nav_policies': {'id': 'Kebijakan', 'en': 'Policies'},
      'nav_servers': {'id': 'Server', 'en': 'Servers'},
      'nav_settings': {'id': 'Pengaturan', 'en': 'Settings'},
      'settings_title': {
        'id': 'PENGATURAN SISTEM & KEAMANAN',
        'en': 'SYSTEM & SECURITY SETTINGS',
      },
      'appearance_heading': {
        'id': 'TAMPILAN & TEMA',
        'en': 'APPEARANCE & THEME',
      },
      'language_heading': {
        'id': 'BAHASA & LOKALISASI',
        'en': 'LANGUAGE & LOCALIZATION',
      },
      'profile_heading': {
        'id': 'PROFIL OPERATOR KEAMANAN',
        'en': 'SECURITY OPERATOR PROFILE',
      },
      'legal_heading': {
        'id': 'HUKUM, PRIVASI & KEPATUHAN',
        'en': 'LEGAL, PRIVACY & COMPLIANCE',
      },
      'privacy_policy_title': {
        'id': 'Kebijakan Privasi & Perlindungan Data',
        'en': 'Privacy & Data Protection Policy',
      },
      'privacy_policy_sub': {
        'id': 'Vault lokal AES-256, tanpa pengiriman data telemetri keluar',
        'en': 'Local hardware AES-256 vault, zero outbound telemetry',
      },
      'terms_of_service_title': {
        'id': 'Syarat Layanan & Otorisasi Penggunaan',
        'en': 'Terms of Service & Authorization',
      },
      'terms_of_service_sub': {
        'id': 'Ruang lingkup operator & jaminan pemantauan non-destruktif',
        'en': 'Authorized operator scope & non-destructive monitoring',
      },
      'theme_dark': {'id': 'Mode Cyber Dark', 'en': 'Cyber Dark Mode'},
      'theme_light': {'id': 'Mode Cyber Terang', 'en': 'Cyber Light Mode'},
      'polling_rate': {
        'id': 'Frekuensi Polling Telemetri',
        'en': 'Telemetry Polling Interval',
      },
      'monitored_services': {
        'id': 'LAYANAN INFRASTRUKTUR TERDETEKSI',
        'en': 'DETECTED INFRASTRUCTURE SERVICES',
      },
      'all_logs': {'id': 'SEMUA LOG →', 'en': 'ALL LOGS →'},
      'deep_dive': {'id': 'ANALISIS LENGKAP →', 'en': 'DEEP DIVE →'},
      'test_poll': {'id': 'Tes & Perbarui Server', 'en': 'Test & Poll Server'},
      'failed_logins': {'id': 'LOGIN GAGAL', 'en': 'FAILED LOGINS'},
      'unknown_logins': {'id': 'LOGIN TAK DIKENAL', 'en': 'UNKNOWN LOGINS'},
      'blocked_attempts': {'id': 'UPAYA DIBLOKIR', 'en': 'BLOCKED ATTEMPTS'},
      'security_index': {'id': 'SKOR INTEGRITAS', 'en': 'SECURITY INDEX'},
      'threat_intel_heading': {
        'id': 'INTELIJEN ANCAMAN & REPUTASI IP (ABUSEIPDB)',
        'en': 'THREAT INTELLIGENCE & IP REPUTATION (ABUSEIPDB)',
      },
      'threat_intel_sub': {
        'id': 'Deteksi reputasi IP global, node Tor, dan riwayat botnet',
        'en':
            'Detect global IP abuse scores, Tor exit nodes, and botnet history',
      },
    };

    return dict[key]?[_language] ?? dict[key]?['id'] ?? key;
  }
}
