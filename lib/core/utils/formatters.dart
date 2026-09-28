import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');
  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  static String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt);
  static String formatTime(DateTime dt) => _timeFormat.format(dt);
  static String formatDate(DateTime dt) => _dateFormat.format(dt);

  static String timeAgo(DateTime dt, {bool isIndonesian = false}) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 45) {
      return isIndonesian ? 'baru saja' : 'just now';
    } else if (diff.inMinutes < 60) {
      return isIndonesian ? '${diff.inMinutes} mnt lalu' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return isIndonesian ? '${diff.inHours} jam lalu' : '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return isIndonesian ? '${diff.inDays} hari lalu' : '${diff.inDays}d ago';
    } else {
      return _dateFormat.format(dt);
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const List<String> suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
