import 'package:flutter/material.dart';

class DownloadDateFormatter {
  const DownloadDateFormatter._();

  static String format(
    DateTime completedAt, {
    required DateTime now,
    required MaterialLocalizations localizations,
    bool alwaysUse24HourFormat = false,
  }) {
    final completed = completedAt.toLocal();
    final current = now.toLocal();
    final elapsed = current.difference(completed);
    if (!elapsed.isNegative && elapsed < const Duration(minutes: 1)) {
      return 'Just now';
    }
    final completedDay = DateTime(
      completed.year,
      completed.month,
      completed.day,
    );
    final today = DateTime(current.year, current.month, current.day);
    final yesterday = DateTime(current.year, current.month, current.day - 1);
    final day = completedDay == today
        ? 'Today'
        : completedDay == yesterday
        ? 'Yesterday'
        : null;
    if (day == null || elapsed.isNegative) {
      return localizations.formatShortDate(completed);
    }
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(completed),
      alwaysUse24HourFormat: alwaysUse24HourFormat,
    );
    return '$day • $time';
  }
}
