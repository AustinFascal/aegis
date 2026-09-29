import 'package:uuid/uuid.dart';
import '../models/auth_event.dart';

class LogParserService {
  static final LogParserService _instance = LogParserService._internal();
  factory LogParserService() => _instance;
  LogParserService._internal();

  final Uuid _uuid = const Uuid();

  // Maximum allowed length for a single log line to prevent ReDoS / memory exhaustion
  static const int _maxLineLength = 2048;

  // Strict regex patterns
  static final RegExp _mysqlDeniedRegex = RegExp(
    r"(?:(?<time>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+Z)?).*?)?Access denied for user '(?<user>[^']+)'@'(?<ip>[^']+)'(?:\s*\(using password:\s*(?<pwd>[^\)]+)\))?",
    caseSensitive: false,
  );

  static final RegExp _mysqlConnectRegex = RegExp(
    r"(?:(?<time>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+Z)?).*?)?Connect\s+(?<user>[^@]+)@(?<ip>\S+)\s+(?:as\s+\S+\s+)?on\s+(?<db>\S*)",
    caseSensitive: false,
  );

  static final RegExp _mysqlAbortedRegex = RegExp(
    r"(?:(?<time>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+Z)?).*?)?Aborted connection \d+ to db: '(?<db>[^']*)' user: '(?<user>[^']*)' host: '(?<ip>[^']+)'",
    caseSensitive: false,
  );

  // SSH Regex Patterns
  static final RegExp _sshAcceptedRegex = RegExp(
    r"(?:(?<month>\w{3})\s+(?<day>\d+)\s+(?<time>\d{2}:\d{2}:\d{2}))?.*sshd(?:\[\d+\])?:\s+Accepted\s+(?<method>publickey|password|keyboard-interactive(?:/pam)?|none)\s+for\s+(?<user>\S+)\s+from\s+(?<ip>\S+)\s+port\s+(?<port>\d+)",
    caseSensitive: false,
  );

  static final RegExp _sshFailedRegex = RegExp(
    r"(?:(?<month>\w{3})\s+(?<day>\d+)\s+(?<time>\d{2}:\d{2}:\d{2}))?.*sshd(?:\[\d+\])?:\s+Failed\s+(?:password|publickey|none)\s+(?:for\s+invalid\s+user\s+|for\s+)(?<user>\S+)\s+from\s+(?<ip>\S+)\s+port\s+(?<port>\d+)",
    caseSensitive: false,
  );

  static final RegExp _sshInvalidUserRegex = RegExp(
    r"(?:(?<month>\w{3})\s+(?<day>\d+)\s+(?<time>\d{2}:\d{2}:\d{2}))?.*sshd(?:\[\d+\])?:\s+Invalid\s+user\s+(?<user>\S+)\s+from\s+(?<ip>\S+)",
    caseSensitive: false,
  );

  static final RegExp _pamFailedRegex = RegExp(
    r"(?:(?<month>\w{3})\s+(?<day>\d+)\s+(?<time>\d{2}:\d{2}:\d{2}))?.*pam_unix\(sshd(?::auth)?\):\s+authentication failure;.*rhost=(?<ip>[0-9a-fA-F:\.]+)(?:\s+user=(?<user>\S+))?",
    caseSensitive: false,
  );

  static final RegExp _fail2banActionRegex = RegExp(
    r"fail2ban\.actions.*:\s+NOTICE\s+\[(?<jail>[^\]]+)\]\s+(?<action>Ban|Unban)\s+(?<ip>[0-9a-fA-F:\.]+)",
    caseSensitive: false,
  );

  // Safe IP matching pattern (IPv4 or IPv6)
  static final RegExp _safeIpRegex = RegExp(r'^[0-9a-fA-F:\.]+$');

