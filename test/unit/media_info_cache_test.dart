import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/core/storage/app_database.dart';
import 'package:universal_downloader/core/storage/media_info_codec.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';
import 'package:universal_downloader/providers/media_info_cache.dart';

import '../support/controlled_download_provider.dart';
import '../support/persistence_fixtures.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late MediaInfoCache cache;
  late MetadataProvider provider;
  late DateTime now;
  final url = Uri.parse('https://youtu.be/NAEp-qL4VHc?si=tracking');
  const codec = MediaInfoCodec();

  setUp(() {
    root = Directory.systemTemp.createTempSync('link_cache_');
    final paths = QueueTestPaths(root);
    database = AppDatabase.open(paths);
    now = DateTime.utc(2026, 10, 11, 12);
    cache = MediaInfoCache(
      database: database,
      log: LogService(paths: paths),
      now: () => now,
      maxEntries: 2,
    );
    provider = MetadataProvider();
  });

  tearDown(() async {
    await database.close();
    root.deleteSync(recursive: true);
  });

  test(
    'round trips metadata without losing quality, language, HLS or subtitles',
    () {
      final media = cachedMedia();
      expect(
        codec.encode(codec.decode(codec.encode(media))),
        codec.encode(media),
      );
    },
  );

  test(
    'same video URL variants reuse metadata and survive reopening storage',
    () async {
      await cache.fetch(provider, url);
      await database.close();
      database = AppDatabase.open(QueueTestPaths(root));
      cache = MediaInfoCache(
        database: database,
        log: LogService(paths: QueueTestPaths(root)),
        now: () => now,
      );
      for (final link in [
        'https://www.youtube.com/watch?v=NAEp-qL4VHc&t=10',
        'https://www.youtube.com/shorts/NAEp-qL4VHc',
        'https://www.youtube.com/embed/NAEp-qL4VHc',
      ]) {
        final result = await cache.fetch(provider, Uri.parse(link));
        expect(codec.encode(result), codec.encode(cachedMedia()));
      }
      expect(provider.fetches, 1);
    },
  );

  test(
    'expires after five minutes and separates changed extractor settings',
    () async {
      await cache.fetch(provider, url);
      now = now.add(const Duration(minutes: 5));
      await cache.fetch(provider, url);
      expect(provider.fetches, 2);
      await cache.fetch(provider, url, configuration: 'changed-tools');
      expect(provider.fetches, 3);
    },
  );

  test('only successful fetches are cached', () async {
    provider.failure = StateError('network unavailable');
    await expectLater(cache.fetch(provider, url), throwsStateError);
    provider.failure = null;
    await cache.fetch(provider, url);
    await cache.fetch(provider, url);
    expect(provider.fetches, 2);
  });

  test('corrupt cached payload is replaced by fresh metadata', () async {
    await cache.fetch(provider, url);
    await database
        .update(database.linkCacheEntries)
        .write(const LinkCacheEntriesCompanion(payload: Value('{broken')));
    final result = await cache.fetch(provider, url);
    expect(result.id, cachedMedia().id);
    expect(provider.fetches, 2);
  });

  test('deduplicates concurrent requests for the same video', () async {
    final pending = Completer<MediaInfo>();
    provider.pending = pending;
    final first = cache.fetch(provider, url);
    final second = cache.fetch(provider, url);
    expect(identical(first, second), isTrue);
    await provider.started.future;
    expect(provider.fetches, 1);
    pending.complete(cachedMedia());
    await Future.wait([first, second]);
  });

  test(
    'clearing during a fetch prevents the old request from repopulating cache',
    () async {
      final pending = Completer<MediaInfo>();
      provider.pending = pending;
      final first = cache.fetch(provider, url);
      await provider.started.future;
      await cache.clear();
      pending.complete(cachedMedia());
      await first;
      expect(await database.select(database.linkCacheEntries).get(), isEmpty);
      provider.pending = null;
      await cache.fetch(provider, url);
      expect(provider.fetches, 2);
      await cache.clear();
      await cache.fetch(provider, url);
      expect(provider.fetches, 3);
    },
  );

  test('bounds the number of entries and evicts the oldest', () async {
    await cache.fetch(provider, url);
    now = now.add(const Duration(seconds: 1));
    await cache.fetch(provider, Uri.parse('https://youtu.be/abcdefghijk'));
    now = now.add(const Duration(seconds: 1));
    await cache.fetch(provider, Uri.parse('https://youtu.be/12345678901'));
    expect(
      await database.select(database.linkCacheEntries).get(),
      hasLength(2),
    );
    await cache.fetch(provider, url);
    expect(provider.fetches, 4);
  });
}

class MetadataProvider extends Fake implements DownloaderProvider {
  int fetches = 0;
  Object? failure;
  Completer<MediaInfo>? pending;
  final started = Completer<void>();

  @override
  String get id => 'youtube';

  @override
  String get displayName => 'YouTube';

  @override
  Future<MediaInfo> fetchInfo(Uri url) async {
    fetches++;
    if (!started.isCompleted) started.complete();
    if (failure != null) throw failure!;
    return pending == null ? cachedMedia() : pending!.future;
  }
}
