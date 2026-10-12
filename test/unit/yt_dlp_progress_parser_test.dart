import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/process/yt_dlp_progress_parser.dart';

void main() {
  const parser = YtDlpProgressParser();

  test('fragment progress is independent of fluctuating estimated sizes', () {
    for (final estimate in [1024, 2000000, 1000000]) {
      final progress = parser.parse(
        '[download] ud-progress:downloading|400000|NA|$estimate|50000.5|12.2|20|100',
      )!;
      expect(progress.percent, 20);
      expect(progress.downloadedBytes, 400000);
      expect(progress.totalBytes, estimate);
      expect(progress.speedBytesPerSecond, 50001);
      expect(progress.eta, const Duration(seconds: 12));
    }
  });

  test('exact byte counts drive non-fragmented downloads', () {
    final progress = parser.parse(
      '[download] ud-progress:downloading|250|1000|NA|NA|NA|NA|NA',
    )!;
    expect(progress.percent, 25);
    expect(progress.downloadedBytes, 250);
    expect(progress.totalBytes, 1000);
    expect(progress.speedBytesPerSecond, isNull);
    expect(progress.eta, isNull);
  });

  test('unknown sizes report bytes without inventing a percentage', () {
    final progress = parser.parse(
      '[download] ud-progress:downloading|1024|NA|1024|NA|NA|NA|NA',
    )!;
    expect(progress.percent, isNull);
    expect(progress.downloadedBytes, 1024);
    expect(parser.parse('[download] 100.0% of ~ 1.00KiB')!.percent, isNull);
  });

  test('only finished stream reaches 100 even after the last fragment', () {
    expect(
      parser
          .parse('[download] ud-progress:downloading|1000|1000|NA|NA|0|10|10')!
          .percent,
      99,
    );
    expect(
      parser
          .parse('[download] ud-progress:finished|1000|1000|NA|NA|NA|NA|NA')!
          .percent,
      100,
    );
    expect(
      parser.parse('[download] 100% of 1.00MiB at 1MiB/s ETA 00:00')!.percent,
      99,
    );
    expect(parser.parse('[download] 100% of 1.00MiB in 00:01')!.percent, 100);
  });

  test('legacy fragment lines work for already running downloads', () {
    expect(
      parser
          .parse(
            '[download] 22.0% of ~ 19.3MiB at 662KiB/s ETA 00:22 (frag 12/60)',
          )!
          .percent,
      20,
    );
    expect(
      parser
          .parse(
            '[download] 19.0% of ~ 23.0MiB at 662KiB/s ETA 00:23 (frag 13/60)',
          )!
          .percent,
      closeTo(21.6667, 0.001),
    );
  });

  test('malformed or non-finite progress cannot break rendering', () {
    expect(parser.parse('[download] ud-progress:downloading|bad'), isNull);
    expect(parser.parse('[download] ud-progress:error|1|2|3|4|5|6|7'), isNull);
    final progress = parser.parse(
      '[download] ud-progress:downloading|NaN|Infinity|-1|-2|-3|-1|0',
    )!;
    expect(progress.percent, isNull);
    expect(progress.downloadedBytes, isNull);
    expect(progress.totalBytes, isNull);
    expect(progress.speedBytesPerSecond, isNull);
    expect(progress.eta, isNull);
  });
}
