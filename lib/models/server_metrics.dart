class TimeSeriesPoint {
  final int hour; // 0 - 23 (chronological bucket index: 0 = 23h ago, 23 = current hour)
  final int clockHour; // 0 - 23 (actual clock hour of the day)
  final String label; // formatted hour (e.g., '09:00', '14:00')
  final DateTime? timestamp;
  final int successCount;
  final int failedCount;
  final int blockedCount;

  const TimeSeriesPoint({
    required this.hour,
    this.clockHour = 0,
    this.label = '',
    this.timestamp,
    required this.successCount,
    required this.failedCount,
    required this.blockedCount,
  });
}

class ServerMetrics {
  final int totalAttempts24h;
  final int failedAttempts24h;
  final int unknownPersonAttempts24h;
  final int blockedCount;
  final int integrityScore; // 0 to 100
  final Map<String, int> serviceDistribution;
  final Map<String, int> targetedUsers;
  final List<TimeSeriesPoint> hourlyTrend;

  const ServerMetrics({
    this.totalAttempts24h = 0,
    this.failedAttempts24h = 0,
    this.unknownPersonAttempts24h = 0,
    this.blockedCount = 0,
    this.integrityScore = 100,
    this.serviceDistribution = const {},
    this.targetedUsers = const {},
    this.hourlyTrend = const [],
  });

  double get failureRate {
    if (totalAttempts24h == 0) return 0.0;
    return (failedAttempts24h / totalAttempts24h) * 100;
  }
}
