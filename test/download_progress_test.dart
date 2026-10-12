import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/process/yt_dlp_progress_parser.dart';
import 'package:universal_downloader/downloads/download_progress.dart';
import 'package:universal_downloader/downloads/download_task.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/ui/widgets/download_tile.dart';

void main() {
  testWidgets(
    'fragment counts prevent early full progress and changing estimates',
    (tester) async {
      final task = createTask();
      addTearDown(task.dispose);
      task.setPhase(DownloadTaskState.downloadingVideo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DownloadTile(task: task)),
        ),
      );
      const parser = YtDlpProgressParser();
      task.setProgress(
        parser.parse('[download] 100.0% of ~ 1.00KiB (frag 0/100)')!,
      );
      expect(task.displayPercent, 0);
      task.setProgress(
        parser.parse(
          '[download] 5.0% of ~ 124.00MiB at 739KiB/s ETA 00:52 (frag 5/100)',
        )!,
      );
      await tester.pump();
      expect(task.progress.downloadedBytes, closeTo(6.2 * 1024 * 1024, 1));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.05, 0.0001),
      );
      expect(find.textContaining('5%'), findsOneWidget);
      expect(find.textContaining('100%'), findsNothing);
      task.setProgress(
        parser.parse('[download] Retrying fragment 2 (1/10)...')!,
      );
      await tester.pump();
      expect(task.displayPercent, 5);
      task.setProgress(
        parser.parse('[download] 100.0% of 124.00MiB in 00:58')!,
      );
      await tester.pump();
      expect(task.displayPercent, 100);
    },
  );

  test(
    'preserves raw estimates and keeps display progress scoped to each phase',
    () {
      final task = createTask();
      addTearDown(task.dispose);
      task.setPhase(DownloadTaskState.downloadingVideo);
      task.setProgress(
        const DownloadProgress(
          percent: 60,
          downloadedBytes: 600,
          totalBytes: 1000,
        ),
      );
      task.setProgress(
        const DownloadProgress(
          percent: 55,
          downloadedBytes: 660,
          totalBytes: 1200,
        ),
      );
      expect(task.progress.percent, 55);
      expect(task.progress.totalBytes, 1200);
      expect(task.displayPercent, 60);
      task.setProgress(
        const DownloadProgress(statusLabel: 'Retrying fragment'),
      );
      expect(task.progress.downloadedBytes, 660);
      expect(task.displayPercent, 60);
      task.setPhase(DownloadTaskState.downloadingVideo);
      expect(task.displayPercent, 60);
      task.setPhase(DownloadTaskState.downloadingAudio);
      expect(task.displayPercent, isNull);
      expect(task.progress.totalBytes, isNull);
      task.setProgress(const DownloadProgress(percent: 20));
      expect(task.displayPercent, 20);
      task.setPhase(DownloadTaskState.merging);
      expect(task.progress.percent, isNull);
      expect(task.displayPercent, isNull);
    },
  );

  test(
    'retry resets display progress and invalid values never reach the bar',
    () {
      final task = createTask();
      addTearDown(task.dispose);
      task.setProgress(const DownloadProgress(percent: double.nan));
      expect(task.displayPercent, isNull);
      task.setProgress(const DownloadProgress(percent: -10));
      expect(task.displayPercent, 0);
      task.setProgress(const DownloadProgress(percent: 110));
      expect(task.displayPercent, 100);
      task.setProgress(const DownloadProgress(percent: double.infinity));
      expect(task.displayPercent, 100);
      task.resetForRetry();
      expect(task.displayPercent, isNull);
      expect(task.progress.percent, isNull);
    },
  );

  testWidgets(
    'progress never reverses on changing estimates or status messages',
    (tester) async {
      final task = createTask();
      addTearDown(task.dispose);
      task.setPhase(DownloadTaskState.downloadingVideo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DownloadTile(task: task)),
          ),
        ),
      );
      const parser = YtDlpProgressParser();
      final updates = [
        (
          '[download] 6.0% of ~ 57.81MiB at 550KiB/s ETA 01:23 (frag 6/100)',
          0.06,
        ),
        (
          '[download] 5.5% of ~ 65.00MiB at 540KiB/s ETA 01:24 (frag 6/100)',
          0.06,
        ),
        ('[download] Retrying fragment 2 (1/10)...', 0.06),
        (
          '[download] 7.0% of ~ 64.00MiB at 570KiB/s ETA 01:20 (frag 7/100)',
          0.07,
        ),
      ];
      for (final (line, expected) in updates) {
        task.setProgress(parser.parse(line)!);
        await tester.pump();
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          closeTo(expected, 0.0001),
        );
      }
      task.setPhase(DownloadTaskState.downloadingAudio);
      await tester.pump();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );
      expect(find.textContaining('57.81'), findsNothing);
      task.setProgress(const DownloadProgress(percent: 2));
      await tester.pump();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.02,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('download card size stays fixed when statistics change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final task = createTask();
    addTearDown(task.dispose);
    task.setPhase(DownloadTaskState.downloadingVideo);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DownloadTile(task: task)),
        ),
      ),
    );
    final cardSize = tester.getSize(find.byType(Card));
    final barRect = tester.getRect(find.byType(LinearProgressIndicator));
    task.setProgress(
      const DownloadProgress(
        percent: 87,
        downloadedBytes: 987654321,
        totalBytes: 1234567890,
        speedBytesPerSecond: 1234567,
        eta: Duration(hours: 12, minutes: 59, seconds: 59),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(Card)), cardSize);
    expect(tester.getRect(find.byType(LinearProgressIndicator)), barRect);
    expect(tester.takeException(), isNull);
  });
}

DownloadTask createTask() => DownloadTask(
  id: 'progress',
  media: MediaInfo(
    id: 'video',
    title: 'SQL joins',
    providerId: 'youtube',
    providerName: 'YouTube',
    pageUrl: Uri.parse('https://youtu.be/test'),
  ),
  options: const DownloadOptions(
    taskId: 'progress',
    outputDirectory: '/tmp',
    title: 'SQL joins',
    videoFormatId: 'video',
  ),
  providerId: 'youtube',
  providerName: 'YouTube',
  videoLabel: '1440p 60fps',
  audioLabel: 'Arabic 129 kbps',
);
