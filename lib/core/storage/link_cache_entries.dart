import 'package:drift/drift.dart';

class LinkCacheEntries extends Table {
  @override
  String get tableName => 'link_cache_entries';

  TextColumn get cacheKey => text().named('cache_key')();
  TextColumn get payload => text().named('payload')();
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {cacheKey};
}
