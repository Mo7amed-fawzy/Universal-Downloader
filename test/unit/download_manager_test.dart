import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_queue.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/provider_registry.dart';

import '../support/controlled_download_provider.dart';

void main() {
  late Directory root;
  late ControlledDownloadProvider provider;
  late DownloadManager manager;

  setUp(() {
    root = Directory.systemTemp.createTempSync('queue_test_');
    final paths = QueueTestPaths(root);
    provider = ControlledDownloadProvider();
    manager = DownloadManager(
      registry: ProviderRegistry([provider]),
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
      queue: DownloadQueue(maxConcurrent: 1),
    );
  });

  tearDown(() {
    manager.dispose();
    root.deleteSync(recursive: true);
  });

  void add(String id) {
    manager.add(
      provider: provider,
      media: MediaInfo(
        id: id,
        title: id,
        providerId: provider.id,
        providerName: provider.displayName,
        pageUrl: Uri.parse('https://example.com/$id'),
      ),
      options: DownloadOptions(
        taskId: id,
        outputDirectory: root.path,
        title: id,
        videoFormatId: 'video',
      ),
      videoLabel: '720p',
      audioLabel: 'English',
    );
  }

  test('retry executes once and clears active count after failure', () async {
    add('first');
    provider.calls.first.completeError(
      DownloadFailedException('subtitles failed'),
    );
    await pumpEventQueue();
    expect(manager.activeCount, 0);
    await manager.retry('first');
    expect(provider.calls, hasLength(2));
    expect(manager.activeCount, 1);
    provider.calls.last.completeError(
      DownloadFailedException('subtitles failed'),
    );
    await pumpEventQueue();
    expect(manager.activeCount, 0);
    expect(manager.tasks.single.state, DownloadTaskState.failed);
  });

  test(
    'retry respects a full queue and runs when a slot becomes free',
    () async {
      add('first');
      provider.calls.first.completeError(
        DownloadFailedException('subtitles failed'),
      );
      await pumpEventQueue();
      add('second');
      await manager.retry('first');
      expect(provider.calls, hasLength(2));
      expect(manager.tasks.first.state, DownloadTaskState.queued);
      provider.calls[1].completeError(DownloadFailedException('failed'));
      await pumpEventQueue();
      expect(provider.calls, hasLength(3));
      provider.calls[2].completeError(DownloadFailedException('failed'));
      await pumpEventQueue();
      expect(manager.activeCount, 0);
    },
  );

  test('a running task without a phase callback cannot start twice', () async {
    manager.dispose();
    final paths = QueueTestPaths(root);
    manager = DownloadManager(
      registry: ProviderRegistry([provider]),
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
      queue: DownloadQueue(maxConcurrent: 2),
    );
    add('first');
    add('second');
    expect(provider.calls, hasLength(2));
    provider.calls.first.completeError(DownloadFailedException('failed'));
    await pumpEventQueue();
    expect(provider.calls, hasLength(2));
    provider.calls.last.completeError(DownloadFailedException('failed'));
    await pumpEventQueue();
    expect(manager.activeCount, 0);
  });
}
