import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/core/storage/app_database.dart';
import 'package:universal_downloader/core/storage/media_info_codec.dart';
import 'package:universal_downloader/downloads/download_history.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_progress.dart';
import 'package:universal_downloader/downloads/download_queue.dart';
import 'package:universal_downloader/downloads/download_recovery_store.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';
import 'package:universal_downloader/providers/provider_registry.dart';

import '../support/controlled_download_provider.dart';
import '../support/persistence_fixtures.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late DownloadRecoveryStore store;
  late ControlledDownloadProvider provider;
  late DownloadRepository repository;

  setUp(() {
    root = Directory.systemTemp.createTempSync('download_recovery_');
    database = AppDatabase.open(QueueTestPaths(root));
    store = DownloadRecoveryStore(database);
    provider = ControlledDownloadProvider();
    repository = DownloadRepository(paths: QueueTestPaths(root));
  });

  tearDown(() async {
    await database.close();
    root.deleteSync(recursive: true);
  });

  DownloadManager manager({
    DownloadRecoveryStore? recovery,
    List<Duration>? delays,
  }) {
    final result = DownloadManager(
      registry: ProviderRegistry([provider]),
      repository: repository,
      log: LogService(paths: QueueTestPaths(root)),
      recovery: recovery ?? store,
      history: DownloadHistory(database),
      queue: DownloadQueue(maxConcurrent: 1),
      retryDelays: delays ?? const [Duration(days: 1)],
    );
    addTearDown(result.dispose);
    return result;
  }

  void add(DownloadManager manager, String id) {
    final fixture = completedDownload('${root.path}/$id.mkv', id: id);
    manager.add(
      provider: provider,
      media: fixture.media,
      options: fixture.options,
      videoLabel: fixture.videoLabel,
      audioLabel: fixture.audioLabel,
    );
  }

  Future<void> settle(DownloadManager manager) async {
    await manager.flushHistory();
    await pumpEventQueue();
  }

  test(
    'active and queued selections survive reopening, without auto-starting',
    () async {
      final first = manager();
      add(first, 'active');
      add(first, 'queued');
      await settle(first);
      expect(provider.calls, hasLength(1));
      final partial = File(
        '${repository.createTaskDirectory('active').path}/video.part',
      )..writeAsStringSync('partial bytes');
      final closing = first.shutdown();
      provider.calls.single.completeError(DownloadCancelledException());
      await closing;
      expect(partial.readAsStringSync(), 'partial bytes');
      await database.close();
      database = AppDatabase.open(QueueTestPaths(root));
      store = DownloadRecoveryStore(database);
      final reopened = manager();
      await reopened.restoreHistory();
      expect(reopened.tasks.map((task) => task.id), ['active', 'queued']);
      expect(
        reopened.tasks.every(
          (task) => task.state == DownloadTaskState.interrupted,
        ),
        isTrue,
      );
      expect(provider.calls, hasLength(1));
      const codec = MediaInfoCodec();
      expect(
        codec.encode(reopened.tasks.first.media),
        codec.encode(first.tasks.first.media),
      );
      expect(
        codec.encodeOptions(reopened.tasks.first.options),
        codec.encodeOptions(first.tasks.first.options),
      );
      expect(reopened.tasks.first.audioLabel, 'Arabic 128 kbps');
      await reopened.retry('active');
      await reopened.retry('active');
      await settle(reopened);
      expect(provider.calls, hasLength(2));
      provider.calls.last.completeError(
        DownloadFailedException('Permanent failure'),
      );
      await settle(reopened);
      expect((await store.load()).length, 2);
    },
  );

  test('queued cancellation never starts and is not resurrected', () async {
    final downloads = manager();
    add(downloads, 'active');
    add(downloads, 'queued');
    downloads.cancel('queued');
    await settle(downloads);
    expect((await store.load()).map((task) => task.id), ['active']);
    provider.calls.single.completeError(DownloadFailedException('Failure'));
    await settle(downloads);
    expect(provider.calls, hasLength(1));
    expect(downloads.tasks.last.state, DownloadTaskState.cancelled);
  });

  test('pause preserves bytes and selections and resumes only once', () async {
    final downloads = manager();
    add(downloads, 'paused');
    add(downloads, 'next');
    await settle(downloads);
    final task = downloads.tasks.first;
    final originalOptions = task.options;
    final token = task.cancelToken;
    final partial = File(
      '${repository.createTaskDirectory(task.id).path}/video.part',
    )..writeAsStringSync('retained bytes');
    provider.phases.first(DownloadTaskState.downloadingAudio);
    provider.progress.first(const DownloadProgress(percent: 40));
    downloads.pause(task.id);
    downloads.pause(task.id);
    expect(task.state, DownloadTaskState.pausing);
    expect(token.isCancelled, isTrue);
    provider.phases.first(DownloadTaskState.merging);
    provider.progress.first(const DownloadProgress(percent: 99));
    expect(task.state, DownloadTaskState.pausing);
    expect(task.displayPercent, 40);
    await downloads.retry(task.id);
    await downloads.remove(task.id);
    expect(provider.calls, hasLength(1));
    expect(downloads.tasks, hasLength(2));
    provider.calls.first.completeError(DownloadCancelledException());
    await settle(downloads);
    expect(task.state, DownloadTaskState.paused);
    expect(task.displayPercent, 40);
    expect(provider.calls, hasLength(2));
    expect(partial.readAsStringSync(), 'retained bytes');
    expect((await store.load()).map((task) => task.id), ['paused', 'next']);
    await downloads.retry(task.id);
    await downloads.retry(task.id);
    await settle(downloads);
    expect(task.state, DownloadTaskState.queued);
    expect(task.options, same(originalOptions));
    expect(task.cancelToken, isNot(same(token)));
    expect(task.cancelToken.isCancelled, isFalse);
    provider.calls.last.completeError(DownloadFailedException('Done'));
    await settle(downloads);
    expect(provider.calls, hasLength(3));
    provider.calls.last.completeError(DownloadFailedException('Done'));
    await settle(downloads);
  });

  test('queued pause survives restart without starting a transfer', () async {
    final downloads = manager();
    add(downloads, 'queued');
    downloads.pause('queued');
    await settle(downloads);
    expect(provider.calls, isEmpty);
    expect(downloads.tasks.single.state, DownloadTaskState.paused);
    await downloads.shutdown();
    await database.close();
    database = AppDatabase.open(QueueTestPaths(root));
    store = DownloadRecoveryStore(database);
    final reopened = manager();
    await reopened.restoreHistory();
    expect(reopened.tasks.single.state, DownloadTaskState.interrupted);
    expect(provider.calls, isEmpty);
    await reopened.retry('queued');
    await settle(reopened);
    expect(provider.calls, hasLength(1));
    provider.calls.single.completeError(DownloadFailedException('Done'));
    await settle(reopened);
  });

  test('pause stops a pending network retry until manual resume', () async {
    final downloads = manager(delays: [const Duration(milliseconds: 100)]);
    add(downloads, 'network');
    await settle(downloads);
    provider.calls.single.completeError(NetworkException('Disconnected'));
    await settle(downloads);
    expect(downloads.tasks.single.state, DownloadTaskState.waitingForRetry);
    downloads.pause('network');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(downloads.tasks.single.state, DownloadTaskState.paused);
    expect(provider.calls, hasLength(1));
    await downloads.retry('network');
    await settle(downloads);
    expect(provider.calls, hasLength(2));
    provider.calls.last.completeError(DownloadFailedException('Done'));
    await settle(downloads);
  });

  for (final finishPause in [false, true]) {
    test('cancel discards a pause (already stopped: $finishPause)', () async {
      final downloads = manager();
      add(downloads, 'paused');
      await settle(downloads);
      final directory = repository.createTaskDirectory('paused');
      File('${directory.path}/video.part').writeAsStringSync('bytes');
      downloads.pause('paused');
      if (finishPause) {
        provider.calls.single.completeError(DownloadCancelledException());
        await settle(downloads);
      }
      downloads.cancel('paused');
      if (!finishPause) {
        provider.calls.single.completeError(DownloadCancelledException());
      }
      await settle(downloads);
      expect(downloads.tasks.single.state, DownloadTaskState.cancelled);
      expect(directory.existsSync(), isFalse);
      expect(await store.load(), isEmpty);
    });
  }

  for (final pausing in [false, true]) {
    test('stop handles a late network error (pause: $pausing)', () async {
      final downloads = manager();
      add(downloads, 'late');
      await settle(downloads);
      if (pausing) {
        downloads.pause('late');
      } else {
        downloads.cancel('late');
      }
      provider.calls.single.completeError(NetworkException('Socket closed'));
      await settle(downloads);
      expect(
        downloads.tasks.single.state,
        pausing ? DownloadTaskState.paused : DownloadTaskState.cancelled,
      );
      expect(downloads.tasks.single.retryAttempt, 0);
      expect(downloads.activeCount, 0);
    });
  }

  test(
    'storage failure prevents unprotected downloads from starting',
    () async {
      final downloads = manager(recovery: FailingRecoveryStore(database));
      add(downloads, 'unsaved');
      await settle(downloads);
      expect(provider.calls, isEmpty);
      expect(downloads.tasks.single.state, DownloadTaskState.failed);
      expect(downloads.historyError, isNotNull);
    },
  );

  test(
    'transient retry is bounded, preserves task id, and leaves failed task recoverable',
    () async {
      final downloads = manager(delays: [Duration.zero, Duration.zero]);
      add(downloads, 'network');
      await settle(downloads);
      for (var index = 0; index < 3; index++) {
        expect(provider.calls, hasLength(index + 1));
        provider.calls.last.completeError(NetworkException('Connection reset'));
        await settle(downloads);
      }
      expect(downloads.tasks.single.state, DownloadTaskState.failed);
      expect(downloads.tasks.single.retryAttempt, 2);
      expect((await store.load()).single.id, 'network');
    },
  );

  test(
    'waiting retry releases its slot and cancellation removes recovery',
    () async {
      final downloads = manager();
      add(downloads, 'network');
      add(downloads, 'next');
      await settle(downloads);
      provider.calls.first.completeError(NetworkException('Disconnected'));
      await settle(downloads);
      expect(downloads.tasks.first.state, DownloadTaskState.waitingForRetry);
      expect(provider.calls, hasLength(2));
      downloads.cancel('network');
      provider.calls.last.completeError(DownloadFailedException('Permanent'));
      await settle(downloads);
      expect((await store.load()).map((task) => task.id), ['next']);
      expect(downloads.tasks.first.state, DownloadTaskState.cancelled);
    },
  );

  test(
    'completion and removal clear recovery without deleting published files',
    () async {
      final downloads = manager();
      add(downloads, 'finished');
      await settle(downloads);
      final output = File('${root.path}/finished.mkv')
        ..writeAsStringSync('complete');
      provider.calls.single.complete(
        DownloadTaskResult(outputFile: output, merged: true),
      );
      await settle(downloads);
      await settle(downloads);
      expect(await store.load(), isEmpty);
      expect(await DownloadHistory(database).load(), hasLength(1));
      await downloads.remove('finished');
      expect(output.readAsStringSync(), 'complete');
      expect(await store.load(), isEmpty);
      expect(await DownloadHistory(database).load(), isEmpty);
    },
  );

  test('version one migration preserves completed history', () async {
    await DownloadHistory(
      database,
    ).save(completedDownload('${root.path}/keep.mkv'));
    await database.customStatement('DROP TABLE pending_downloads');
    await database.customStatement('PRAGMA user_version = 1');
    await database.close();
    database = AppDatabase.open(QueueTestPaths(root));
    store = DownloadRecoveryStore(database);
    expect((await DownloadHistory(database).load()).single.id, 'finished');
    expect(await store.load(), isEmpty);
    final fixture = completedDownload('unused');
    final task = DownloadTask(
      id: 'recovered',
      media: fixture.media,
      options: fixture.options,
      providerId: fixture.providerId,
      providerName: fixture.providerName,
      videoLabel: fixture.videoLabel,
      audioLabel: fixture.audioLabel,
    );
    await store.save(task);
    expect((await store.load()).single.state, DownloadTaskState.interrupted);
  });
}

class FailingRecoveryStore extends DownloadRecoveryStore {
  FailingRecoveryStore(super.database);

  @override
  Future<void> save(DownloadTask task) async =>
      throw const FileSystemException('No space');
}
