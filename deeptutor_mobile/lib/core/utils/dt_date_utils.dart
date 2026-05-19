/// Date/time formatting helpers used across the app.
abstract final class DtDateUtils {
  /// Returns "Today", "Yesterday", or "d MMM" for older dates.
  static String relativeDay(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final date = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(date).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return '${dt.day} ${_month(dt.month)}';
    } catch (_) {
      return '';
    }
  }

  /// Short time "HH:mm".
  static String shortTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// Returns "HH:mm" if today, otherwise "d MMM".
  static String chatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        return shortTime(isoString);
      }
      return '${dt.day} ${_month(dt.month)}';
    } catch (_) {
      return '';
    }
  }

  /// Full readable timestamp: "18 May 2026, 14:30".
  static String fullTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day} ${_month(dt.month)} ${dt.year}, '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m];
}
