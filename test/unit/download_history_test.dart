import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/core/storage/app_database.dart';
import 'package:universal_downloader/core/storage/media_info_codec.dart';
import 'package:universal_downloader/downloads/download_history.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';
import 'package:universal_downloader/providers/media_info_cache.dart';
import 'package:universal_downloader/providers/provider_registry.dart';

import '../support/controlled_download_provider.dart';
import '../support/persistence_fixtures.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late DownloadHistory history;
  late LogService log;

  setUp(() {
    root = Directory.systemTemp.createTempSync('download_history_');
    final paths = QueueTestPaths(root);
    database = AppDatabase.open(paths);
    history = DownloadHistory(database);
    log = LogService(paths: paths);
  });

  tearDown(() async {
    await database.close();
    root.deleteSync(recursive: true);
  });

  test(
    'completed downloads and selected options survive database reopening',
    () async {
      final output = File('${root.path}/فيديو.mkv')..writeAsStringSync('video');
      final original = completedDownload(output.path);
      await history.save(original);
      await history.save(original);
      await database.close();
      database = AppDatabase.open(QueueTestPaths(root));
      history = DownloadHistory(database);
      final restored = (await history.load()).single;
      expect(restored.id, original.id);
      expect(restored.media.title, original.media.title);
      expect(restored.media.pageUrl, original.media.pageUrl);
      expect(restored.media.duration, original.media.duration);
      expect(restored.media.thumbnail, original.media.thumbnail);
      expect(restored.outputPath, output.path);
      expect(restored.videoLabel, '144p');
      expect(restored.audioLabel, 'Arabic 128 kbps');
      expect(restored.state, DownloadTaskState.completed);
      expect(restored.startedAt?.toUtc(), original.startedAt);
      expect(restored.completedAt?.toUtc(), original.completedAt);
      const codec = MediaInfoCodec();
      expect(
        codec.encodeOptions(restored.options),
        codec.encodeOptions(original.options),
      );
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.single, 1);
    },
  );

  test(
    'Android content URIs are restored without treating them as file paths',
    () async {
      await history.save(
        completedDownload('content://media/external/downloads/42'),
      );
      expect(
        (await history.load()).single.outputPath,
        'content://media/external/downloads/42',
      );
    },
  );

  test(
    'cache clearing leaves download history and video files intact',
    () async {
      final output = File('${root.path}/video.mp4')..writeAsStringSync('keep');
      await history.save(completedDownload(output.path));
      final cache = MediaInfoCache(database: database, log: log);
      await cache.fetch(HistoryMetadataProvider(), cachedMedia().pageUrl);
      await cache.clear();
      expect(await database.select(database.linkCacheEntries).get(), isEmpty);
      expect(await history.load(), hasLength(1));
      expect(output.readAsStringSync(), 'keep');
    },
  );

  test('manager restores and removes history without deleting files', () async {
    final output = File('${root.path}/video.mp4')..writeAsStringSync('keep');
    await history.save(completedDownload(output.path));
    final manager = DownloadManager(
      registry: ProviderRegistry([]),
      repository: DownloadRepository(paths: QueueTestPaths(root)),
      log: log,
      history: history,
    );
    addTearDown(manager.dispose);
    await manager.restoreHistory();
    expect(manager.tasks.single.state, DownloadTaskState.completed);
    expect(manager.activeCount, 0);
    await manager.remove('finished');
    expect(manager.tasks, isEmpty);
    expect(await history.load(), isEmpty);
    expect(output.readAsStringSync(), 'keep');
  });

  for (final storageFails in [false, true]) {
    test(
      'manager persists successful completion; storage failure is reported ($storageFails)',
      () async {
        final provider = ControlledDownloadProvider();
        final manager = DownloadManager(
          registry: ProviderRegistry([provider]),
          repository: DownloadRepository(paths: QueueTestPaths(root)),
          log: log,
          history: storageFails ? FailingHistory(database) : history,
        );
        addTearDown(manager.dispose);
        final original = completedDownload('${root.path}/video.mp4');
        manager.add(
          provider: provider,
          media: original.media,
          options: original.options,
          videoLabel: original.videoLabel,
          audioLabel: original.audioLabel,
        );
        provider.calls.single.complete(
          DownloadTaskResult(
            outputFile: File(original.outputPath!),
            merged: true,
          ),
        );
        await pumpEventQueue();
        await manager.flushHistory();
        await pumpEventQueue();
        expect(manager.tasks.single.state, DownloadTaskState.completed);
        expect(manager.activeCount, 0);
        expect(manager.historyError, storageFails ? isNotNull : isNull);
        expect(await history.load(), hasLength(storageFails ? 0 : 1));
      },
    );
  }
}

class HistoryMetadataProvider extends Fake implements DownloaderProvider {
  @override
  String get id => 'youtube';
  @override
  String get displayName => 'YouTube';
  @override
  Future<MediaInfo> fetchInfo(Uri url) async => cachedMedia();
}

class FailingHistory extends DownloadHistory {
  FailingHistory(super.database);

  @override
  Future<void> save(DownloadTask task) async =>
      throw const FileSystemException('No space');
}
