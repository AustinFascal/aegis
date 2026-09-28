import 'dart:convert';

enum EventStatus { success, failed, blocked }

enum EventSeverity { info, warning, critical }

class AuthEvent {
  final String id;
  final String serverId;
  final String service; // 'mysqld', 'sshd', 'nginx'
  final DateTime timestamp;
  final String clientIp;
  final String user;
  final EventStatus status;
  final EventSeverity severity;
  final int riskScore; // 0 to 100
  final bool isUnknownPerson;
  final String? failureReason;
  final String? country;
  final String? city;
  final String? asn;
  final String? rawLog;
  final int attemptCount;
  final List<String> evidenceLogs;

  const AuthEvent({
    required this.id,
    required this.serverId,
    required this.service,
    required this.timestamp,
    required this.clientIp,
    required this.user,
    required this.status,
    required this.severity,
    this.riskScore = 0,
    this.isUnknownPerson = false,
    this.failureReason,
    this.country,
    this.city,
    this.asn,
    this.rawLog,
    this.attemptCount = 1,
    this.evidenceLogs = const [],
  });

  /// Returns all available evidence logs for this event, falling back to [rawLog] if [evidenceLogs] is empty.
  List<String> get allEvidenceLogs {
    if (evidenceLogs.isNotEmpty) return evidenceLogs;
    if (rawLog != null && rawLog!.isNotEmpty) return [rawLog!];
    return const [];
  }

  AuthEvent copyWith({
    String? id,
    String? serverId,
    String? service,
    DateTime? timestamp,
    String? clientIp,
    String? user,
    EventStatus? status,
    EventSeverity? severity,
    int? riskScore,
    bool? isUnknownPerson,
    String? failureReason,
    String? country,
    String? city,
    String? asn,
    String? rawLog,
    int? attemptCount,
    List<String>? evidenceLogs,
  }) {
    return AuthEvent(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      service: service ?? this.service,
      timestamp: timestamp ?? this.timestamp,
      clientIp: clientIp ?? this.clientIp,
      user: user ?? this.user,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      riskScore: riskScore ?? this.riskScore,
      isUnknownPerson: isUnknownPerson ?? this.isUnknownPerson,
      failureReason: failureReason ?? this.failureReason,
      country: country ?? this.country,
      city: city ?? this.city,
      asn: asn ?? this.asn,
      rawLog: rawLog ?? this.rawLog,
      attemptCount: attemptCount ?? this.attemptCount,
      evidenceLogs: evidenceLogs ?? this.evidenceLogs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serverId': serverId,
      'service': service,
      'timestamp': timestamp.toIso8601String(),
      'clientIp': clientIp,
      'user': user,
      'status': status.name,
      'severity': severity.name,
      'riskScore': riskScore,
      'isUnknownPerson': isUnknownPerson,
      'failureReason': failureReason,
      'country': country,
      'city': city,
      'asn': asn,
      'rawLog': rawLog,
      'attemptCount': attemptCount,
      'evidenceLogs': evidenceLogs,
    };
  }

  factory AuthEvent.fromMap(Map<String, dynamic> map) {
    final rawLogsList = (map['evidenceLogs'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        (map['rawLog'] != null ? [map['rawLog'] as String] : const <String>[]);

    return AuthEvent(
      id: map['id'] as String,
      serverId: map['serverId'] as String,
      service: map['service'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      clientIp: map['clientIp'] as String,
      user: map['user'] as String,
      status: EventStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => EventStatus.failed,
      ),
      severity: EventSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => EventSeverity.info,
      ),
      riskScore: map['riskScore'] as int? ?? 0,
      isUnknownPerson: map['isUnknownPerson'] as bool? ?? false,
      failureReason: map['failureReason'] as String?,
      country: map['country'] as String?,
      city: map['city'] as String?,
      asn: map['asn'] as String?,
      rawLog: map['rawLog'] as String?,
      attemptCount: map['attemptCount'] as int? ?? (rawLogsList.isNotEmpty ? rawLogsList.length : 1),
      evidenceLogs: rawLogsList,
    );
  }

  String toJson() => json.encode(toMap());
  factory AuthEvent.fromJson(String source) =>
      AuthEvent.fromMap(json.decode(source) as Map<String, dynamic>);
}
