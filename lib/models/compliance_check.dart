enum ComplianceCategory {
  ssh,
  sysctl,
  firewall,
  identity,
  filesystem,
}

enum ComplianceSeverity {
  critical,
  high,
  medium,
  low,
}

enum ComplianceStatus {
  passed,
  warning,
  failed,
  skipped,
}

class ComplianceCheckItem {
  final String id;
  final ComplianceCategory category;
  final String titleId;
  final String titleEn;
  final String descriptionId;
  final String descriptionEn;
  final String rationaleId;
  final String rationaleEn;
  final String command;
  final String expected;
  final String? actual;
  final ComplianceStatus status;
  final ComplianceSeverity severity;
  final String remediationScript;
  final String standard;

  const ComplianceCheckItem({
    required this.id,
    required this.category,
    required this.titleId,
    required this.titleEn,
    required this.descriptionId,
    required this.descriptionEn,
    required this.rationaleId,
    required this.rationaleEn,
    required this.command,
    required this.expected,
    this.actual,
    required this.status,
    required this.severity,
    required this.remediationScript,
    required this.standard,
  });

  ComplianceCheckItem copyWith({
    String? id,
    ComplianceCategory? category,
    String? titleId,
    String? titleEn,
    String? descriptionId,
    String? descriptionEn,
    String? rationaleId,
    String? rationaleEn,
    String? command,
    String? expected,
    String? actual,
    ComplianceStatus? status,
    ComplianceSeverity? severity,
    String? remediationScript,
    String? standard,
  }) {
    return ComplianceCheckItem(
      id: id ?? this.id,
      category: category ?? this.category,
      titleId: titleId ?? this.titleId,
      titleEn: titleEn ?? this.titleEn,
      descriptionId: descriptionId ?? this.descriptionId,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      rationaleId: rationaleId ?? this.rationaleId,
      rationaleEn: rationaleEn ?? this.rationaleEn,
      command: command ?? this.command,
      expected: expected ?? this.expected,
      actual: actual ?? this.actual,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      remediationScript: remediationScript ?? this.remediationScript,
      standard: standard ?? this.standard,
    );
  }
}

class ComplianceScanReport {
  final String id;
  final String serverId;
  final String serverName;
  final DateTime timestamp;
  final List<ComplianceCheckItem> items;
  final int score;
  final String grade;

  const ComplianceScanReport({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.timestamp,
    required this.items,
    required this.score,
    required this.grade,
  });

  int get totalCount => items.length;
  int get passedCount => items.where((i) => i.status == ComplianceStatus.passed).length;
  int get warningCount => items.where((i) => i.status == ComplianceStatus.warning).length;
  int get failedCount => items.where((i) => i.status == ComplianceStatus.failed).length;

  static String calculateGrade(int score) {
    if (score >= 95) return 'A+';
    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 55) return 'C';
    return 'F';
  }

  static int calculateScore(List<ComplianceCheckItem> items) {
    if (items.isEmpty) return 100;
    double points = 0;
    double maxPoints = 0;

    for (final item in items) {
      double weight;
      switch (item.severity) {
        case ComplianceSeverity.critical:
          weight = 4.0;
          break;
        case ComplianceSeverity.high:
          weight = 3.0;
          break;
        case ComplianceSeverity.medium:
          weight = 2.0;
          break;
        case ComplianceSeverity.low:
          weight = 1.0;
          break;
      }

      maxPoints += weight;
      if (item.status == ComplianceStatus.passed) {
        points += weight;
      } else if (item.status == ComplianceStatus.warning) {
        points += weight * 0.5;
      }
    }

    if (maxPoints == 0) return 100;
    return ((points / maxPoints) * 100).round().clamp(0, 100);
  }
}
