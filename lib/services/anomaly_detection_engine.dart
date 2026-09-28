import '../models/auth_event.dart';
import '../models/security_policy.dart';

class AnomalyEvaluationResult {
  final AuthEvent event;
  final bool shouldAlert;
  final String alertTitle;
  final String alertMessage;
  final bool recommendBlock;

  const AnomalyEvaluationResult({
    required this.event,
    required this.shouldAlert,
    required this.alertTitle,
    required this.alertMessage,
    this.recommendBlock = false,
  });
}

class AnomalyDetectionEngine {
  static final AnomalyDetectionEngine _instance = AnomalyDetectionEngine._internal();
  factory AnomalyDetectionEngine() => _instance;
  AnomalyDetectionEngine._internal();

  // Sliding window: IP -> List of failure timestamps
  final Map<String, List<DateTime>> _failedAttemptsTracker = {};

  AnomalyEvaluationResult evaluate({
    required AuthEvent event,
    required SecurityPolicy policy,
  }) {
    final ip = event.clientIp;
    final isTrustedIp = _isIpTrusted(ip, policy.trustedIps);

    // 1. Evaluate Successful Login
    if (event.status == EventStatus.success) {
      if (!isTrustedIp) {
        // UNKNOWN PERSON DETECTED!
        final escalatedEvent = event.copyWith(
          isUnknownPerson: true,
          severity: EventSeverity.critical,
          riskScore: 98,
          failureReason: 'UNKNOWN PERSON: Verified login from untrusted IP',
        );

        return AnomalyEvaluationResult(
          event: escalatedEvent,
          shouldAlert: policy.alertOnUnknownSuccess,
          alertTitle: '🚨 CRITICAL: Unknown Person Access',
          alertMessage:
              'User "${event.user}" logged in to ${event.service.toUpperCase()} from untrusted IP $ip!',
          recommendBlock: true,
        );
      } else {
        // Legitimate authorized login
        return AnomalyEvaluationResult(
          event: event.copyWith(riskScore: 5),
          shouldAlert: false,
          alertTitle: 'Authorized Access',
          alertMessage: 'User "${event.user}" logged in from trusted IP.',
        );
      }
    }

    // 2. Evaluate Failed Attempt (Brute Force / Unauthorized probe)
    if (event.status == EventStatus.failed) {
      final now = DateTime.now();
      final tracker = _failedAttemptsTracker.putIfAbsent(ip, () => []);
      tracker.add(now);

      // Clean old timestamps outside sliding window
      final windowDuration = Duration(seconds: policy.timeWindowSeconds);
      tracker.removeWhere((dt) => now.difference(dt) > windowDuration);

      final failCount = tracker.length;
      final isRootOrAdmin = event.user.toLowerCase() == 'root' ||
          event.user.toLowerCase() == 'admin';

      if (failCount >= policy.maxFailedAttemptsThreshold) {
        // Brute force threshold breached!
        final escalatedEvent = event.copyWith(
          severity: EventSeverity.critical,
          riskScore: 95,
          failureReason: 'BRUTE FORCE DETECTED: $failCount failed attempts in ${policy.timeWindowSeconds}s',
        );

        return AnomalyEvaluationResult(
          event: escalatedEvent,
          shouldAlert: true,
          alertTitle: '⚠️ BRUTE FORCE ATTACK',
          alertMessage:
              'IP $ip has failed $failCount login attempts on ${event.service.toUpperCase()} targeting user "${event.user}"!',
          recommendBlock: true,
        );
      }

      // Single or low frequency failure
      final calculatedRisk = isRootOrAdmin ? 80 : 50;
      return AnomalyEvaluationResult(
        event: event.copyWith(riskScore: calculatedRisk),
        shouldAlert: isRootOrAdmin,
        alertTitle: 'Unauthorized Login Attempt',
        alertMessage: 'Failed ${event.service.toUpperCase()} login for "${event.user}" from $ip',
        recommendBlock: false,
      );
    }

    // 3. Fallback for other statuses
    return AnomalyEvaluationResult(
      event: event,
      shouldAlert: false,
      alertTitle: 'Access Log',
      alertMessage: '${event.service} event recorded.',
    );
  }

  bool _isIpTrusted(String ip, List<String> trustedIps) {
    if (trustedIps.contains(ip)) return true;
    for (final pattern in trustedIps) {
      if (pattern == ip) return true;
      // Simple subnet check: e.g. 192.168.1.
      if (pattern.endsWith('.*') &&
          ip.startsWith(pattern.substring(0, pattern.length - 2))) {
        return true;
      }
    }
    return false;
  }

  void clearHistory() {
    _failedAttemptsTracker.clear();
  }
}
