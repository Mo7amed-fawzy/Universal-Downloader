import 'package:drift/drift.dart';

import '../core/models/media_info.dart';
import '../core/storage/app_database.dart';
import '../core/storage/media_info_codec.dart';
import 'download_task.dart';
import 'download_task_state.dart';

class DownloadHistory {
  const DownloadHistory(this.database);

  final AppDatabase database;
  static const _codec = MediaInfoCodec();

  Future<void> save(DownloadTask task) async {
    if (task.state != DownloadTaskState.completed || task.outputPath == null) {
      return;
    }
    await database.transaction(() async {
      await database
          .into(database.downloadRecords)
          .insertOnConflictUpdate(
            DownloadRecordsCompanion.insert(
              taskId: task.id,
              mediaId: task.media.id,
              providerId: task.providerId,
              providerName: task.providerName,
              title: task.media.title,
              sourceUrl: task.media.pageUrl.toString(),
              thumbnailUrl: Value(task.media.thumbnail?.toString()),
              durationMilliseconds: Value(task.media.duration?.inMilliseconds),
              videoLabel: task.videoLabel,
              audioLabel: task.audioLabel,
              outputLocation: task.outputPath!,
              optionsJson: _codec.encodeOptions(task.options),
              startedAt: Value(task.startedAt),
              completedAt: task.completedAt!,
            ),
          );
      await (database.delete(
        database.pendingDownloads,
      )..where((row) => row.taskId.equals(task.id))).go();
    });
  }

  Future<List<DownloadTask>> load() async {
    final rows = await (database.select(
      database.downloadRecords,
    )..orderBy([(row) => OrderingTerm.desc(row.completedAt)])).get();
    return [
      for (final row in rows)
        DownloadTask.completed(
          id: row.taskId,
          media: MediaInfo(
            id: row.mediaId,
            title: row.title,
            providerId: row.providerId,
            providerName: row.providerName,
            pageUrl: Uri.parse(row.sourceUrl),
            thumbnail: row.thumbnailUrl == null
                ? null
                : Uri.parse(row.thumbnailUrl!),
            duration: row.durationMilliseconds == null
                ? null
                : Duration(milliseconds: row.durationMilliseconds!),
          ),
          options: _codec.decodeOptions(
            row.optionsJson,
            taskId: row.taskId,
            title: row.title,
          ),
          providerId: row.providerId,
          providerName: row.providerName,
          videoLabel: row.videoLabel,
          audioLabel: row.audioLabel,
          outputPath: row.outputLocation,
          startedAt: row.startedAt,
          completedAt: row.completedAt,
        ),
    ];
  }

  Future<void> remove(String taskId) async {
    await (database.delete(
      database.downloadRecords,
    )..where((row) => row.taskId.equals(taskId))).go();
  }
}
