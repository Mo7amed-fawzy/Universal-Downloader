import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_progress.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';
import 'package:universal_downloader/providers/provider_registry.dart';
import 'package:universal_downloader/ui/pages/downloads_page.dart';

import 'support/controlled_download_provider.dart';

void main() {
  late Directory root;
  late ControlledDownloadProvider provider;
  late DownloadManager manager;

  setUp(() {
    root = Directory.systemTemp.createTempSync('pause_ui_');
    provider = ControlledDownloadProvider();
    final paths = QueueTestPaths(root);
    manager = DownloadManager(
      registry: ProviderRegistry([provider]),
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
    );
  });

  tearDown(() {
    manager.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> showDownloads(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double scale = 1,
  }) async {
    manager.add(
      provider: provider,
      media: MediaInfo(
        id: 'pause',
        title: 'UNIX vs LINUX Explained: The Most Confused Topic',
        providerId: provider.id,
        providerName: provider.displayName,
        pageUrl: Uri.parse('https://example.com/video'),
      ),
      options: DownloadOptions(
        taskId: 'pause',
        outputDirectory: root.path,
        title: 'Linux',
        videoFormatId: '1440p',
        audioLanguage: 'ar',
      ),
      videoLabel: '1440p 60fps',
      audioLabel: 'Arabic 129 kbps',
    );
    provider.phases.single(DownloadTaskState.downloadingVideo);
    provider.progress.single(
      const DownloadProgress(
        percent: 40,
        downloadedBytes: 4194304,
        totalBytes: 10485760,
        speedBytesPerSecond: 1024,
        eta: Duration(seconds: 17),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: PauseTestController(manager),
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const DownloadsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(375, 850),
      const Size(1162, 900),
      const Size(850, 375),
    ]) {
      testWidgets(
        'pause, resume and confirm cancellation at $size $brightness',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await showDownloads(tester, brightness: brightness, scale: 1.3);
          final task = manager.tasks.single;
          await tester.tap(find.byTooltip('Pause'));
          await tester.pumpAndSettle();
          expect(find.text('Pausing...'), findsOneWidget);
          expect(find.byTooltip('Resume'), findsNothing);
          expect(find.textContaining('ETA'), findsNothing);
          provider.calls.single.completeError(DownloadCancelledException());
          await tester.pumpAndSettle();
          expect(find.text('Paused'), findsOneWidget);
          expect(find.textContaining('40%'), findsOneWidget);
          expect(find.text('0 active'), findsOneWidget);
          await tester.tap(find.byTooltip('Cancel'));
          await tester.pumpAndSettle();
          expect(find.text('Cancel download?'), findsOneWidget);
          expect(task.state, DownloadTaskState.paused);
          await tester.tap(find.text('Keep download'));
          await tester.pumpAndSettle();
          expect(task.state, DownloadTaskState.paused);
          await tester.tap(find.byTooltip('Resume'));
          await tester.pumpAndSettle();
          expect(provider.calls, hasLength(2));
          provider.phases.last(DownloadTaskState.downloadingVideo);
          provider.progress.last(const DownloadProgress(percent: 41));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Cancel'));
          await tester.pumpAndSettle();
          expect(provider.tokens.last.isCancelled, isFalse);
          await tester.tap(find.text('Cancel download'));
          await tester.pumpAndSettle();
          expect(provider.tokens.last.isCancelled, isTrue);
          provider.calls.last.completeError(DownloadCancelledException());
          await tester.pumpAndSettle();
          expect(task.state, DownloadTaskState.cancelled);
          expect(find.byTooltip('Resume'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('dismissal and Escape keep an active transfer running', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showDownloads(tester, scale: 2);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(provider.tokens.single.isCancelled, isFalse);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(provider.tokens.single.isCancelled, isFalse);
    expect(tester.takeException(), isNull);
    provider.calls.single.completeError(DownloadCancelledException());
    await tester.pumpAndSettle();
  });

  testWidgets('completion while confirmation is open keeps the finished file', (
    tester,
  ) async {
    await showDownloads(tester);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    final output = File('${root.path}/finished.mp4')
      ..writeAsStringSync('video');
    provider.calls.single.complete(
      DownloadTaskResult(outputFile: output, merged: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel download'));
    await tester.pumpAndSettle();
    expect(manager.tasks.single.state, DownloadTaskState.completed);
    expect(output.readAsStringSync(), 'video');
    expect(tester.takeException(), isNull);
  });
}

class PauseTestController extends Fake implements AppController {
  PauseTestController(this.manager);

  @override
  final DownloadManager manager;

  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
