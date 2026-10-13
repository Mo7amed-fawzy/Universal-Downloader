// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LinkCacheEntriesTable extends LinkCacheEntries
    with TableInfo<$LinkCacheEntriesTable, LinkCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LinkCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    payload,
    expiresAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'link_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LinkCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  LinkCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LinkCacheEntry(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LinkCacheEntriesTable createAlias(String alias) {
    return $LinkCacheEntriesTable(attachedDatabase, alias);
  }
}

class LinkCacheEntry extends DataClass implements Insertable<LinkCacheEntry> {
  final String cacheKey;
  final String payload;
  final DateTime expiresAt;
  final DateTime createdAt;
  const LinkCacheEntry({
    required this.cacheKey,
    required this.payload,
    required this.expiresAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload'] = Variable<String>(payload);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LinkCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return LinkCacheEntriesCompanion(
      cacheKey: Value(cacheKey),
      payload: Value(payload),
      expiresAt: Value(expiresAt),
      createdAt: Value(createdAt),
    );
  }

  factory LinkCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LinkCacheEntry(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payload: serializer.fromJson<String>(json['payload']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payload': serializer.toJson<String>(payload),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LinkCacheEntry copyWith({
    String? cacheKey,
    String? payload,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) => LinkCacheEntry(
    cacheKey: cacheKey ?? this.cacheKey,
    payload: payload ?? this.payload,
    expiresAt: expiresAt ?? this.expiresAt,
    createdAt: createdAt ?? this.createdAt,
  );
  LinkCacheEntry copyWithCompanion(LinkCacheEntriesCompanion data) {
    return LinkCacheEntry(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LinkCacheEntry(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, payload, expiresAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkCacheEntry &&
          other.cacheKey == this.cacheKey &&
          other.payload == this.payload &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt);
}

class LinkCacheEntriesCompanion extends UpdateCompanion<LinkCacheEntry> {
  final Value<String> cacheKey;
  final Value<String> payload;
  final Value<DateTime> expiresAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LinkCacheEntriesCompanion({
    this.cacheKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LinkCacheEntriesCompanion.insert({
    required String cacheKey,
    required String payload,
    required DateTime expiresAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payload = Value(payload),
       expiresAt = Value(expiresAt),
       createdAt = Value(createdAt);
  static Insertable<LinkCacheEntry> custom({
    Expression<String>? cacheKey,
    Expression<String>? payload,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payload != null) 'payload': payload,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LinkCacheEntriesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? payload,
    Value<DateTime>? expiresAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LinkCacheEntriesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      payload: payload ?? this.payload,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LinkCacheEntriesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadRecordsTable extends DownloadRecords
    with TableInfo<$DownloadRecordsTable, DownloadRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerNameMeta = const VerificationMeta(
    'providerName',
  );
  @override
  late final GeneratedColumn<String> providerName = GeneratedColumn<String>(
    'provider_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMillisecondsMeta =
      const VerificationMeta('durationMilliseconds');
  @override
  late final GeneratedColumn<int> durationMilliseconds = GeneratedColumn<int>(
    'duration_milliseconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoLabelMeta = const VerificationMeta(
    'videoLabel',
  );
  @override
  late final GeneratedColumn<String> videoLabel = GeneratedColumn<String>(
    'video_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioLabelMeta = const VerificationMeta(
    'audioLabel',
  );
  @override
  late final GeneratedColumn<String> audioLabel = GeneratedColumn<String>(
    'audio_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputLocationMeta = const VerificationMeta(
    'outputLocation',
  );
  @override
  late final GeneratedColumn<String> outputLocation = GeneratedColumn<String>(
    'output_location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    taskId,
    mediaId,
    providerId,
    providerName,
    title,
    sourceUrl,
    thumbnailUrl,
    durationMilliseconds,
    videoLabel,
    audioLabel,
    outputLocation,
    optionsJson,
    startedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('provider_name')) {
      context.handle(
        _providerNameMeta,
        providerName.isAcceptableOrUnknown(
          data['provider_name']!,
          _providerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerNameMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('duration_milliseconds')) {
      context.handle(
        _durationMillisecondsMeta,
        durationMilliseconds.isAcceptableOrUnknown(
          data['duration_milliseconds']!,
          _durationMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('video_label')) {
      context.handle(
        _videoLabelMeta,
        videoLabel.isAcceptableOrUnknown(data['video_label']!, _videoLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_videoLabelMeta);
    }
    if (data.containsKey('audio_label')) {
      context.handle(
        _audioLabelMeta,
        audioLabel.isAcceptableOrUnknown(data['audio_label']!, _audioLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_audioLabelMeta);
    }
    if (data.containsKey('output_location')) {
      context.handle(
        _outputLocationMeta,
        outputLocation.isAcceptableOrUnknown(
          data['output_location']!,
          _outputLocationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outputLocationMeta);
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_optionsJsonMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId};
  @override
  DownloadRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRecord(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      providerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_name'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      durationMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_milliseconds'],
      ),
      videoLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_label'],
      )!,
      audioLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_label'],
      )!,
      outputLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_location'],
      )!,
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $DownloadRecordsTable createAlias(String alias) {
    return $DownloadRecordsTable(attachedDatabase, alias);
  }
}

class DownloadRecord extends DataClass implements Insertable<DownloadRecord> {
  final String taskId;
  final String mediaId;
  final String providerId;
  final String providerName;
  final String title;
  final String sourceUrl;
  final String? thumbnailUrl;
  final int? durationMilliseconds;
  final String videoLabel;
  final String audioLabel;
  final String outputLocation;
  final String optionsJson;
  final DateTime? startedAt;
  final DateTime completedAt;
  const DownloadRecord({
    required this.taskId,
    required this.mediaId,
    required this.providerId,
    required this.providerName,
    required this.title,
    required this.sourceUrl,
    this.thumbnailUrl,
    this.durationMilliseconds,
    required this.videoLabel,
    required this.audioLabel,
    required this.outputLocation,
    required this.optionsJson,
    this.startedAt,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['media_id'] = Variable<String>(mediaId);
    map['provider_id'] = Variable<String>(providerId);
    map['provider_name'] = Variable<String>(providerName);
    map['title'] = Variable<String>(title);
    map['source_url'] = Variable<String>(sourceUrl);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || durationMilliseconds != null) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds);
    }
    map['video_label'] = Variable<String>(videoLabel);
    map['audio_label'] = Variable<String>(audioLabel);
    map['output_location'] = Variable<String>(outputLocation);
    map['options_json'] = Variable<String>(optionsJson);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  DownloadRecordsCompanion toCompanion(bool nullToAbsent) {
    return DownloadRecordsCompanion(
      taskId: Value(taskId),
      mediaId: Value(mediaId),
      providerId: Value(providerId),
      providerName: Value(providerName),
      title: Value(title),
      sourceUrl: Value(sourceUrl),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationMilliseconds: durationMilliseconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMilliseconds),
      videoLabel: Value(videoLabel),
      audioLabel: Value(audioLabel),
      outputLocation: Value(outputLocation),
      optionsJson: Value(optionsJson),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: Value(completedAt),
    );
  }

  factory DownloadRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRecord(
      taskId: serializer.fromJson<String>(json['taskId']),
      mediaId: serializer.fromJson<String>(json['mediaId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      providerName: serializer.fromJson<String>(json['providerName']),
      title: serializer.fromJson<String>(json['title']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationMilliseconds: serializer.fromJson<int?>(
        json['durationMilliseconds'],
      ),
      videoLabel: serializer.fromJson<String>(json['videoLabel']),
      audioLabel: serializer.fromJson<String>(json['audioLabel']),
      outputLocation: serializer.fromJson<String>(json['outputLocation']),
      optionsJson: serializer.fromJson<String>(json['optionsJson']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'mediaId': serializer.toJson<String>(mediaId),
      'providerId': serializer.toJson<String>(providerId),
      'providerName': serializer.toJson<String>(providerName),
      'title': serializer.toJson<String>(title),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationMilliseconds': serializer.toJson<int?>(durationMilliseconds),
      'videoLabel': serializer.toJson<String>(videoLabel),
      'audioLabel': serializer.toJson<String>(audioLabel),
      'outputLocation': serializer.toJson<String>(outputLocation),
      'optionsJson': serializer.toJson<String>(optionsJson),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  DownloadRecord copyWith({
    String? taskId,
    String? mediaId,
    String? providerId,
    String? providerName,
    String? title,
    String? sourceUrl,
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<int?> durationMilliseconds = const Value.absent(),
    String? videoLabel,
    String? audioLabel,
    String? outputLocation,
    String? optionsJson,
    Value<DateTime?> startedAt = const Value.absent(),
    DateTime? completedAt,
  }) => DownloadRecord(
    taskId: taskId ?? this.taskId,
    mediaId: mediaId ?? this.mediaId,
    providerId: providerId ?? this.providerId,
    providerName: providerName ?? this.providerName,
    title: title ?? this.title,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    durationMilliseconds: durationMilliseconds.present
        ? durationMilliseconds.value
        : this.durationMilliseconds,
    videoLabel: videoLabel ?? this.videoLabel,
    audioLabel: audioLabel ?? this.audioLabel,
    outputLocation: outputLocation ?? this.outputLocation,
    optionsJson: optionsJson ?? this.optionsJson,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt ?? this.completedAt,
  );
  DownloadRecord copyWithCompanion(DownloadRecordsCompanion data) {
    return DownloadRecord(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      providerName: data.providerName.present
          ? data.providerName.value
          : this.providerName,
      title: data.title.present ? data.title.value : this.title,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationMilliseconds: data.durationMilliseconds.present
          ? data.durationMilliseconds.value
          : this.durationMilliseconds,
      videoLabel: data.videoLabel.present
          ? data.videoLabel.value
          : this.videoLabel,
      audioLabel: data.audioLabel.present
          ? data.audioLabel.value
          : this.audioLabel,
      outputLocation: data.outputLocation.present
          ? data.outputLocation.value
          : this.outputLocation,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRecord(')
          ..write('taskId: $taskId, ')
          ..write('mediaId: $mediaId, ')
          ..write('providerId: $providerId, ')
          ..write('providerName: $providerName, ')
          ..write('title: $title, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('videoLabel: $videoLabel, ')
          ..write('audioLabel: $audioLabel, ')
          ..write('outputLocation: $outputLocation, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    taskId,
    mediaId,
    providerId,
    providerName,
    title,
    sourceUrl,
    thumbnailUrl,
    durationMilliseconds,
    videoLabel,
    audioLabel,
    outputLocation,
    optionsJson,
    startedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRecord &&
          other.taskId == this.taskId &&
          other.mediaId == this.mediaId &&
          other.providerId == this.providerId &&
          other.providerName == this.providerName &&
          other.title == this.title &&
          other.sourceUrl == this.sourceUrl &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationMilliseconds == this.durationMilliseconds &&
          other.videoLabel == this.videoLabel &&
          other.audioLabel == this.audioLabel &&
          other.outputLocation == this.outputLocation &&
          other.optionsJson == this.optionsJson &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt);
}

class DownloadRecordsCompanion extends UpdateCompanion<DownloadRecord> {
  final Value<String> taskId;
  final Value<String> mediaId;
  final Value<String> providerId;
  final Value<String> providerName;
  final Value<String> title;
  final Value<String> sourceUrl;
  final Value<String?> thumbnailUrl;
  final Value<int?> durationMilliseconds;
  final Value<String> videoLabel;
  final Value<String> audioLabel;
  final Value<String> outputLocation;
  final Value<String> optionsJson;
  final Value<DateTime?> startedAt;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const DownloadRecordsCompanion({
    this.taskId = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.providerName = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationMilliseconds = const Value.absent(),
    this.videoLabel = const Value.absent(),
    this.audioLabel = const Value.absent(),
    this.outputLocation = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadRecordsCompanion.insert({
    required String taskId,
    required String mediaId,
    required String providerId,
    required String providerName,
    required String title,
    required String sourceUrl,
    this.thumbnailUrl = const Value.absent(),
    this.durationMilliseconds = const Value.absent(),
    required String videoLabel,
    required String audioLabel,
    required String outputLocation,
    required String optionsJson,
    this.startedAt = const Value.absent(),
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       mediaId = Value(mediaId),
       providerId = Value(providerId),
       providerName = Value(providerName),
       title = Value(title),
       sourceUrl = Value(sourceUrl),
       videoLabel = Value(videoLabel),
       audioLabel = Value(audioLabel),
       outputLocation = Value(outputLocation),
       optionsJson = Value(optionsJson),
       completedAt = Value(completedAt);
  static Insertable<DownloadRecord> custom({
    Expression<String>? taskId,
    Expression<String>? mediaId,
    Expression<String>? providerId,
    Expression<String>? providerName,
    Expression<String>? title,
    Expression<String>? sourceUrl,
    Expression<String>? thumbnailUrl,
    Expression<int>? durationMilliseconds,
    Expression<String>? videoLabel,
    Expression<String>? audioLabel,
    Expression<String>? outputLocation,
    Expression<String>? optionsJson,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (mediaId != null) 'media_id': mediaId,
      if (providerId != null) 'provider_id': providerId,
      if (providerName != null) 'provider_name': providerName,
      if (title != null) 'title': title,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationMilliseconds != null)
        'duration_milliseconds': durationMilliseconds,
      if (videoLabel != null) 'video_label': videoLabel,
      if (audioLabel != null) 'audio_label': audioLabel,
      if (outputLocation != null) 'output_location': outputLocation,
      if (optionsJson != null) 'options_json': optionsJson,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadRecordsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? mediaId,
    Value<String>? providerId,
    Value<String>? providerName,
    Value<String>? title,
    Value<String>? sourceUrl,
    Value<String?>? thumbnailUrl,
    Value<int?>? durationMilliseconds,
    Value<String>? videoLabel,
    Value<String>? audioLabel,
    Value<String>? outputLocation,
    Value<String>? optionsJson,
    Value<DateTime?>? startedAt,
    Value<DateTime>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadRecordsCompanion(
      taskId: taskId ?? this.taskId,
      mediaId: mediaId ?? this.mediaId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      title: title ?? this.title,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMilliseconds: durationMilliseconds ?? this.durationMilliseconds,
      videoLabel: videoLabel ?? this.videoLabel,
      audioLabel: audioLabel ?? this.audioLabel,
      outputLocation: outputLocation ?? this.outputLocation,
      optionsJson: optionsJson ?? this.optionsJson,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (providerName.present) {
      map['provider_name'] = Variable<String>(providerName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationMilliseconds.present) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds.value);
    }
    if (videoLabel.present) {
      map['video_label'] = Variable<String>(videoLabel.value);
    }
    if (audioLabel.present) {
      map['audio_label'] = Variable<String>(audioLabel.value);
    }
    if (outputLocation.present) {
      map['output_location'] = Variable<String>(outputLocation.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRecordsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('mediaId: $mediaId, ')
          ..write('providerId: $providerId, ')
          ..write('providerName: $providerName, ')
          ..write('title: $title, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('videoLabel: $videoLabel, ')
          ..write('audioLabel: $audioLabel, ')
          ..write('outputLocation: $outputLocation, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingDownloadsTable extends PendingDownloads
    with TableInfo<$PendingDownloadsTable, PendingDownload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingDownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerNameMeta = const VerificationMeta(
    'providerName',
  );
  @override
  late final GeneratedColumn<String> providerName = GeneratedColumn<String>(
    'provider_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaJsonMeta = const VerificationMeta(
    'mediaJson',
  );
  @override
  late final GeneratedColumn<String> mediaJson = GeneratedColumn<String>(
    'media_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoLabelMeta = const VerificationMeta(
    'videoLabel',
  );
  @override
  late final GeneratedColumn<String> videoLabel = GeneratedColumn<String>(
    'video_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioLabelMeta = const VerificationMeta(
    'audioLabel',
  );
  @override
  late final GeneratedColumn<String> audioLabel = GeneratedColumn<String>(
    'audio_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    taskId,
    providerId,
    providerName,
    mediaJson,
    optionsJson,
    title,
    videoLabel,
    audioLabel,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingDownload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('provider_name')) {
      context.handle(
        _providerNameMeta,
        providerName.isAcceptableOrUnknown(
          data['provider_name']!,
          _providerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerNameMeta);
    }
    if (data.containsKey('media_json')) {
      context.handle(
        _mediaJsonMeta,
        mediaJson.isAcceptableOrUnknown(data['media_json']!, _mediaJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaJsonMeta);
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_optionsJsonMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('video_label')) {
      context.handle(
        _videoLabelMeta,
        videoLabel.isAcceptableOrUnknown(data['video_label']!, _videoLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_videoLabelMeta);
    }
    if (data.containsKey('audio_label')) {
      context.handle(
        _audioLabelMeta,
        audioLabel.isAcceptableOrUnknown(data['audio_label']!, _audioLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_audioLabelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId};
  @override
  PendingDownload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingDownload(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      providerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_name'],
      )!,
      mediaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_json'],
      )!,
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      videoLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_label'],
      )!,
      audioLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_label'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingDownloadsTable createAlias(String alias) {
    return $PendingDownloadsTable(attachedDatabase, alias);
  }
}

class PendingDownload extends DataClass implements Insertable<PendingDownload> {
  final String taskId;
  final String providerId;
  final String providerName;
  final String mediaJson;
  final String optionsJson;
  final String title;
  final String videoLabel;
  final String audioLabel;
  final DateTime createdAt;
  const PendingDownload({
    required this.taskId,
    required this.providerId,
    required this.providerName,
    required this.mediaJson,
    required this.optionsJson,
    required this.title,
    required this.videoLabel,
    required this.audioLabel,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['provider_id'] = Variable<String>(providerId);
    map['provider_name'] = Variable<String>(providerName);
    map['media_json'] = Variable<String>(mediaJson);
    map['options_json'] = Variable<String>(optionsJson);
    map['title'] = Variable<String>(title);
    map['video_label'] = Variable<String>(videoLabel);
    map['audio_label'] = Variable<String>(audioLabel);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingDownloadsCompanion toCompanion(bool nullToAbsent) {
    return PendingDownloadsCompanion(
      taskId: Value(taskId),
      providerId: Value(providerId),
      providerName: Value(providerName),
      mediaJson: Value(mediaJson),
      optionsJson: Value(optionsJson),
      title: Value(title),
      videoLabel: Value(videoLabel),
      audioLabel: Value(audioLabel),
      createdAt: Value(createdAt),
    );
  }

  factory PendingDownload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingDownload(
      taskId: serializer.fromJson<String>(json['taskId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      providerName: serializer.fromJson<String>(json['providerName']),
      mediaJson: serializer.fromJson<String>(json['mediaJson']),
      optionsJson: serializer.fromJson<String>(json['optionsJson']),
      title: serializer.fromJson<String>(json['title']),
      videoLabel: serializer.fromJson<String>(json['videoLabel']),
      audioLabel: serializer.fromJson<String>(json['audioLabel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'providerId': serializer.toJson<String>(providerId),
      'providerName': serializer.toJson<String>(providerName),
      'mediaJson': serializer.toJson<String>(mediaJson),
      'optionsJson': serializer.toJson<String>(optionsJson),
      'title': serializer.toJson<String>(title),
      'videoLabel': serializer.toJson<String>(videoLabel),
      'audioLabel': serializer.toJson<String>(audioLabel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingDownload copyWith({
    String? taskId,
    String? providerId,
    String? providerName,
    String? mediaJson,
    String? optionsJson,
    String? title,
    String? videoLabel,
    String? audioLabel,
    DateTime? createdAt,
  }) => PendingDownload(
    taskId: taskId ?? this.taskId,
    providerId: providerId ?? this.providerId,
    providerName: providerName ?? this.providerName,
    mediaJson: mediaJson ?? this.mediaJson,
    optionsJson: optionsJson ?? this.optionsJson,
    title: title ?? this.title,
    videoLabel: videoLabel ?? this.videoLabel,
    audioLabel: audioLabel ?? this.audioLabel,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingDownload copyWithCompanion(PendingDownloadsCompanion data) {
    return PendingDownload(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      providerName: data.providerName.present
          ? data.providerName.value
          : this.providerName,
      mediaJson: data.mediaJson.present ? data.mediaJson.value : this.mediaJson,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      title: data.title.present ? data.title.value : this.title,
      videoLabel: data.videoLabel.present
          ? data.videoLabel.value
          : this.videoLabel,
      audioLabel: data.audioLabel.present
          ? data.audioLabel.value
          : this.audioLabel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingDownload(')
          ..write('taskId: $taskId, ')
          ..write('providerId: $providerId, ')
          ..write('providerName: $providerName, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('title: $title, ')
          ..write('videoLabel: $videoLabel, ')
          ..write('audioLabel: $audioLabel, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    taskId,
    providerId,
    providerName,
    mediaJson,
    optionsJson,
    title,
    videoLabel,
    audioLabel,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingDownload &&
          other.taskId == this.taskId &&
          other.providerId == this.providerId &&
          other.providerName == this.providerName &&
          other.mediaJson == this.mediaJson &&
          other.optionsJson == this.optionsJson &&
          other.title == this.title &&
          other.videoLabel == this.videoLabel &&
          other.audioLabel == this.audioLabel &&
          other.createdAt == this.createdAt);
}

class PendingDownloadsCompanion extends UpdateCompanion<PendingDownload> {
  final Value<String> taskId;
  final Value<String> providerId;
  final Value<String> providerName;
  final Value<String> mediaJson;
  final Value<String> optionsJson;
  final Value<String> title;
  final Value<String> videoLabel;
  final Value<String> audioLabel;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingDownloadsCompanion({
    this.taskId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.providerName = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.title = const Value.absent(),
    this.videoLabel = const Value.absent(),
    this.audioLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingDownloadsCompanion.insert({
    required String taskId,
    required String providerId,
    required String providerName,
    required String mediaJson,
    required String optionsJson,
    required String title,
    required String videoLabel,
    required String audioLabel,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       providerId = Value(providerId),
       providerName = Value(providerName),
       mediaJson = Value(mediaJson),
       optionsJson = Value(optionsJson),
       title = Value(title),
       videoLabel = Value(videoLabel),
       audioLabel = Value(audioLabel),
       createdAt = Value(createdAt);
  static Insertable<PendingDownload> custom({
    Expression<String>? taskId,
    Expression<String>? providerId,
    Expression<String>? providerName,
    Expression<String>? mediaJson,
    Expression<String>? optionsJson,
    Expression<String>? title,
    Expression<String>? videoLabel,
    Expression<String>? audioLabel,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (providerId != null) 'provider_id': providerId,
      if (providerName != null) 'provider_name': providerName,
      if (mediaJson != null) 'media_json': mediaJson,
      if (optionsJson != null) 'options_json': optionsJson,
      if (title != null) 'title': title,
      if (videoLabel != null) 'video_label': videoLabel,
      if (audioLabel != null) 'audio_label': audioLabel,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingDownloadsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? providerId,
    Value<String>? providerName,
    Value<String>? mediaJson,
    Value<String>? optionsJson,
    Value<String>? title,
    Value<String>? videoLabel,
    Value<String>? audioLabel,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingDownloadsCompanion(
      taskId: taskId ?? this.taskId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      mediaJson: mediaJson ?? this.mediaJson,
      optionsJson: optionsJson ?? this.optionsJson,
      title: title ?? this.title,
      videoLabel: videoLabel ?? this.videoLabel,
      audioLabel: audioLabel ?? this.audioLabel,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (providerName.present) {
      map['provider_name'] = Variable<String>(providerName.value);
    }
    if (mediaJson.present) {
      map['media_json'] = Variable<String>(mediaJson.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (videoLabel.present) {
      map['video_label'] = Variable<String>(videoLabel.value);
    }
    if (audioLabel.present) {
      map['audio_label'] = Variable<String>(audioLabel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingDownloadsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('providerId: $providerId, ')
          ..write('providerName: $providerName, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('title: $title, ')
          ..write('videoLabel: $videoLabel, ')
          ..write('audioLabel: $audioLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LinkCacheEntriesTable linkCacheEntries = $LinkCacheEntriesTable(
    this,
  );
  late final $DownloadRecordsTable downloadRecords = $DownloadRecordsTable(
    this,
  );
  late final $PendingDownloadsTable pendingDownloads = $PendingDownloadsTable(
    this,
  );
  late final Index downloadsCompletedAt = Index(
    'downloads_completed_at',
    'CREATE INDEX downloads_completed_at ON download_records (completed_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    linkCacheEntries,
    downloadRecords,
    pendingDownloads,
    downloadsCompletedAt,
  ];
}

typedef $$LinkCacheEntriesTableCreateCompanionBuilder =
    LinkCacheEntriesCompanion Function({
      required String cacheKey,
      required String payload,
      required DateTime expiresAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LinkCacheEntriesTableUpdateCompanionBuilder =
    LinkCacheEntriesCompanion Function({
      Value<String> cacheKey,
      Value<String> payload,
      Value<DateTime> expiresAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LinkCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LinkCacheEntriesTable> {
  $$LinkCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LinkCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LinkCacheEntriesTable> {
  $$LinkCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LinkCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LinkCacheEntriesTable> {
  $$LinkCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LinkCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LinkCacheEntriesTable,
          LinkCacheEntry,
          $$LinkCacheEntriesTableFilterComposer,
          $$LinkCacheEntriesTableOrderingComposer,
          $$LinkCacheEntriesTableAnnotationComposer,
          $$LinkCacheEntriesTableCreateCompanionBuilder,
          $$LinkCacheEntriesTableUpdateCompanionBuilder,
          (
            LinkCacheEntry,
            BaseReferences<
              _$AppDatabase,
              $LinkCacheEntriesTable,
              LinkCacheEntry
            >,
          ),
          LinkCacheEntry,
          PrefetchHooks Function()
        > {
  $$LinkCacheEntriesTableTableManager(
    _$AppDatabase db,
    $LinkCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LinkCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LinkCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LinkCacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LinkCacheEntriesCompanion(
                cacheKey: cacheKey,
                payload: payload,
                expiresAt: expiresAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String payload,
                required DateTime expiresAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LinkCacheEntriesCompanion.insert(
                cacheKey: cacheKey,
                payload: payload,
                expiresAt: expiresAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LinkCacheEntriesTable, LinkCacheEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LinkCacheEntriesTable,
                    LinkCacheEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LinkCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LinkCacheEntriesTable,
      LinkCacheEntry,
      $$LinkCacheEntriesTableFilterComposer,
      $$LinkCacheEntriesTableOrderingComposer,
      $$LinkCacheEntriesTableAnnotationComposer,
      $$LinkCacheEntriesTableCreateCompanionBuilder,
      $$LinkCacheEntriesTableUpdateCompanionBuilder,
      (
        LinkCacheEntry,
        BaseReferences<_$AppDatabase, $LinkCacheEntriesTable, LinkCacheEntry>,
      ),
      LinkCacheEntry,
      PrefetchHooks Function()
    >;
typedef $$DownloadRecordsTableCreateCompanionBuilder =
    DownloadRecordsCompanion Function({
      required String taskId,
      required String mediaId,
      required String providerId,
      required String providerName,
      required String title,
      required String sourceUrl,
      Value<String?> thumbnailUrl,
      Value<int?> durationMilliseconds,
      required String videoLabel,
      required String audioLabel,
      required String outputLocation,
      required String optionsJson,
      Value<DateTime?> startedAt,
      required DateTime completedAt,
      Value<int> rowid,
    });
typedef $$DownloadRecordsTableUpdateCompanionBuilder =
    DownloadRecordsCompanion Function({
      Value<String> taskId,
      Value<String> mediaId,
      Value<String> providerId,
      Value<String> providerName,
      Value<String> title,
      Value<String> sourceUrl,
      Value<String?> thumbnailUrl,
      Value<int?> durationMilliseconds,
      Value<String> videoLabel,
      Value<String> audioLabel,
      Value<String> outputLocation,
      Value<String> optionsJson,
      Value<DateTime?> startedAt,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });

class $$DownloadRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoLabel => $composableBuilder(
    column: $table.videoLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioLabel => $composableBuilder(
    column: $table.audioLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputLocation => $composableBuilder(
    column: $table.outputLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoLabel => $composableBuilder(
    column: $table.videoLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioLabel => $composableBuilder(
    column: $table.audioLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputLocation => $composableBuilder(
    column: $table.outputLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadRecordsTable> {
  $$DownloadRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoLabel => $composableBuilder(
    column: $table.videoLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioLabel => $composableBuilder(
    column: $table.audioLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputLocation => $composableBuilder(
    column: $table.outputLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadRecordsTable,
          DownloadRecord,
          $$DownloadRecordsTableFilterComposer,
          $$DownloadRecordsTableOrderingComposer,
          $$DownloadRecordsTableAnnotationComposer,
          $$DownloadRecordsTableCreateCompanionBuilder,
          $$DownloadRecordsTableUpdateCompanionBuilder,
          (
            DownloadRecord,
            BaseReferences<
              _$AppDatabase,
              $DownloadRecordsTable,
              DownloadRecord
            >,
          ),
          DownloadRecord,
          PrefetchHooks Function()
        > {
  $$DownloadRecordsTableTableManager(
    _$AppDatabase db,
    $DownloadRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> mediaId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> providerName = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<int?> durationMilliseconds = const Value.absent(),
                Value<String> videoLabel = const Value.absent(),
                Value<String> audioLabel = const Value.absent(),
                Value<String> outputLocation = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadRecordsCompanion(
                taskId: taskId,
                mediaId: mediaId,
                providerId: providerId,
                providerName: providerName,
                title: title,
                sourceUrl: sourceUrl,
                thumbnailUrl: thumbnailUrl,
                durationMilliseconds: durationMilliseconds,
                videoLabel: videoLabel,
                audioLabel: audioLabel,
                outputLocation: outputLocation,
                optionsJson: optionsJson,
                startedAt: startedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String taskId,
                required String mediaId,
                required String providerId,
                required String providerName,
                required String title,
                required String sourceUrl,
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<int?> durationMilliseconds = const Value.absent(),
                required String videoLabel,
                required String audioLabel,
                required String outputLocation,
                required String optionsJson,
                Value<DateTime?> startedAt = const Value.absent(),
                required DateTime completedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadRecordsCompanion.insert(
                taskId: taskId,
                mediaId: mediaId,
                providerId: providerId,
                providerName: providerName,
                title: title,
                sourceUrl: sourceUrl,
                thumbnailUrl: thumbnailUrl,
                durationMilliseconds: durationMilliseconds,
                videoLabel: videoLabel,
                audioLabel: audioLabel,
                outputLocation: outputLocation,
                optionsJson: optionsJson,
                startedAt: startedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadRecordsTable, DownloadRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DownloadRecordsTable,
                    DownloadRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadRecordsTable,
      DownloadRecord,
      $$DownloadRecordsTableFilterComposer,
      $$DownloadRecordsTableOrderingComposer,
      $$DownloadRecordsTableAnnotationComposer,
      $$DownloadRecordsTableCreateCompanionBuilder,
      $$DownloadRecordsTableUpdateCompanionBuilder,
      (
        DownloadRecord,
        BaseReferences<_$AppDatabase, $DownloadRecordsTable, DownloadRecord>,
      ),
      DownloadRecord,
      PrefetchHooks Function()
    >;
typedef $$PendingDownloadsTableCreateCompanionBuilder =
    PendingDownloadsCompanion Function({
      required String taskId,
      required String providerId,
      required String providerName,
      required String mediaJson,
      required String optionsJson,
      required String title,
      required String videoLabel,
      required String audioLabel,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PendingDownloadsTableUpdateCompanionBuilder =
    PendingDownloadsCompanion Function({
      Value<String> taskId,
      Value<String> providerId,
      Value<String> providerName,
      Value<String> mediaJson,
      Value<String> optionsJson,
      Value<String> title,
      Value<String> videoLabel,
      Value<String> audioLabel,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PendingDownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingDownloadsTable> {
  $$PendingDownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoLabel => $composableBuilder(
    column: $table.videoLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioLabel => $composableBuilder(
    column: $table.audioLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingDownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingDownloadsTable> {
  $$PendingDownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoLabel => $composableBuilder(
    column: $table.videoLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioLabel => $composableBuilder(
    column: $table.audioLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingDownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingDownloadsTable> {
  $$PendingDownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaJson =>
      $composableBuilder(column: $table.mediaJson, builder: (column) => column);

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get videoLabel => $composableBuilder(
    column: $table.videoLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioLabel => $composableBuilder(
    column: $table.audioLabel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingDownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingDownloadsTable,
          PendingDownload,
          $$PendingDownloadsTableFilterComposer,
          $$PendingDownloadsTableOrderingComposer,
          $$PendingDownloadsTableAnnotationComposer,
          $$PendingDownloadsTableCreateCompanionBuilder,
          $$PendingDownloadsTableUpdateCompanionBuilder,
          (
            PendingDownload,
            BaseReferences<
              _$AppDatabase,
              $PendingDownloadsTable,
              PendingDownload
            >,
          ),
          PendingDownload,
          PrefetchHooks Function()
        > {
  $$PendingDownloadsTableTableManager(
    _$AppDatabase db,
    $PendingDownloadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingDownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingDownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingDownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> providerName = const Value.absent(),
                Value<String> mediaJson = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> videoLabel = const Value.absent(),
                Value<String> audioLabel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingDownloadsCompanion(
                taskId: taskId,
                providerId: providerId,
                providerName: providerName,
                mediaJson: mediaJson,
                optionsJson: optionsJson,
                title: title,
                videoLabel: videoLabel,
                audioLabel: audioLabel,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String taskId,
                required String providerId,
                required String providerName,
                required String mediaJson,
                required String optionsJson,
                required String title,
                required String videoLabel,
                required String audioLabel,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingDownloadsCompanion.insert(
                taskId: taskId,
                providerId: providerId,
                providerName: providerName,
                mediaJson: mediaJson,
                optionsJson: optionsJson,
                title: title,
                videoLabel: videoLabel,
                audioLabel: audioLabel,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingDownloadsTable, PendingDownload>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingDownloadsTable,
                    PendingDownload
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingDownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingDownloadsTable,
      PendingDownload,
      $$PendingDownloadsTableFilterComposer,
      $$PendingDownloadsTableOrderingComposer,
      $$PendingDownloadsTableAnnotationComposer,
      $$PendingDownloadsTableCreateCompanionBuilder,
      $$PendingDownloadsTableUpdateCompanionBuilder,
      (
        PendingDownload,
        BaseReferences<_$AppDatabase, $PendingDownloadsTable, PendingDownload>,
      ),
      PendingDownload,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LinkCacheEntriesTableTableManager get linkCacheEntries =>
      $$LinkCacheEntriesTableTableManager(_db, _db.linkCacheEntries);
  $$DownloadRecordsTableTableManager get downloadRecords =>
      $$DownloadRecordsTableTableManager(_db, _db.downloadRecords);
  $$PendingDownloadsTableTableManager get pendingDownloads =>
      $$PendingDownloadsTableTableManager(_db, _db.pendingDownloads);
}
