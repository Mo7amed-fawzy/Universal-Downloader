import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../core/models/media_info.dart';
import '../core/services/log_service.dart';
import '../core/storage/app_database.dart';
import '../core/storage/media_info_codec.dart';
import 'downloader_provider.dart';
import 'youtube/youtube_cache_key.dart';

class MediaInfoCache {
  MediaInfoCache({
    required this.database,
    required this.log,
    this.lifetime = const Duration(minutes: 5),
    this.maxEntries = 100,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase database;
  final LogService log;
  final Duration lifetime;
  final int maxEntries;
  final DateTime Function() _now;
  final Map<String, Future<MediaInfo>> _pending = {};
  final _codec = const MediaInfoCodec();
  int _generation = 0;

  Future<MediaInfo> fetch(
    DownloaderProvider provider,
    Uri url, {
    String configuration = '',
  }) {
    final normalized = provider.id == 'youtube'
        ? youtubeCacheKey(url)
        : url.toString();
    final key = sha256
        .convert(
          utf8.encode(jsonEncode([provider.id, normalized, configuration])),
        )
        .toString();
    final pending = _pending[key];
    if (pending != null) return pending;
    final generation = _generation;
    late final Future<MediaInfo> request;
    request = _fetch(provider, url, key, generation).whenComplete(() {
      if (identical(_pending[key], request)) _pending.remove(key);
    });
    _pending[key] = request;
    return request;
  }

  Future<MediaInfo> _fetch(
    DownloaderProvider provider,
    Uri url,
    String key,
    int generation,
  ) async {
    try {
      final entry = await (database.select(
        database.linkCacheEntries,
      )..where((row) => row.cacheKey.equals(key))).getSingleOrNull();
      if (entry != null &&
          entry.expiresAt.isAfter(_now()) &&
          generation == _generation) {
        final info = _codec.decode(entry.payload);
        log.info('Using cached ${provider.displayName} metadata');
        return info;
      }
    } catch (error) {
      log.error('Could not read link cache; fetching fresh metadata: $error');
    }

    final info = await provider.fetchInfo(url);
    if (generation != _generation) return info;
    try {
      final now = _now();
      await database.transaction(() async {
        if (generation != _generation) return;
        await database
            .into(database.linkCacheEntries)
            .insertOnConflictUpdate(
              LinkCacheEntriesCompanion.insert(
                cacheKey: key,
                payload: _codec.encode(info),
                createdAt: now,
                expiresAt: now.add(lifetime),
              ),
            );
        await (database.delete(
          database.linkCacheEntries,
        )..where((row) => row.expiresAt.isSmallerOrEqualValue(now))).go();
        final entries = await (database.select(
          database.linkCacheEntries,
        )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
        final removed = entries
            .skip(maxEntries)
            .map((entry) => entry.cacheKey)
            .toList();
        if (removed.isNotEmpty) {
          await (database.delete(
            database.linkCacheEntries,
          )..where((row) => row.cacheKey.isIn(removed))).go();
        }
      });
    } catch (error) {
      log.error('Could not save link cache: $error');
    }
    return info;
  }

  Future<void> clear() async {
    _generation++;
    _pending.clear();
    await database.delete(database.linkCacheEntries).go();
  }
}
