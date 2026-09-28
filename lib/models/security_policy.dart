import 'dart:convert';

class BannedIpRecord {
  final String ip;
  final DateTime bannedAt;
  final String reason;
  final String service;

  const BannedIpRecord({
    required this.ip,
    required this.bannedAt,
    required this.reason,
    required this.service,
  });

  Map<String, dynamic> toMap() => {
        'ip': ip,
        'bannedAt': bannedAt.toIso8601String(),
        'reason': reason,
        'service': service,
      };

  factory BannedIpRecord.fromMap(Map<String, dynamic> map) => BannedIpRecord(
        ip: map['ip'] as String,
        bannedAt: DateTime.parse(map['bannedAt'] as String),
        reason: map['reason'] as String,
        service: map['service'] as String,
      );
}

class SecurityPolicy {
  final String serverId;
  final List<String> trustedIps;
  final List<String> trustedCountries;
  final int maxFailedAttemptsThreshold;
  final int timeWindowSeconds;
  final bool alertOnUnknownSuccess;
  final bool autoBlockBruteForce;
  final List<BannedIpRecord> bannedIps;

  const SecurityPolicy({
    required this.serverId,
    this.trustedIps = const ['127.0.0.1', '::1'],
    this.trustedCountries = const ['ID'],
    this.maxFailedAttemptsThreshold = 3,
    this.timeWindowSeconds = 120,
    this.alertOnUnknownSuccess = true,
    this.autoBlockBruteForce = false,
    this.bannedIps = const [],
  });

  SecurityPolicy copyWith({
    String? serverId,
    List<String>? trustedIps,
    List<String>? trustedCountries,
    int? maxFailedAttemptsThreshold,
    int? timeWindowSeconds,
    bool? alertOnUnknownSuccess,
    bool? autoBlockBruteForce,
    List<BannedIpRecord>? bannedIps,
  }) {
    return SecurityPolicy(
      serverId: serverId ?? this.serverId,
      trustedIps: trustedIps ?? this.trustedIps,
      trustedCountries: trustedCountries ?? this.trustedCountries,
      maxFailedAttemptsThreshold:
          maxFailedAttemptsThreshold ?? this.maxFailedAttemptsThreshold,
      timeWindowSeconds: timeWindowSeconds ?? this.timeWindowSeconds,
      alertOnUnknownSuccess:
          alertOnUnknownSuccess ?? this.alertOnUnknownSuccess,
      autoBlockBruteForce: autoBlockBruteForce ?? this.autoBlockBruteForce,
      bannedIps: bannedIps ?? this.bannedIps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serverId': serverId,
      'trustedIps': trustedIps,
      'trustedCountries': trustedCountries,
      'maxFailedAttemptsThreshold': maxFailedAttemptsThreshold,
      'timeWindowSeconds': timeWindowSeconds,
      'alertOnUnknownSuccess': alertOnUnknownSuccess,
      'autoBlockBruteForce': autoBlockBruteForce,
      'bannedIps': bannedIps.map((x) => x.toMap()).toList(),
    };
  }

  factory SecurityPolicy.fromMap(Map<String, dynamic> map) {
    return SecurityPolicy(
      serverId: map['serverId'] as String,
      trustedIps: (map['trustedIps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['127.0.0.1', '::1'],
      trustedCountries: (map['trustedCountries'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['ID'],
      maxFailedAttemptsThreshold:
          map['maxFailedAttemptsThreshold'] as int? ?? 3,
      timeWindowSeconds: map['timeWindowSeconds'] as int? ?? 120,
      alertOnUnknownSuccess: map['alertOnUnknownSuccess'] as bool? ?? true,
      autoBlockBruteForce: map['autoBlockBruteForce'] as bool? ?? false,
      bannedIps: (map['bannedIps'] as List<dynamic>?)
              ?.map((e) => BannedIpRecord.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String toJson() => json.encode(toMap());
  factory SecurityPolicy.fromJson(String source) =>
      SecurityPolicy.fromMap(json.decode(source) as Map<String, dynamic>);
}
