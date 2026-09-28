import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/security/secure_vault.dart';
import '../models/security_policy.dart';

class PolicyProvider extends ChangeNotifier {
  final Map<String, SecurityPolicy> _policies = {};

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
        return File('${dir.path}/policies.json');
      }
    } catch (e) {
      debugPrint('[PolicyProvider] Config dir access: $e');
    }
    return null;
  }

  PolicyProvider() {
    _loadAllPolicies();
  }

  Future<void> _loadAllPolicies() async {
    try {
      final file = _getConfigFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> decoded = json.decode(content);
          for (final entry in decoded.entries) {
            _policies[entry.key] = SecurityPolicy.fromMap(entry.value as Map<String, dynamic>);
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[PolicyProvider] Load file policies error: $e');
    }
  }

  SecurityPolicy _createDefaultPolicy(String serverId) {
    return SecurityPolicy(
      serverId: serverId,
      trustedIps: const ['127.0.0.1', '::1', '103.142.21.195', '182.1.200.*'],
      trustedCountries: const ['ID', 'SG'],
      maxFailedAttemptsThreshold: 3,
      timeWindowSeconds: 120,
      alertOnUnknownSuccess: true,
      autoBlockBruteForce: false,
      bannedIps: [
        BannedIpRecord(
          ip: '185.220.101.5',
          bannedAt: DateTime.now().subtract(const Duration(hours: 3)),
          reason: 'Brute-force root access on mysqld',
          service: 'mysqld',
        ),
        BannedIpRecord(
          ip: '45.154.255.88',
          bannedAt: DateTime.now().subtract(const Duration(hours: 8)),
          reason: 'SSH dictionary probe for invalid users',
          service: 'sshd',
        ),
      ],
    );
  }

  SecurityPolicy getPolicy(String serverId) {
    if (!_policies.containsKey(serverId)) {
      final file = _getConfigFile();
      if (file != null && file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          if (content.trim().isNotEmpty) {
            final Map<String, dynamic> all = json.decode(content);
            if (all.containsKey(serverId)) {
              final loaded = SecurityPolicy.fromMap(all[serverId] as Map<String, dynamic>);
              _policies[serverId] = loaded;
              return loaded;
            }
          }
        } catch (_) {}
      }

      final vaultJson = SecureVault().getPolicySync(serverId);
      if (vaultJson != null && vaultJson.trim().isNotEmpty) {
        try {
          final loaded = SecurityPolicy.fromJson(vaultJson);
          _policies[serverId] = loaded;
          return loaded;
        } catch (_) {}
      }

      _loadPolicyFromVault(serverId);
      _policies[serverId] = _createDefaultPolicy(serverId);
    }
    return _policies[serverId]!;
  }

  Future<void> _loadPolicyFromVault(String serverId) async {
    try {
      String? jsonStr = await SecureVault().getPolicy(serverId);
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        final file = _getConfigFile();
        if (file != null && await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isNotEmpty) {
            final Map<String, dynamic> all = json.decode(content);
            if (all.containsKey(serverId)) {
              jsonStr = json.encode(all[serverId]);
            }
          }
        }
      }

      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        _policies[serverId] = SecurityPolicy.fromJson(jsonStr);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved policy for $serverId: $e');
    }
  }

  void _persistPolicy(String serverId, SecurityPolicy policy) {
    SecureVault().savePolicy(serverId, policy.toJson()).catchError((e) {
      debugPrint('Error persisting policy in vault for $serverId: $e');
    });

    try {
      final file = _getConfigFile();
      if (file != null) {
        Map<String, dynamic> all = {};
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          if (content.trim().isNotEmpty) {
            all = json.decode(content) as Map<String, dynamic>;
          }
        }
        all[serverId] = policy.toMap();
        file.writeAsStringSync(json.encode(all));
      }
    } catch (e) {
      debugPrint('Error persisting policy in file for $serverId: $e');
    }
  }

  void addTrustedIp(String serverId, String ip) {
    final current = getPolicy(serverId);
    if (!current.trustedIps.contains(ip.trim())) {
      final updated = current.copyWith(
        trustedIps: [...current.trustedIps, ip.trim()],
      );
      _policies[serverId] = updated;
      notifyListeners();
      _persistPolicy(serverId, updated);
    }
  }

  void removeTrustedIp(String serverId, String ip) {
    final current = getPolicy(serverId);
    final updated = current.copyWith(
      trustedIps: current.trustedIps.where((item) => item != ip).toList(),
    );
    _policies[serverId] = updated;
    notifyListeners();
    _persistPolicy(serverId, updated);
  }

  void updatePolicy(String serverId, SecurityPolicy newPolicy) {
    _policies[serverId] = newPolicy;
    notifyListeners();
    _persistPolicy(serverId, newPolicy);
  }

  void banIp(String serverId, String ip, String reason, String service) {
    final current = getPolicy(serverId);
    final isAlreadyBanned = current.bannedIps.any((b) => b.ip == ip);
    if (!isAlreadyBanned) {
      final newRecord = BannedIpRecord(
        ip: ip,
        bannedAt: DateTime.now(),
        reason: reason,
        service: service,
      );
      final updated = current.copyWith(
        bannedIps: [newRecord, ...current.bannedIps],
      );
      _policies[serverId] = updated;
      notifyListeners();
      _persistPolicy(serverId, updated);
    }
  }

  void unbanIp(String serverId, String ip) {
    final current = getPolicy(serverId);
    final updated = current.copyWith(
      bannedIps: current.bannedIps.where((b) => b.ip != ip).toList(),
    );
    _policies[serverId] = updated;
    notifyListeners();
    _persistPolicy(serverId, updated);
  }
  void syncServerBannedIps(String serverId, List<BannedIpRecord> serverBans) {
    final current = getPolicy(serverId);
    final List<BannedIpRecord> merged = [...serverBans];
    for (final b in current.bannedIps) {
      if (!merged.any((x) => x.ip == b.ip)) {
        merged.add(b);
      }
    }
    final updated = current.copyWith(bannedIps: merged);
    _policies[serverId] = updated;
    notifyListeners();
    _persistPolicy(serverId, updated);
  }

  void clearAllPolicies() {
    _policies.clear();
    final file = _getConfigFile();
    if (file != null && file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    notifyListeners();
  }
}
