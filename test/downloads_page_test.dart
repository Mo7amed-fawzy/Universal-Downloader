import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/app/routes.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/provider_registry.dart';
import 'package:universal_downloader/ui/pages/downloads_page.dart';
import 'package:universal_downloader/ui/pages/downloads_navigation.dart';
import 'package:universal_downloader/ui/widgets/download_history_entry.dart';
import 'package:universal_downloader/ui/widgets/download_tile.dart';

import 'support/controlled_download_provider.dart';
import 'support/persistence_fixtures.dart';

void main() {
  for (final taskCount in [2, 30]) {
    testWidgets(
      'revealing the last row keeps normal spacing with $taskCount downloads',
      (tester) async {
        tester.view.physicalSize = const Size(1162, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = Directory.systemTemp.createTempSync('history_spacing_');
        addTearDown(() => root.deleteSync(recursive: true));
        final paths = QueueTestPaths(root);
        final manager = DownloadManager(
          registry: ProviderRegistry([]),
          repository: DownloadRepository(paths: paths),
          log: LogService(paths: paths),
        );
        addTearDown(manager.dispose);
        for (var index = 0; index < taskCount; index++) {
          manager.queue.add(
            completedDownload(
              '${root.path}/video-$index.mkv',
              id: 'spacing-$index',
            ),
          );
        }
        final targetId = 'spacing-${taskCount - 1}';
        final target = find.byWidgetPredicate(
          (widget) =>
              widget is DownloadHistoryEntry && widget.task.id == targetId,
        );
        final selectedId = ValueNotifier<String?>(null);
        addTearDown(selectedId.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AppController>.value(
            value: QueueTestController(manager),
            child: MaterialApp(
              home: ValueListenableBuilder<String?>(
                valueListenable: selectedId,
                builder: (context, id, _) => DownloadsPage(initialTaskId: id),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position;
        scroll.jumpTo(scroll.maxScrollExtent);
        await tester.pumpAndSettle();
        final normalBottom = tester.getRect(target).bottom;
        selectedId.value = targetId;
        await tester.pumpAndSettle();
        expect(find.text('Downloaded before'), findsOneWidget);
        if (taskCount == 30) {
          expect(tester.getRect(target).bottom, closeTo(normalBottom, 1));
        }
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Downloaded before'), findsNothing);
        expect(tester.getRect(target).bottom, closeTo(normalBottom, 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'reveals a distant row and clears the arrival highlight after three seconds (reduced motion: $reducedMotion)',
      (tester) async {
        tester.view.physicalSize = reducedMotion
            ? const Size(375, 900)
            : const Size(1162, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = Directory.systemTemp.createTempSync('reveal_history_');
        addTearDown(() => root.deleteSync(recursive: true));
        final paths = QueueTestPaths(root);
        final manager = DownloadManager(
          registry: ProviderRegistry([]),
          repository: DownloadRepository(paths: paths),
          log: LogService(paths: paths),
        );
        addTearDown(manager.dispose);
        for (var index = 0; index < 1000; index++) {
          final task = completedDownload(
            '${root.path}/video-$index.mkv',
            id: 'history-$index',
          );
          if (index % 3 == 0) {
            task.markFailed(
              DownloadFailedException('A longer failure message. ' * 8),
            );
          }
          manager.queue.add(task);
        }
        await tester.pumpWidget(
          ChangeNotifierProvider<AppController>.value(
            value: QueueTestController(manager),
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.linux),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: reducedMotion,
                  textScaler: TextScaler.linear(reducedMotion ? 1.3 : 1),
                ),
                child: child!,
              ),
              onGenerateRoute: generateRoute,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.downloads,
                      arguments: const DownloadsNavigation(
                        taskId: 'history-800',
                      ),
                    ),
                    child: const Text('Reveal previous download'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Reveal previous download'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        final match = find.byWidgetPredicate(
          (widget) =>
              widget is DownloadHistoryEntry && widget.task.id == 'history-800',
        );
        if (!reducedMotion) {
          expect(
            tester.widget<DownloadHistoryEntry>(match).highlightAnimation.value,
            0,
          );
        }
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 450));
        final entry = tester.widget<DownloadHistoryEntry>(match);
        expect(entry.highlighted, isTrue);
        expect(
          entry.highlightAnimation.value,
          reducedMotion ? 1 : inExclusiveRange(0, 1),
        );
        await tester.pump(const Duration(milliseconds: 2450));
        expect(entry.highlightAnimation.value, 1);
        expect(find.text('Downloaded before'), findsOneWidget);
        expect(find.byType(DownloadTile).evaluate().length, lessThan(20));
        final bounds = tester.getRect(match);
        expect(
          bounds.top,
          greaterThan(tester.getBottomLeft(find.text('Clear finished')).dy),
        );
        expect(bounds.bottom, lessThanOrEqualTo(900));
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position;
        expect(scroll.minScrollExtent, lessThan(0));
        expect(scroll.maxScrollExtent, greaterThan(0));
        final arrivalOffset = scroll.pixels;
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Downloaded before'), findsNothing);
        expect(tester.widget<DownloadHistoryEntry>(match).highlighted, isFalse);
        expect(scroll.pixels, arrivalOffset);
        expect(tester.getRect(match).bottom, lessThanOrEqualTo(900));
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
        await tester.pumpAndSettle();
        expect(scroll.pixels, lessThan(0));
        await manager.remove('history-800');
        await tester.pumpAndSettle();
        expect(find.text('Downloaded before'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed subtitle task updates active count and clear action', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('downloads_widget_');
    addTearDown(() => root.deleteSync(recursive: true));
    final paths = QueueTestPaths(root);
    final provider = ControlledDownloadProvider();
    final manager = DownloadManager(
      registry: ProviderRegistry([provider]),
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
    );
    addTearDown(manager.dispose);
    final controller = QueueTestController(manager);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: DownloadsPage()),
      ),
    );
    expect(find.text('No downloads yet'), findsOneWidget);
    manager.add(
      provider: provider,
      media: MediaInfo(
        id: 'task',
        title: 'Test video',
        providerId: provider.id,
        providerName: provider.displayName,
        pageUrl: Uri.parse('https://example.com'),
      ),
      options: DownloadOptions(
        taskId: 'task',
        outputDirectory: root.path,
        title: 'Test',
        videoFormatId: 'video',
      ),
      videoLabel: '720p',
      audioLabel: 'English',
    );
    await tester.pump();
    expect(find.text('1 active'), findsOneWidget);
    provider.calls.single.completeError(
      DownloadFailedException('Subtitle limit reached'),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 active'), findsOneWidget);
    expect(find.text('Subtitle limit reached'), findsOneWidget);
    await tester.tap(find.text('Clear finished'));
    await tester.pumpAndSettle();
    expect(find.text('Clear download history?'), findsOneWidget);
    expect(manager.tasks, hasLength(1));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manager.tasks, hasLength(1));
    await tester.tap(find.text('Clear finished'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(find.text('No downloads yet'), findsOneWidget);
  });

  testWidgets('removing history requires confirmation and keeps the file', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('remove_history_widget_');
    addTearDown(() => root.deleteSync(recursive: true));
    final paths = QueueTestPaths(root);
    final output = File('${root.path}/video.mkv')..writeAsStringSync('video');
    final manager = DownloadManager(
      registry: ProviderRegistry([]),
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
    );
    addTearDown(manager.dispose);
    final task = completedDownload(output.path);
    addTearDown(task.dispose);
    manager.queue.add(task);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: QueueTestController(manager),
        child: const MaterialApp(home: DownloadsPage()),
      ),
    );
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from history?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(task.media.title),
      ),
      findsNothing,
    );
    expect(
      find.text('Downloaded files will stay on your device.'),
      findsOneWidget,
    );
    expect(manager.tasks, hasLength(1));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manager.tasks, hasLength(1));
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(manager.tasks, hasLength(1));
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(manager.tasks, isEmpty);
    expect(output.readAsStringSync(), 'video');
  });

  testWidgets('clear history keeps active and newly finished downloads', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('clear_history_widget_');
    addTearDown(() => root.deleteSync(recursive: true));
    final paths = QueueTestPaths(root);
    final output = File('${root.path}/video.mkv')..writeAsStringSync('video');
    final manager = DownloadManager(
      registry: ProviderRegistry([]),
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
    );
    addTearDown(manager.dispose);
    for (final id in [
      'completed',
      'failed',
      'cancelled',
      'active',
      'finishing',
    ]) {
      final task = completedDownload(output.path, id: id);
      if (id == 'failed') task.markFailed(DownloadFailedException('Failed'));
      if (id == 'cancelled') task.markCancelled();
      if (id == 'active' || id == 'finishing') {
        task.setPhase(DownloadTaskState.downloadingVideo);
      }
      addTearDown(task.dispose);
      manager.queue.add(task);
    }
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: QueueTestController(manager),
        child: const MaterialApp(home: DownloadsPage()),
      ),
    );
    await tester.tap(find.text('Clear finished'));
    await tester.pumpAndSettle();
    expect(manager.tasks, hasLength(5));
    manager.queue.byId('finishing')!.markCompleted(output.path);
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(manager.tasks.map((task) => task.id), ['active', 'finishing']);
    expect(output.readAsStringSync(), 'video');
    expect(tester.takeException(), isNull);
  });
}

class QueueTestController extends Fake implements AppController {
  QueueTestController(this.manager);

  @override
  final DownloadManager manager;

  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  Future<void> openDownload(String location) async {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
