import 'package:drift/drift.dart';

@TableIndex(name: 'downloads_completed_at', columns: {#completedAt})
class DownloadRecords extends Table {
  @override
  String get tableName => 'download_records';

  TextColumn get taskId => text().named('task_id')();
  TextColumn get mediaId => text().named('media_id')();
  TextColumn get providerId => text().named('provider_id')();
  TextColumn get providerName => text().named('provider_name')();
  TextColumn get title => text().named('title')();
  TextColumn get sourceUrl => text().named('source_url')();
  TextColumn get thumbnailUrl => text().named('thumbnail_url').nullable()();
  IntColumn get durationMilliseconds =>
      integer().named('duration_milliseconds').nullable()();
  TextColumn get videoLabel => text().named('video_label')();
  TextColumn get audioLabel => text().named('audio_label')();
  TextColumn get outputLocation => text().named('output_location')();
  TextColumn get optionsJson => text().named('options_json')();
  DateTimeColumn get startedAt => dateTime().named('started_at').nullable()();
  DateTimeColumn get completedAt => dateTime().named('completed_at')();

  @override
  Set<Column> get primaryKey => {taskId};
}
