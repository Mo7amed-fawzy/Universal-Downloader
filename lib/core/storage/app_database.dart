import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../utils/path_utils.dart';
import 'download_records.dart';
import 'link_cache_entries.dart';
import 'pending_downloads.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [LinkCacheEntries, DownloadRecords, PendingDownloads])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open(PathUtils paths) {
    final root = paths.appDataDirectory()..createSync(recursive: true);
    return AppDatabase(
      NativeDatabase.createInBackground(File('${root.path}/library.sqlite')),
    );
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(pendingDownloads);
    },
  );
}
