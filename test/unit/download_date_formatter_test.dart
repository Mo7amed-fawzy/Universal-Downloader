import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/ui/download_date_formatter.dart';

void main() {
  const localizations = DefaultMaterialLocalizations();
  final now = DateTime(2026, 10, 12, 16, 30);

  for (final (completed, expected) in [
    (now.subtract(const Duration(seconds: 59)), 'Just now'),
    (now.subtract(const Duration(minutes: 1)), 'Today • 16:29'),
    (DateTime(2026, 10, 12, 9, 5), 'Today • 09:05'),
    (DateTime(2026, 10, 11, 10, 15), 'Yesterday • 10:15'),
    (DateTime(2026, 10, 10, 23, 59), 'Oct 10, 2026'),
    (DateTime(2025, 10, 12, 10), 'Oct 12, 2025'),
    (now.add(const Duration(minutes: 1)), 'Oct 12, 2026'),
  ]) {
    test('formats $completed as $expected', () {
      expect(
        DownloadDateFormatter.format(
          completed,
          now: now,
          localizations: localizations,
          alwaysUse24HourFormat: true,
        ),
        expected,
      );
    });
  }

  test('uses local calendar days across year boundaries', () {
    expect(
      DownloadDateFormatter.format(
        DateTime(2025, 12, 31, 23).toUtc(),
        now: DateTime(2026, 1, 1, 0, 5).toUtc(),
        localizations: localizations,
      ),
      'Yesterday • 11:00 PM',
    );
  });

  test('just now takes precedence during the first minute after midnight', () {
    expect(
      DownloadDateFormatter.format(
        DateTime(2026, 10, 11, 23, 59, 50),
        now: DateTime(2026, 10, 12, 0, 0, 10),
        localizations: localizations,
      ),
      'Just now',
    );
  });
}