  /// Parse multiple lines from server logs into a deduplicated list of AuthEvent objects
  List<AuthEvent> parseLines(List<String> lines, String serverId) {
    final events = <AuthEvent>[];
    final seen = <String>{};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      final ev = parseLine(trimmed, serverId);
      if (ev != null) {
        events.add(ev);
      }
    }
    return events;
  }

  /// Parse a single line from either MySQL, SSH, or Fail2ban log with boundary protections
  AuthEvent? parseLine(String line, String serverId) {
    var trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // Defense against oversized log lines
    if (trimmed.length > _maxLineLength) {
      trimmed = trimmed.substring(0, _maxLineLength);
    }

    // 1. Check MySQL Access Denied
    final mysqlDeniedMatch = _mysqlDeniedRegex.firstMatch(trimmed);
    if (mysqlDeniedMatch != null) {
      final user = _sanitizeString(mysqlDeniedMatch.namedGroup('user') ?? 'unknown');
      final ip = _cleanIp(mysqlDeniedMatch.namedGroup('ip') ?? '0.0.0.0');
      final pwdUsed = mysqlDeniedMatch.namedGroup('pwd');
      final failureReason = pwdUsed != null ? 'Access denied (pwd: $pwdUsed)' : 'Access denied';

      return AuthEvent(
        id: _uuid.v4(),
        serverId: serverId,
        service: 'mysqld',
        timestamp: _parseTimestamp(mysqlDeniedMatch, trimmed),
        clientIp: ip,
        user: user,
        status: EventStatus.failed,
        severity: (user == 'root' || user == 'admin') ? EventSeverity.critical : EventSeverity.warning,
        riskScore: (user == 'root' || user == 'admin') ? 85 : 55,
        failureReason: failureReason,
        rawLog: trimmed,
      );
    }

    // 2. Check MySQL Successful Connect
    final mysqlConnectMatch = _mysqlConnectRegex.firstMatch(trimmed);
    if (mysqlConnectMatch != null) {
      final user = _sanitizeString(mysqlConnectMatch.namedGroup('user') ?? 'unknown');
      final ip = _cleanIp(mysqlConnectMatch.namedGroup('ip') ?? '127.0.0.1');
      final db = _sanitizeString(mysqlConnectMatch.namedGroup('db') ?? '');

      return AuthEvent(
        id: _uuid.v4(),
        serverId: serverId,
        service: 'mysqld',
        timestamp: _parseTimestamp(mysqlConnectMatch, trimmed),
        clientIp: ip,
        user: user,
        status: EventStatus.success,
        severity: EventSeverity.info,
        riskScore: 10,
        failureReason: db.isNotEmpty ? 'Connected to db: $db' : null,
        rawLog: trimmed,
      );
    }

    // 3. Check MySQL Aborted connection
    final mysqlAbortedMatch = _mysqlAbortedRegex.firstMatch(trimmed);
    if (mysqlAbortedMatch != null) {
      final user = _sanitizeString(mysqlAbortedMatch.namedGroup('user') ?? 'unauthenticated');
      final ip = _cleanIp(mysqlAbortedMatch.namedGroup('ip') ?? '0.0.0.0');

      return AuthEvent(
        id: _uuid.v4(),
        serverId: serverId,
        service: 'mysqld',
        timestamp: _parseTimestamp(mysqlAbortedMatch, trimmed),
        clientIp: ip,
        user: user,
        status: EventStatus.failed,
        severity: EventSeverity.warning,
        riskScore: 60,
        failureReason: 'Aborted handshake / packet error',
        rawLog: trimmed,
      );
    }

    // 4. Check SSH Accepted
    final sshAcceptedMatch = _sshAcceptedRegex.firstMatch(trimmed);
    if (sshAcceptedMatch != null) {
      final user = _sanitizeString(sshAcceptedMatch.namedGroup('user') ?? 'unknown');
      final ip = _cleanIp(sshAcceptedMatch.namedGroup('ip') ?? '127.0.0.1');
      final method = _sanitizeString(sshAcceptedMatch.namedGroup('method') ?? 'ssh2');

      return AuthEvent(
        id: _uuid.v4(),
        serverId: serverId,
        service: 'sshd',
        timestamp: _parseTimestamp(sshAcceptedMatch, trimmed),
        clientIp: ip,
        user: user,
        status: EventStatus.success,
        severity: EventSeverity.info,
        riskScore: 15,
        failureReason: 'Auth method: $method',
        rawLog: trimmed,
      );
    }

    // 5. Check SSH Failed
    final sshFailedMatch = _sshFailedRegex.firstMatch(trimmed);
    if (sshFailedMatch != null) {
      final user = _sanitizeString(sshFailedMatch.namedGroup('user') ?? 'unknown');
      final ip = _cleanIp(sshFailedMatch.namedGroup('ip') ?? '0.0.0.0');

      return AuthEvent(
        id: _uuid.v4(),
        serverId: serverId,
        service: 'sshd',
        timestamp: _parseTimestamp(sshFailedMatch, trimmed),
        clientIp: ip,
        user: user,
        status: EventStatus.failed,
        severity: (user == 'root' || user == 'admin') ? EventSeverity.critical : EventSeverity.warning,
        riskScore: (user == 'root' || user == 'admin') ? 90 : 65,
        failureReason: 'Failed password attempt',
        rawLog: trimmed,
      );
    }

    // 6. Check SSH Invalid User
    final sshInvalidMatch = _sshInvalidUserRegex.firstMatch(trimmed);
    if (sshInvalidMatch != null) {
      final user = _sanitizeString(sshInvalidMatch.namedGroup('user') ?? 'unknown');
      final ip = _cleanIp(sshInvalidMatch.namedGroup('ip') ?? '0.0.0.0');

      return AuthEvent(
        id: _uuid.v4(),
        serverId: serverId,
        service: 'sshd',
        timestamp: _parseTimestamp(sshInvalidMatch, trimmed),
        clientIp: ip,
        user: user,
        status: EventStatus.failed,
        severity: EventSeverity.critical,
        riskScore: 92,
        failureReason: 'Invalid / non-existent user probe',
        rawLog: trimmed,
      );
    }

    // 7. Check PAM Authentication Failure
    final pamMatch = _pamFailedRegex.firstMatch(trimmed);
    if (pamMatch != null) {
      final user = _sanitizeString(pamMatch.namedGroup('user') ?? 'root');
      final ip = _cleanIp(pamMatch.namedGroup('ip') ?? '0.0.0.0');

      return AuthEvent(
        id: _uuid.v4(),
        serverId: serverId,
        service: 'sshd',
        timestamp: _parseTimestamp(pamMatch, trimmed),
        clientIp: ip,
        user: user,
        status: EventStatus.failed,
        severity: (user == 'root' || user == 'admin') ? EventSeverity.critical : EventSeverity.warning,
        riskScore: 88,
        failureReason: 'PAM authentication failure for $user',
        rawLog: trimmed,
      );
    }

    // 8. Check Fail2ban Ban / Unban
    final f2bMatch = _fail2banActionRegex.firstMatch(trimmed);
    if (f2bMatch != null) {
      final jail = _sanitizeString(f2bMatch.namedGroup('jail') ?? 'sshd');
      final action = _sanitizeString(f2bMatch.namedGroup('action') ?? 'Ban');
      final ip = _cleanIp(f2bMatch.namedGroup('ip') ?? '0.0.0.0');
      final isBan = action.toLowerCase() == 'ban';

      return AuthEvent(
        id: _uuid.v4(),
        serverId: serverId,
        service: jail.contains('mysql') ? 'mysqld' : 'sshd',
        timestamp: _parseTimestamp(f2bMatch, trimmed),
        clientIp: ip,
        user: 'system',
        status: isBan ? EventStatus.blocked : EventStatus.success,
        severity: isBan ? EventSeverity.critical : EventSeverity.info,
        riskScore: isBan ? 95 : 10,
        failureReason: isBan ? 'Blocked by Fail2ban jail [$jail]' : 'Unbanned by Fail2ban jail [$jail]',
        rawLog: trimmed,
      );
    }

    return null;
  }

  DateTime _parseTimestamp(RegExpMatch? match, String rawLine) {
    if (match != null && match.groupNames.contains("time")) {
      final timeStr = match.namedGroup("time");
      if (timeStr != null) {
        final isoCandidate = timeStr.contains("T") ? timeStr : timeStr.replaceAll(" ", "T");
        final parsedIso = DateTime.tryParse(isoCandidate);
        if (parsedIso != null) return parsedIso;

        try {
          final monthStr = match.groupNames.contains("month") ? match.namedGroup("month") : null;
          final dayStr = match.groupNames.contains("day") ? match.namedGroup("day") : null;
          if (monthStr != null && dayStr != null) {
            final now = DateTime.now();
            final months = {
              "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
              "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
            };
            final month = months[monthStr.toLowerCase()] ?? now.month;
            final day = int.tryParse(dayStr) ?? now.day;
            final timeParts = timeStr.split(":");
            if (timeParts.length == 3) {
              final h = int.tryParse(timeParts[0]) ?? 0;
              final m = int.tryParse(timeParts[1]) ?? 0;
              final s = int.tryParse(timeParts[2]) ?? 0;
              var year = now.year;
              if (month > now.month + 1) year -= 1;
              return DateTime(year, month, day, h, m, s);
            }
          }
        } catch (_) {}
      }
    }

    final isoMatch = RegExp(r"(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})").firstMatch(rawLine);
    if (isoMatch != null) {
      final parsed = DateTime.tryParse(isoMatch.group(1)!.replaceAll(" ", "T"));
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  String _cleanIp(String ip) {
    var cleaned = ip.trim();
    if (cleaned.startsWith('::ffff:')) {
      cleaned = cleaned.substring(7);
    }
    // Strip trailing port if present (e.g. 1.2.3.4:5678)
    if (cleaned.contains(':') && !cleaned.contains('::')) {
      final parts = cleaned.split(':');
      if (parts.length == 2 && int.tryParse(parts[1]) != null) {
        cleaned = parts[0];
      }
    }
    // Whitelist characters
    if (!_safeIpRegex.hasMatch(cleaned)) {
      return '0.0.0.0';
    }
    return cleaned;
  }

  String _sanitizeString(String val) {
    return val.replaceAll(RegExp(r'[\r\n\t]'), ' ').trim();
  }
}
