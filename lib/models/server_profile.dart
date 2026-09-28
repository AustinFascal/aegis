import 'dart:convert';

enum AuthType { privateKey, password }

class ServerProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final AuthType authType;
  final List<String> monitoredServices; // e.g. ['mysqld', 'sshd', 'nginx']
  final Map<String, bool> serviceStatuses; // e.g. {'mysqld': true, 'sshd': true}
  final bool isConnected;
  final DateTime? lastChecked;
  final String? osInfo;
  final String? uptime;
  final bool has2FA;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.authType = AuthType.privateKey,
    this.monitoredServices = const ['mysqld', 'sshd'],
    this.serviceStatuses = const {},
    this.isConnected = false,
    this.lastChecked,
    this.osInfo,
    this.uptime,
    this.has2FA = false,
  });

  ServerProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    List<String>? monitoredServices,
    Map<String, bool>? serviceStatuses,
    bool? isConnected,
    DateTime? lastChecked,
    String? osInfo,
    String? uptime,
    bool? has2FA,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      monitoredServices: monitoredServices ?? this.monitoredServices,
      serviceStatuses: serviceStatuses ?? this.serviceStatuses,
      isConnected: isConnected ?? this.isConnected,
      lastChecked: lastChecked ?? this.lastChecked,
      osInfo: osInfo ?? this.osInfo,
      uptime: uptime ?? this.uptime,
      has2FA: has2FA ?? this.has2FA,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'authType': authType.name,
      'monitoredServices': monitoredServices,
      'serviceStatuses': serviceStatuses,
      'isConnected': isConnected,
      'lastChecked': lastChecked?.toIso8601String(),
      'osInfo': osInfo,
      'uptime': uptime,
      'has2FA': has2FA,
    };
  }

  factory ServerProfile.fromMap(Map<String, dynamic> map) {
    return ServerProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      host: map['host'] as String,
      port: map['port'] as int? ?? 22,
      username: map['username'] as String,
      authType: AuthType.values.firstWhere(
        (e) => e.name == map['authType'],
        orElse: () => AuthType.privateKey,
      ),
      monitoredServices: (map['monitoredServices'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['mysqld', 'sshd'],
      serviceStatuses: (map['serviceStatuses'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          const {},
      isConnected: map['isConnected'] as bool? ?? false,
      lastChecked: map['lastChecked'] != null
          ? DateTime.tryParse(map['lastChecked'] as String)
          : null,
      osInfo: map['osInfo'] as String?,
      uptime: map['uptime'] as String?,
      has2FA: map['has2FA'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());
  factory ServerProfile.fromJson(String source) =>
      ServerProfile.fromMap(json.decode(source) as Map<String, dynamic>);
}
