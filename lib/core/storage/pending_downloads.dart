import 'package:drift/drift.dart';

class PendingDownloads extends Table {
  TextColumn get taskId => text()();
  TextColumn get providerId => text()();
  TextColumn get providerName => text()();
  TextColumn get mediaJson => text()();
  TextColumn get optionsJson => text()();
  TextColumn get title => text()();
  TextColumn get videoLabel => text()();
  TextColumn get audioLabel => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {taskId};
}
