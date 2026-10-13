import 'package:drift/drift.dart';

import '../core/storage/app_database.dart';
import '../core/storage/media_info_codec.dart';
import 'download_task.dart';

class DownloadRecoveryStore {
  const DownloadRecoveryStore(this.database);

  final AppDatabase database;
  static const _codec = MediaInfoCodec();

  Future<void> save(DownloadTask task) async {
    final row = PendingDownloadsCompanion.insert(
      taskId: task.id,
      providerId: task.providerId,
      providerName: task.providerName,
      mediaJson: _codec.encode(task.media),
      optionsJson: _codec.encodeOptions(task.options),
      title: task.options.title,
      videoLabel: task.videoLabel,
      audioLabel: task.audioLabel,
      createdAt: task.startedAt ?? DateTime.now(),
    );
    await database.into(database.pendingDownloads).insertOnConflictUpdate(row);
  }

  Future<List<DownloadTask>> load() async {
    final rows = await (database.select(
      database.pendingDownloads,
    )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();
    return [for (final row in rows) _restore(row)];
  }

  DownloadTask _restore(PendingDownload row) {
    final media = _codec.decode(row.mediaJson);
    return DownloadTask(
      id: row.taskId,
      media: media,
      options: _codec.decodeOptions(
        row.optionsJson,
        taskId: row.taskId,
        title: row.title,
      ),
      providerId: row.providerId,
      providerName: row.providerName,
      videoLabel: row.videoLabel,
      audioLabel: row.audioLabel,
    )..markInterrupted();
  }

  Future<void> remove(String taskId) async {
    await (database.delete(
      database.pendingDownloads,
    )..where((row) => row.taskId.equals(taskId))).go();
  }
}
