import 'package:intl/intl.dart';

class DateFormatter {
  static String timeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final h = difference.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final d = difference.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      return DateFormat('MMM d').format(dateTime);
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  static String formatGradYear(int? gradYear) {
    if (gradYear == null || gradYear <= 0) return '';
    return 'Class of $gradYear';
  }

  static String shortGradYear(int? gradYear) {
    if (gradYear == null || gradYear <= 0) return '';
    final str = gradYear.toString();
    if (str.length >= 2) {
      return "'${str.substring(str.length - 2)}";
    }
    return str;
  }
}
