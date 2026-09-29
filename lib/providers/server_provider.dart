import '../models/security_policy.dart';
import '../models/auth_event.dart';
import '../services/log_parser_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/server_profile.dart';
import '../core/security/secure_vault.dart';
import '../services/ssh_service.dart';
import '../core/constants/service_registry.dart';
import '../main.dart';
import '../ui/widgets/two_factor_auth_dialog.dart';

class ServerProvider extends ChangeNotifier {
  final SecureVault _vault = SecureVault();
  final SshService _sshService = SshService();

  List<ServerProfile> _servers = [];
  String? _activeServerId;
  bool _isLoading = false;
  String? _errorMessage;

  // Track whether credentials exist in hardware vault for each server
  final Map<String, bool> _vaultStatus = {};
  final Map<String, bool> _sudoStatus = {};

  List<ServerProfile> get servers => List.unmodifiable(_servers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ServerProfile? get activeServer {
    if (_servers.isEmpty) return null;
    if (_activeServerId == null) {
      return _servers.first;
    }
    return _servers.firstWhere(
      (s) => s.id == _activeServerId,
      orElse: () => _servers.first,
    );
  }

  bool hasStoredCredential(String serverId) {
    return _vaultStatus[serverId] ?? false;
  }

  bool hasStoredSudoPassword(String serverId) {
    return _sudoStatus[serverId] ?? false;
  }

  bool isServerConnected(String serverId) {
    return _sshService.isConnected(serverId);
  }

  Future<void> disconnectServer(String serverId) async {
    await _sshService.disconnect(serverId);
    notifyListeners();
  }

  Future<String?> getCredentialForServer(ServerProfile server) async {
    String? credential = server.authType == AuthType.privateKey
        ? await _vault.getPrivateKey(server.id)
        : await _vault.getPassword(server.id);

    if ((credential == null || credential.trim().isEmpty) && server.id == 'srv_rumahweb_01') {
      const localKeyPath = '/home/austin/Web Dev/Projects/cethokaryo/RumahWeb';
      final keyFile = File(localKeyPath);
      if (await keyFile.exists()) {
        final content = await keyFile.readAsString();
        if (content.trim().isNotEmpty) {
          credential = content.trim();
          await _vault.savePrivateKey(server.id, credential);
          _vaultStatus[server.id] = true;
        }
      }
    }
    return credential;
  }

  Future<String?> get2FASecretForServer(ServerProfile server) async {
    return _vault.get2FASecret(server.id);
  }

  static const ServerProfile defaultVps = ServerProfile(
    id: 'srv_rumahweb_01',
    name: 'RumahWeb VPS (CethoKaryo)',
    host: '202.10.46.4',
    port: 22,
    username: 'cethokaryo',
    authType: AuthType.privateKey,
    monitoredServices: [
      'mysqld',
      'sshd',
      'httpd',
      'nginx',
      'redis-server',
      'php-fpm',
      'node',
      'ollama',
      'dovecot',
      'exim',
      'pure-ftpd',
      'named',
    ],
    serviceStatuses: {
      'mysqld': true,
      'sshd': true,
      'httpd': true,
      'nginx': true,
      'redis-server': true,
      'php-fpm': true,
      'node': true,
      'ollama': true,
      'dovecot': true,
      'exim': true,
      'pure-ftpd': true,
      'named': true,
    },
    isConnected: true,
    osInfo: 'CloudLinux/CentOS (3.10.0-1160)',
    uptime: 'up 18 days',
  );

  File? _getConfigFile() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        final dir = Directory('$home/.config/aegis');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/servers.json');
      }
    } catch (e) {
      debugPrint('[ServerProvider] Config dir access: $e');
    }
    return null;
  }

  Future<void> _persistServers() async {
    try {
      final list = _servers.map((s) => s.toMap()).toList();
      final jsonStr = json.encode(list);
      await _vault.saveServerProfiles(jsonStr);

      if (_activeServerId != null) {
        await _vault.saveActiveServerId(_activeServerId!);
      }

      final file = _getConfigFile();
      if (file != null) {
        await file.writeAsString(jsonStr);
      }
    } catch (e) {
      debugPrint('[ServerProvider] Persist servers error: $e');
    }
  }

  Future<void> _loadPersistedServers() async {
    try {
      String? jsonStr = await _vault.getServerProfiles();
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        final file = _getConfigFile();
        if (file != null && await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isNotEmpty) {
            jsonStr = content;
          }
        }
      }

      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        final loadedServers = decoded
            .map((item) => ServerProfile.fromMap(item as Map<String, dynamic>))
            .toList();

        if (loadedServers.isNotEmpty) {
          final existingIds = _servers.map((s) => s.id).toSet();
          for (final s in loadedServers) {
            if (!existingIds.contains(s.id)) {
              _servers.add(s);
            }
          }
        }
      }

      final savedActiveId = await _vault.getActiveServerId();
      if (savedActiveId != null && _servers.any((s) => s.id == savedActiveId)) {
        if (_activeServerId == null || _activeServerId == defaultVps.id) {
          _activeServerId = savedActiveId;
        }
      }
    } catch (e) {
      debugPrint('[ServerProvider] Load persisted servers error: $e');
    }

    notifyListeners();
    await _autoSeedAndCheckCredentials();
  }

  ServerProvider({List<ServerProfile>? initialServers}) {
    if (initialServers != null) {
      _servers = List.from(initialServers);
      _activeServerId = _servers.isNotEmpty ? _servers.first.id : null;
    } else {
      _initializeDefaultServers();
    }
  }

  void _initializeDefaultServers() {
    // First install: start with no servers so user can add and setup manually
    _servers = [];
    _activeServerId = null;

    _loadPersistedServers();
  }

  Future<void> _autoSeedAndCheckCredentials() async {
    try {
      final existingKey = await _vault.getPrivateKey('srv_rumahweb_01');
      if (existingKey == null || existingKey.trim().isEmpty) {
        // Known local OpenSSH key path on the developer's system
        const localKeyPath = '/home/austin/Web Dev/Projects/cethokaryo/RumahWeb';
        final keyFile = File(localKeyPath);
        if (await keyFile.exists()) {
          final content = await keyFile.readAsString();
          if (content.trim().isNotEmpty) {
            await _vault.savePrivateKey('srv_rumahweb_01', content.trim());
            debugPrint('[ServerProvider] Auto-seeded RumahWeb private key into vault.');
          }
        }
      }
    } catch (e) {
      debugPrint('[ServerProvider] Key auto-seeding notice: $e');
    }

    await refreshCredentialStatus();
  }

  Future<void> refreshCredentialStatus() async {
    for (final server in List<ServerProfile>.from(_servers)) {
      try {
        final cred = server.authType == AuthType.privateKey
            ? await _vault.getPrivateKey(server.id)
            : await _vault.getPassword(server.id);
        _vaultStatus[server.id] = (cred != null && cred.trim().isNotEmpty);
      } catch (_) {
        _vaultStatus[server.id] = false;
      }
      try {
        final sudo = await _vault.getSudoPassword(server.id);
        _sudoStatus[server.id] = (sudo != null && sudo.trim().isNotEmpty);
      } catch (_) {
        _sudoStatus[server.id] = false;
      }
    }
    notifyListeners();
  }

  void selectServer(String serverId) {
    if (_activeServerId != serverId) {
      _activeServerId = serverId;
      _vault.saveActiveServerId(serverId);
      notifyListeners();
    }
  }

  Future<void> saveCredential(String serverId, AuthType authType, String credential) async {
    if (authType == AuthType.privateKey) {
      await _vault.savePrivateKey(serverId, credential.trim());
    } else {
      await _vault.savePassword(serverId, credential.trim());
    }
    _vaultStatus[serverId] = credential.trim().isNotEmpty;
    notifyListeners();
  }

  Future<void> addServer({
    required String name,
    required String host,
    required int port,
    required String username,
    required AuthType authType,
    required String credential,
    List<String> monitoredServices = const ['mysqld', 'sshd'],
    bool has2FA = false,
    String? twoFactorSecret,
    String? sudoPassword,
  }) async {
    final newId = 'srv_${const Uuid().v4().substring(0, 8)}';
    final profile = ServerProfile(
      id: newId,
      name: name,
      host: host,
      port: port,
      username: username,
      authType: authType,
      monitoredServices: monitoredServices,
      isConnected: false,
      has2FA: has2FA,
    );

    if (credential.trim().isNotEmpty) {
      await saveCredential(newId, authType, credential);
    }
    if (has2FA && twoFactorSecret != null && twoFactorSecret.trim().isNotEmpty) {
      await _vault.save2FASecret(newId, twoFactorSecret.trim());
    }
    if (sudoPassword != null && sudoPassword.trim().isNotEmpty) {
      await _vault.saveSudoPassword(newId, sudoPassword.trim());
    }

    _servers.add(profile);
    _activeServerId = newId;
    await _persistServers();
    await refreshCredentialStatus();
    notifyListeners();
  }

  Future<void> updateServer(
    ServerProfile updated, [
    String? newCredential,
    String? newTwoFactorSecret,
    String? newSudoPassword,
  ]) async {
    final index = _servers.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _servers[index] = updated;

      if (newCredential != null && newCredential.trim().isNotEmpty) {
        await saveCredential(updated.id, updated.authType, newCredential.trim());
        await _sshService.disconnect(updated.id);
      }

      if (newTwoFactorSecret != null && newTwoFactorSecret.trim().isNotEmpty) {
        await _vault.save2FASecret(updated.id, newTwoFactorSecret.trim());
      } else if (!updated.has2FA) {
        await _vault.delete2FASecret(updated.id);
      }

      if (newSudoPassword != null && newSudoPassword.trim().isNotEmpty) {
        await _vault.saveSudoPassword(updated.id, newSudoPassword.trim());
      }

      await refreshCredentialStatus();
      notifyListeners();
    }
  }

  Future<void> deleteServer(String serverId) async {
    await _sshService.disconnect(serverId);
    _servers.removeWhere((s) => s.id == serverId);
    _vaultStatus.remove(serverId);
    _sudoStatus.remove(serverId);
    await _vault.deletePrivateKey(serverId);
    await _vault.deletePassword(serverId);
    await _vault.delete2FASecret(serverId);
    await _vault.deleteSudoPassword(serverId);

    if (_activeServerId == serverId) {
      _activeServerId = _servers.isNotEmpty ? _servers.first.id : null;
    }
    await _persistServers();
    notifyListeners();
  }

  Future<void> clearAllServers() async {
    await _sshService.closeAll();
    for (final s in _servers) {
      await _vault.deletePrivateKey(s.id);
      await _vault.deletePassword(s.id);
      await _vault.delete2FASecret(s.id);
      await _vault.deleteSudoPassword(s.id);
    }
    _servers.clear();
    _vaultStatus.clear();
    _sudoStatus.clear();
    _activeServerId = null;
    await _persistServers();
    notifyListeners();
  }

  /// Tests SSH connection for a specific server profile
  Future<SshTestResult> testServer(
    ServerProfile server, {
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? credential = server.authType == AuthType.privateKey
          ? await _vault.getPrivateKey(server.id)
          : await _vault.getPassword(server.id);

      // On-demand fallback check for default RumahWeb key if not yet in vault
      if ((credential == null || credential.trim().isEmpty) && server.id == 'srv_rumahweb_01') {
        const localKeyPath = '/home/austin/Web Dev/Projects/cethokaryo/RumahWeb';
        final keyFile = File(localKeyPath);
        if (await keyFile.exists()) {
          final content = await keyFile.readAsString();
          if (content.trim().isNotEmpty) {
            credential = content.trim();
            await _vault.savePrivateKey(server.id, credential);
            _vaultStatus[server.id] = true;
          }
        }
      }

      if (credential == null || credential.trim().isEmpty) {
        _isLoading = false;
        _errorMessage = 'No stored credential found for "${server.name}". Please configure an SSH private key or password.';
        _vaultStatus[server.id] = false;
        notifyListeners();
        return SshTestResult(
          success: false,
          errorMessage: _errorMessage,
        );
      }

      _vaultStatus[server.id] = true;

      String? totpSecret;
      if (server.has2FA) {
        totpSecret = await _vault.get2FASecret(server.id);
      }

      // Default prompt resolver: if not provided by caller, pop up TwoFactorAuthDialog via rootNavigatorKey
      Future<String?> Function(String promptText)? effectivePrompt2FA = onPrompt2FA;
      if (effectivePrompt2FA == null && (totpSecret == null || totpSecret.isEmpty)) {
        effectivePrompt2FA = (promptText) async {
          final navCtx = rootNavigatorKey.currentContext;
          if (navCtx != null && navCtx.mounted) {
            return await TwoFactorAuthDialog.show(
              navCtx,
              username: server.username,
              serverName: server.name,
              promptText: promptText,
            );
          }
          return null;
        };
      }

      final result = await _sshService.testConnection(
        profile: server,
        credential: credential.trim(),
        totpSecret: totpSecret,
        onPrompt2FA: effectivePrompt2FA,
      );

      final updated = server.copyWith(
        isConnected: result.success,
        lastChecked: DateTime.now(),
        osInfo: result.osInfo ?? server.osInfo,
        uptime: result.uptime ?? server.uptime,
        serviceStatuses: result.serviceStatuses.isNotEmpty ? result.serviceStatuses : server.serviceStatuses,
      );

      final index = _servers.indexWhere((s) => s.id == server.id);
      if (index != -1) {
        _servers[index] = updated;
      }

      await _persistServers();
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return SshTestResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Tests SSH connection for the currently selected active server
  Future<SshTestResult> testActiveServer({
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final current = activeServer;
    if (current == null) {
      return const SshTestResult(
        success: false,
        errorMessage: 'No active server selected.',
      );
    }
    return await testServer(current, onPrompt2FA: onPrompt2FA);
  }

  /// Securely executes service lifecycle commands (start, stop, restart) via SSH
  Future<ServiceActionResult> executeServiceControl({
    required String serviceId,
    required String action,
    String? sudoPassword,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final currentServer = activeServer;
    if (currentServer == null) {
      return ServiceActionResult(
        success: false,
        action: action,
        serviceId: serviceId,
        output: '',
        errorMessage: 'Tidak ada profil server yang aktif.',
      );
    }

    final credential = currentServer.authType == AuthType.privateKey
        ? await _vault.getPrivateKey(currentServer.id)
        : await _vault.getPassword(currentServer.id);

    if (credential == null || credential.trim().isEmpty) {
      return ServiceActionResult(
        success: false,
        action: action,
        serviceId: serviceId,
        output: '',
        errorMessage: 'Kredensial SSH tidak ditemukan di Secure Vault untuk server ini.',
      );
    }

    String? effectiveSudoPass = (sudoPassword != null && sudoPassword.trim().isNotEmpty)
        ? sudoPassword.trim()
        : await getSavedSudoPassword(currentServer.id);

    if (effectiveSudoPass != null && effectiveSudoPass.isNotEmpty) {
      await _vault.saveSudoPassword(currentServer.id, effectiveSudoPass);
    }

    if (currentServer.username != 'root' && (effectiveSudoPass == null || effectiveSudoPass.trim().isEmpty)) {
      return ServiceActionResult(
        success: false,
        action: action,
        serviceId: serviceId,
        output: '',
        errorMessage: 'Kata sandi sudo/akun wajib diisi untuk pengguna ${currentServer.username}.',
      );
    }

    final serviceDef = ServiceRegistry.getById(serviceId);

    _isLoading = true;
    notifyListeners();

    try {
      String? totpSecret;
      if (currentServer.has2FA) {
        totpSecret = await _vault.get2FASecret(currentServer.id);
      }

      Future<String?> Function(String promptText)? effectivePrompt2FA = onPrompt2FA;
      if (effectivePrompt2FA == null && (totpSecret == null || totpSecret.isEmpty)) {
        effectivePrompt2FA = (promptText) async {
          final navCtx = rootNavigatorKey.currentContext;
          if (navCtx != null && navCtx.mounted) {
            return await TwoFactorAuthDialog.show(
              navCtx,
              username: currentServer.username,
              serverName: currentServer.name,
              promptText: promptText,
            );
          }
          return null;
        };
      }

      final result = await _sshService.executeServiceAction(
        profile: currentServer,
        credential: credential,
        serviceDef: serviceDef,
        action: action,
        sudoPassword: effectiveSudoPass,
        totpSecret: totpSecret,
        onPrompt2FA: effectivePrompt2FA,
      );

      final updatedStatuses = Map<String, bool>.from(currentServer.serviceStatuses);
      updatedStatuses[serviceDef.id] = result.isOnline;

      final updatedServer = currentServer.copyWith(
        serviceStatuses: updatedStatuses,
        lastChecked: DateTime.now(),
      );

      final idx = _servers.indexWhere((s) => s.id == currentServer.id);
      if (idx != -1) {
        _servers[idx] = updatedServer;
      }
      await _persistServers();

      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getSavedSudoPassword(String serverId) async {
    final sudo = await _vault.getSudoPassword(serverId);
    if (sudo != null && sudo.trim().isNotEmpty) {
      return sudo.trim();
    }
    // Fallback: For password-authenticated servers, login password is the user sudo password
    final srv = _servers.firstWhere(
      (s) => s.id == serverId,
      orElse: () => defaultVps,
    );
    if (srv.authType == AuthType.password) {
      final accPass = await _vault.getPassword(serverId);
      if (accPass != null && accPass.trim().isNotEmpty) {
        return accPass.trim();
      }
    }
    return null;
  }

  Future<void> saveSudoPassword(String serverId, String password) async {
    final trimmed = password.trim();
    if (trimmed.isNotEmpty) {
      await _vault.saveSudoPassword(serverId, trimmed);
      _sudoStatus[serverId] = true;
    } else {
      await _vault.deleteSudoPassword(serverId);
      _sudoStatus[serverId] = false;
    }
    notifyListeners();
  }

  Future<String?> getServerPassword(String serverId) async {
    return await _vault.getPassword(serverId);
  }

  Future<String?> getTwoFactorSecret(String serverId) async {
    return await _vault.get2FASecret(serverId);
  }

  Future<void> saveTwoFactorSecret(String serverId, String secret) async {
    await _vault.save2FASecret(serverId, secret);
    notifyListeners();
  }
  /// Securely executes firewall ban or unban via SSH using iptables & fail2ban
  Future<FirewallActionResult> executeFirewallControl({
    required String ip,
    required String action, // 'ban' or 'unban'
    String service = 'sshd',
    String? serverId,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final targetServer = serverId != null
        ? _servers.firstWhere((s) => s.id == serverId, orElse: () => activeServer ?? defaultVps)
        : (activeServer ?? defaultVps);

    final cred = targetServer.authType == AuthType.privateKey
        ? await _vault.getPrivateKey(targetServer.id)
        : await _vault.getPassword(targetServer.id);

    if (cred == null || cred.trim().isEmpty) {
      return FirewallActionResult(
        success: false,
        action: action,
        ip: ip,
        output: '',
        errorMessage: 'Kredensial SSH tidak ditemukan untuk ${targetServer.name}.',
      );
    }

    final sudoPass = await _vault.getSudoPassword(targetServer.id) ??
        (targetServer.authType == AuthType.password ? await _vault.getPassword(targetServer.id) : null);
    final totpSecret = await _vault.get2FASecret(targetServer.id);

    Future<String?> Function(String promptText)? effectivePrompt2FA = onPrompt2FA;
    if (effectivePrompt2FA == null && (totpSecret == null || totpSecret.isEmpty)) {
      effectivePrompt2FA = (promptText) async {
        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx != null && navCtx.mounted) {
          return await TwoFactorAuthDialog.show(
            navCtx,
            username: targetServer.username,
            serverName: targetServer.name,
            promptText: promptText,
          );
        }
        return null;
      };
    }

    return await _sshService.executeFirewallAction(
      profile: targetServer,
      credential: cred,
      action: action,
      ip: ip,
      service: service,
      sudoPassword: sudoPass,
      totpSecret: totpSecret,
      onPrompt2FA: effectivePrompt2FA,
    );
  }

  /// Queries fail2ban & iptables on the remote server via SSH
  Future<List<BannedIpRecord>> fetchServerBannedIps({
    String? serverId,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final targetServer = serverId != null
        ? _servers.firstWhere((s) => s.id == serverId, orElse: () => activeServer ?? defaultVps)
        : (activeServer ?? defaultVps);

    final cred = targetServer.authType == AuthType.privateKey
        ? await _vault.getPrivateKey(targetServer.id)
        : await _vault.getPassword(targetServer.id);

    if (cred == null || cred.trim().isEmpty) {
      return [];
    }

    final sudoPass = await _vault.getSudoPassword(targetServer.id) ??
        (targetServer.authType == AuthType.password ? await _vault.getPassword(targetServer.id) : null);
    final totpSecret = await _vault.get2FASecret(targetServer.id);

    Future<String?> Function(String promptText)? effectivePrompt2FA = onPrompt2FA;
    if (effectivePrompt2FA == null && (totpSecret == null || totpSecret.isEmpty)) {
      effectivePrompt2FA = (promptText) async {
        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx != null && navCtx.mounted) {
          return await TwoFactorAuthDialog.show(
            navCtx,
            username: targetServer.username,
            serverName: targetServer.name,
            promptText: promptText,
          );
        }
        return null;
      };
    }

    return await _sshService.fetchServerBannedIps(
      profile: targetServer,
      credential: cred,
      sudoPassword: sudoPass,
      totpSecret: totpSecret,
      onPrompt2FA: effectivePrompt2FA,
    );
  }

  /// Fetches real-time authentication & service logs directly from the active or specified server
  Future<List<AuthEvent>> fetchRealTimeLogs({
    ServerProfile? server,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final targetServer = server ?? activeServer;
    if (targetServer == null) return [];

    final cred = await getCredentialForServer(targetServer);
    if (cred == null || cred.trim().isEmpty) return [];

    final sudoPass = await getSavedSudoPassword(targetServer.id);
    final totpSecret = await get2FASecretForServer(targetServer);

    Future<String?> Function(String promptText)? effectivePrompt2FA = onPrompt2FA;
    if (effectivePrompt2FA == null && (totpSecret == null || totpSecret.isEmpty)) {
      effectivePrompt2FA = (promptText) async {
        final navCtx = rootNavigatorKey.currentContext;
        if (navCtx != null && navCtx.mounted) {
          return await TwoFactorAuthDialog.show(
            navCtx,
            username: targetServer.username,
            serverName: targetServer.name,
            promptText: promptText,
          );
        }
        return null;
      };
    }

    final rawLines = await _sshService.fetchUnifiedServerLogs(
      profile: targetServer,
      credential: cred.trim(),
      sudoPassword: sudoPass,
      totpSecret: totpSecret,
      onPrompt2FA: effectivePrompt2FA,
    );

    return LogParserService().parseLines(rawLines, targetServer.id);
  }

  /// Queries raw server logs on the remote host for all occurrences matching the specified IP
  Future<List<String>> fetchIpEvidenceLogs({
    required String ip,
    String? serverId,
  }) async {
    final targetServer = serverId != null
        ? _servers.firstWhere((s) => s.id == serverId, orElse: () => activeServer ?? defaultVps)
        : (activeServer ?? defaultVps);

    final cred = targetServer.authType == AuthType.privateKey
        ? await _vault.getPrivateKey(targetServer.id)
        : await _vault.getPassword(targetServer.id);

    if (cred == null || cred.trim().isEmpty) {
      return [];
    }

    final totpSecret = await _vault.get2FASecret(targetServer.id);

    return await _sshService.fetchIpEvidenceLogs(
      profile: targetServer,
      credential: cred,
      ip: ip,
      totpSecret: totpSecret,
    );
  }
  /// Safely reboots the remote server host via SSH
  Future<FirewallActionResult> rebootServer({
    required String serverId,
    String? sudoPassword,
    Future<String?> Function(String promptText)? onPrompt2FA,
  }) async {
    final targetServer = _servers.firstWhere((s) => s.id == serverId, orElse: () => activeServer ?? defaultVps);

    final cred = targetServer.authType == AuthType.privateKey
        ? await _vault.getPrivateKey(targetServer.id)
        : await _vault.getPassword(targetServer.id);

    if (cred == null || cred.trim().isEmpty) {
      return FirewallActionResult(
        success: false,
        action: "reboot",
        ip: targetServer.host,
        output: "",
        errorMessage: "Kredensial SSH tidak ditemukan untuk ${targetServer.name}.",
      );
    }

    final effectiveSudo = sudoPassword?.trim().isNotEmpty == true
        ? sudoPassword!.trim()
        : (await _vault.getSudoPassword(targetServer.id) ??
            (targetServer.authType == AuthType.password ? await _vault.getPassword(targetServer.id) : null));
    final totpSecret = await _vault.get2FASecret(targetServer.id);

    return await _sshService.rebootServer(
      profile: targetServer,
      credential: cred,
      sudoPassword: effectiveSudo,
      totpSecret: totpSecret,
      onPrompt2FA: onPrompt2FA,
    );
  }
}
