import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/provider_registry.dart';
import 'package:universal_downloader/ui/pages/downloads_page.dart';

import 'support/controlled_download_provider.dart';
import 'support/persistence_fixtures.dart';

void main() {
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
