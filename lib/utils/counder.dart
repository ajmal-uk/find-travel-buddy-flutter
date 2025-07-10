import 'package:intl/intl.dart';

String formatCount(int count) {
  if (count >= 1000000000) {
    double formatted = count / 1000000000;
    String result = formatted
        .toStringAsFixed(formatted.truncateToDouble() == formatted ? 0 : 2);
    return result.endsWith('.00')
        ? '${result.substring(0, result.length - 3)}B'
        : '${result}B';
  } else if (count >= 1000000) {
    double formatted = count / 1000000;
    String result = formatted
        .toStringAsFixed(formatted.truncateToDouble() == formatted ? 0 : 2);
    return result.endsWith('.00')
        ? '${result.substring(0, result.length - 3)}M'
        : '${result}M';
  } else if (count >= 1000) {
    double formatted = count / 1000;
    String result = formatted
        .toStringAsFixed(formatted.truncateToDouble() == formatted ? 0 : 2);
    return result.endsWith('.00')
        ? '${result.substring(0, result.length - 3)}K'
        : '${result}K';
  }
  return count.toString();
}


String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 31) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      return DateFormat('MMM d').format(timestamp);
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }