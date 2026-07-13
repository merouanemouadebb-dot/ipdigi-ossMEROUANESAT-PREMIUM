// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SourcesTable extends Sources with TableInfo<$SourcesTable, Source> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
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
  List<GeneratedColumn> get $columns => [id, name, type, configJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<Source> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_configJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Source map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Source(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }
}

class Source extends DataClass implements Insertable<Source> {
  final String id;
  final String name;
  final String type;
  final String configJson;
  final DateTime createdAt;
  const Source({
    required this.id,
    required this.name,
    required this.type,
    required this.configJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['config_json'] = Variable<String>(configJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      configJson: Value(configJson),
      createdAt: Value(createdAt),
    );
  }

  factory Source.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Source(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      configJson: serializer.fromJson<String>(json['configJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'configJson': serializer.toJson<String>(configJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Source copyWith({
    String? id,
    String? name,
    String? type,
    String? configJson,
    DateTime? createdAt,
  }) => Source(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    configJson: configJson ?? this.configJson,
    createdAt: createdAt ?? this.createdAt,
  );
  Source copyWithCompanion(SourcesCompanion data) {
    return Source(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Source(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('configJson: $configJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, configJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Source &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.configJson == this.configJson &&
          other.createdAt == this.createdAt);
}

class SourcesCompanion extends UpdateCompanion<Source> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> configJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.configJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required String name,
    required String type,
    required String configJson,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       configJson = Value(configJson),
       createdAt = Value(createdAt);
  static Insertable<Source> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? configJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (configJson != null) 'config_json': configJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? configJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      configJson: configJson ?? this.configJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
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
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('configJson: $configJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedChannelsTable extends CachedChannels
    with TableInfo<$CachedChannelsTable, CachedChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streamIdMeta = const VerificationMeta(
    'streamId',
  );
  @override
  late final GeneratedColumn<String> streamId = GeneratedColumn<String>(
    'stream_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logoUrlMeta = const VerificationMeta(
    'logoUrl',
  );
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
    'logo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryNameMeta = const VerificationMeta(
    'categoryName',
  );
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
    'category_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropUrlMeta = const VerificationMeta(
    'backdropUrl',
  );
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
    'backdrop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    streamId,
    name,
    logoUrl,
    streamUrl,
    categoryId,
    categoryName,
    kind,
    plot,
    backdropUrl,
    year,
    rating,
    position,
    cachedAt,
    epgChannelId,
    addedAt,
    seriesId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('stream_id')) {
      context.handle(
        _streamIdMeta,
        streamId.isAcceptableOrUnknown(data['stream_id']!, _streamIdMeta),
      );
    } else if (isInserting) {
      context.missing(_streamIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('logo_url')) {
      context.handle(
        _logoUrlMeta,
        logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta),
      );
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_streamUrlMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('category_name')) {
      context.handle(
        _categoryNameMeta,
        categoryName.isAcceptableOrUnknown(
          data['category_name']!,
          _categoryNameMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
        _backdropUrlMeta,
        backdropUrl.isAcceptableOrUnknown(
          data['backdrop_url']!,
          _backdropUrlMeta,
        ),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedChannel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      streamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      logoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_url'],
      ),
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      categoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_name'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      backdropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_url'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      ),
    );
  }

  @override
  $CachedChannelsTable createAlias(String alias) {
    return $CachedChannelsTable(attachedDatabase, alias);
  }
}

class CachedChannel extends DataClass implements Insertable<CachedChannel> {
  final String id;
  final String sourceId;
  final String streamId;
  final String name;
  final String? logoUrl;
  final String streamUrl;
  final String? categoryId;
  final String? categoryName;
  final String kind;
  final String? plot;
  final String? backdropUrl;
  final int? year;
  final double? rating;
  final int position;
  final DateTime cachedAt;

  /// XMLTV channel id - Xtream returns this as `epg_channel_id` next
  /// to `stream_id`, and M3U sources carry it as the `tvg-id`
  /// attribute. Used by the EPG service to map a programme's
  /// `channel="..."` attribute back to the right MediaItem. Nullable
  /// because plenty of M3U channels ship without a tvg-id.
  final String? epgChannelId;

  /// Yayıncının kataloga eklediği tarih. Xtream `added` alanından
  /// gelir. "Yeni Eklenenler" sıralaması ve ana sayfa "Yeni
  /// Eklenenler" rivayetinde kullanılır. M3U/Direct kaynaklarda boş.
  final DateTime? addedAt;

  /// Flat M3U series grouping link. Null for live, movies, series containers,
  /// and all Xtream rows. Set to the parent series container's streamId on
  /// M3U episode rows so the detail page can collect a series' episodes and
  /// the Series grid can hide raw episodes (it shows seriesId IS NULL only).
  final String? seriesId;
  const CachedChannel({
    required this.id,
    required this.sourceId,
    required this.streamId,
    required this.name,
    this.logoUrl,
    required this.streamUrl,
    this.categoryId,
    this.categoryName,
    required this.kind,
    this.plot,
    this.backdropUrl,
    this.year,
    this.rating,
    required this.position,
    required this.cachedAt,
    this.epgChannelId,
    this.addedAt,
    this.seriesId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['stream_id'] = Variable<String>(streamId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    map['stream_url'] = Variable<String>(streamUrl);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || categoryName != null) {
      map['category_name'] = Variable<String>(categoryName);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    map['position'] = Variable<int>(position);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    if (!nullToAbsent || epgChannelId != null) {
      map['epg_channel_id'] = Variable<String>(epgChannelId);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    return map;
  }

  CachedChannelsCompanion toCompanion(bool nullToAbsent) {
    return CachedChannelsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      streamId: Value(streamId),
      name: Value(name),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      streamUrl: Value(streamUrl),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      categoryName: categoryName == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryName),
      kind: Value(kind),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      position: Value(position),
      cachedAt: Value(cachedAt),
      epgChannelId: epgChannelId == null && nullToAbsent
          ? const Value.absent()
          : Value(epgChannelId),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
    );
  }

  factory CachedChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedChannel(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      streamId: serializer.fromJson<String>(json['streamId']),
      name: serializer.fromJson<String>(json['name']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      streamUrl: serializer.fromJson<String>(json['streamUrl']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      categoryName: serializer.fromJson<String?>(json['categoryName']),
      kind: serializer.fromJson<String>(json['kind']),
      plot: serializer.fromJson<String?>(json['plot']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      year: serializer.fromJson<int?>(json['year']),
      rating: serializer.fromJson<double?>(json['rating']),
      position: serializer.fromJson<int>(json['position']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      epgChannelId: serializer.fromJson<String?>(json['epgChannelId']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'streamId': serializer.toJson<String>(streamId),
      'name': serializer.toJson<String>(name),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'streamUrl': serializer.toJson<String>(streamUrl),
      'categoryId': serializer.toJson<String?>(categoryId),
      'categoryName': serializer.toJson<String?>(categoryName),
      'kind': serializer.toJson<String>(kind),
      'plot': serializer.toJson<String?>(plot),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'year': serializer.toJson<int?>(year),
      'rating': serializer.toJson<double?>(rating),
      'position': serializer.toJson<int>(position),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'epgChannelId': serializer.toJson<String?>(epgChannelId),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
      'seriesId': serializer.toJson<String?>(seriesId),
    };
  }

  CachedChannel copyWith({
    String? id,
    String? sourceId,
    String? streamId,
    String? name,
    Value<String?> logoUrl = const Value.absent(),
    String? streamUrl,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> categoryName = const Value.absent(),
    String? kind,
    Value<String?> plot = const Value.absent(),
    Value<String?> backdropUrl = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    int? position,
    DateTime? cachedAt,
    Value<String?> epgChannelId = const Value.absent(),
    Value<DateTime?> addedAt = const Value.absent(),
    Value<String?> seriesId = const Value.absent(),
  }) => CachedChannel(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    streamId: streamId ?? this.streamId,
    name: name ?? this.name,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    streamUrl: streamUrl ?? this.streamUrl,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    categoryName: categoryName.present ? categoryName.value : this.categoryName,
    kind: kind ?? this.kind,
    plot: plot.present ? plot.value : this.plot,
    backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
    year: year.present ? year.value : this.year,
    rating: rating.present ? rating.value : this.rating,
    position: position ?? this.position,
    cachedAt: cachedAt ?? this.cachedAt,
    epgChannelId: epgChannelId.present ? epgChannelId.value : this.epgChannelId,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
  );
  CachedChannel copyWithCompanion(CachedChannelsCompanion data) {
    return CachedChannel(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      streamId: data.streamId.present ? data.streamId.value : this.streamId,
      name: data.name.present ? data.name.value : this.name,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      categoryName: data.categoryName.present
          ? data.categoryName.value
          : this.categoryName,
      kind: data.kind.present ? data.kind.value : this.kind,
      plot: data.plot.present ? data.plot.value : this.plot,
      backdropUrl: data.backdropUrl.present
          ? data.backdropUrl.value
          : this.backdropUrl,
      year: data.year.present ? data.year.value : this.year,
      rating: data.rating.present ? data.rating.value : this.rating,
      position: data.position.present ? data.position.value : this.position,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedChannel(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('streamId: $streamId, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('categoryId: $categoryId, ')
          ..write('categoryName: $categoryName, ')
          ..write('kind: $kind, ')
          ..write('plot: $plot, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('year: $year, ')
          ..write('rating: $rating, ')
          ..write('position: $position, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('addedAt: $addedAt, ')
          ..write('seriesId: $seriesId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    streamId,
    name,
    logoUrl,
    streamUrl,
    categoryId,
    categoryName,
    kind,
    plot,
    backdropUrl,
    year,
    rating,
    position,
    cachedAt,
    epgChannelId,
    addedAt,
    seriesId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedChannel &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.streamId == this.streamId &&
          other.name == this.name &&
          other.logoUrl == this.logoUrl &&
          other.streamUrl == this.streamUrl &&
          other.categoryId == this.categoryId &&
          other.categoryName == this.categoryName &&
          other.kind == this.kind &&
          other.plot == this.plot &&
          other.backdropUrl == this.backdropUrl &&
          other.year == this.year &&
          other.rating == this.rating &&
          other.position == this.position &&
          other.cachedAt == this.cachedAt &&
          other.epgChannelId == this.epgChannelId &&
          other.addedAt == this.addedAt &&
          other.seriesId == this.seriesId);
}

class CachedChannelsCompanion extends UpdateCompanion<CachedChannel> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> streamId;
  final Value<String> name;
  final Value<String?> logoUrl;
  final Value<String> streamUrl;
  final Value<String?> categoryId;
  final Value<String?> categoryName;
  final Value<String> kind;
  final Value<String?> plot;
  final Value<String?> backdropUrl;
  final Value<int?> year;
  final Value<double?> rating;
  final Value<int> position;
  final Value<DateTime> cachedAt;
  final Value<String?> epgChannelId;
  final Value<DateTime?> addedAt;
  final Value<String?> seriesId;
  final Value<int> rowid;
  const CachedChannelsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.streamId = const Value.absent(),
    this.name = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.kind = const Value.absent(),
    this.plot = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.year = const Value.absent(),
    this.rating = const Value.absent(),
    this.position = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedChannelsCompanion.insert({
    required String id,
    required String sourceId,
    required String streamId,
    required String name,
    this.logoUrl = const Value.absent(),
    required String streamUrl,
    this.categoryId = const Value.absent(),
    this.categoryName = const Value.absent(),
    required String kind,
    this.plot = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.year = const Value.absent(),
    this.rating = const Value.absent(),
    this.position = const Value.absent(),
    required DateTime cachedAt,
    this.epgChannelId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       streamId = Value(streamId),
       name = Value(name),
       streamUrl = Value(streamUrl),
       kind = Value(kind),
       cachedAt = Value(cachedAt);
  static Insertable<CachedChannel> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? streamId,
    Expression<String>? name,
    Expression<String>? logoUrl,
    Expression<String>? streamUrl,
    Expression<String>? categoryId,
    Expression<String>? categoryName,
    Expression<String>? kind,
    Expression<String>? plot,
    Expression<String>? backdropUrl,
    Expression<int>? year,
    Expression<double>? rating,
    Expression<int>? position,
    Expression<DateTime>? cachedAt,
    Expression<String>? epgChannelId,
    Expression<DateTime>? addedAt,
    Expression<String>? seriesId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (streamId != null) 'stream_id': streamId,
      if (name != null) 'name': name,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (categoryId != null) 'category_id': categoryId,
      if (categoryName != null) 'category_name': categoryName,
      if (kind != null) 'kind': kind,
      if (plot != null) 'plot': plot,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (year != null) 'year': year,
      if (rating != null) 'rating': rating,
      if (position != null) 'position': position,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (addedAt != null) 'added_at': addedAt,
      if (seriesId != null) 'series_id': seriesId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedChannelsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? streamId,
    Value<String>? name,
    Value<String?>? logoUrl,
    Value<String>? streamUrl,
    Value<String?>? categoryId,
    Value<String?>? categoryName,
    Value<String>? kind,
    Value<String?>? plot,
    Value<String?>? backdropUrl,
    Value<int?>? year,
    Value<double?>? rating,
    Value<int>? position,
    Value<DateTime>? cachedAt,
    Value<String?>? epgChannelId,
    Value<DateTime?>? addedAt,
    Value<String?>? seriesId,
    Value<int>? rowid,
  }) {
    return CachedChannelsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      streamId: streamId ?? this.streamId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      kind: kind ?? this.kind,
      plot: plot ?? this.plot,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      position: position ?? this.position,
      cachedAt: cachedAt ?? this.cachedAt,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      addedAt: addedAt ?? this.addedAt,
      seriesId: seriesId ?? this.seriesId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (streamId.present) {
      map['stream_id'] = Variable<String>(streamId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedChannelsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('streamId: $streamId, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('categoryId: $categoryId, ')
          ..write('categoryName: $categoryName, ')
          ..write('kind: $kind, ')
          ..write('plot: $plot, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('year: $year, ')
          ..write('rating: $rating, ')
          ..write('position: $position, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('addedAt: $addedAt, ')
          ..write('seriesId: $seriesId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDetailsTable extends CachedDetails
    with TableInfo<$CachedDetailsTable, CachedDetail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDetailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streamIdMeta = const VerificationMeta(
    'streamId',
  );
  @override
  late final GeneratedColumn<String> streamId = GeneratedColumn<String>(
    'stream_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _castCsvMeta = const VerificationMeta(
    'castCsv',
  );
  @override
  late final GeneratedColumn<String> castCsv = GeneratedColumn<String>(
    'cast_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directorsCsvMeta = const VerificationMeta(
    'directorsCsv',
  );
  @override
  late final GeneratedColumn<String> directorsCsv = GeneratedColumn<String>(
    'directors_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genresCsvMeta = const VerificationMeta(
    'genresCsv',
  );
  @override
  late final GeneratedColumn<String> genresCsv = GeneratedColumn<String>(
    'genres_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runtimeSecondsMeta = const VerificationMeta(
    'runtimeSeconds',
  );
  @override
  late final GeneratedColumn<int> runtimeSeconds = GeneratedColumn<int>(
    'runtime_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropUrlMeta = const VerificationMeta(
    'backdropUrl',
  );
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
    'backdrop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalTitleMeta = const VerificationMeta(
    'originalTitle',
  );
  @override
  late final GeneratedColumn<String> originalTitle = GeneratedColumn<String>(
    'original_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localizedTitleMeta = const VerificationMeta(
    'localizedTitle',
  );
  @override
  late final GeneratedColumn<String> localizedTitle = GeneratedColumn<String>(
    'localized_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keywordsCsvMeta = const VerificationMeta(
    'keywordsCsv',
  );
  @override
  late final GeneratedColumn<String> keywordsCsv = GeneratedColumn<String>(
    'keywords_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imdbIdMeta = const VerificationMeta('imdbId');
  @override
  late final GeneratedColumn<String> imdbId = GeneratedColumn<String>(
    'imdb_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    streamId,
    kind,
    castCsv,
    directorsCsv,
    genresCsv,
    plot,
    country,
    runtimeSeconds,
    releaseDate,
    coverUrl,
    backdropUrl,
    rating,
    cachedAt,
    originalTitle,
    localizedTitle,
    keywordsCsv,
    imdbId,
    tmdbId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDetail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('stream_id')) {
      context.handle(
        _streamIdMeta,
        streamId.isAcceptableOrUnknown(data['stream_id']!, _streamIdMeta),
      );
    } else if (isInserting) {
      context.missing(_streamIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('cast_csv')) {
      context.handle(
        _castCsvMeta,
        castCsv.isAcceptableOrUnknown(data['cast_csv']!, _castCsvMeta),
      );
    }
    if (data.containsKey('directors_csv')) {
      context.handle(
        _directorsCsvMeta,
        directorsCsv.isAcceptableOrUnknown(
          data['directors_csv']!,
          _directorsCsvMeta,
        ),
      );
    }
    if (data.containsKey('genres_csv')) {
      context.handle(
        _genresCsvMeta,
        genresCsv.isAcceptableOrUnknown(data['genres_csv']!, _genresCsvMeta),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('runtime_seconds')) {
      context.handle(
        _runtimeSecondsMeta,
        runtimeSeconds.isAcceptableOrUnknown(
          data['runtime_seconds']!,
          _runtimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
        _backdropUrlMeta,
        backdropUrl.isAcceptableOrUnknown(
          data['backdrop_url']!,
          _backdropUrlMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('original_title')) {
      context.handle(
        _originalTitleMeta,
        originalTitle.isAcceptableOrUnknown(
          data['original_title']!,
          _originalTitleMeta,
        ),
      );
    }
    if (data.containsKey('localized_title')) {
      context.handle(
        _localizedTitleMeta,
        localizedTitle.isAcceptableOrUnknown(
          data['localized_title']!,
          _localizedTitleMeta,
        ),
      );
    }
    if (data.containsKey('keywords_csv')) {
      context.handle(
        _keywordsCsvMeta,
        keywordsCsv.isAcceptableOrUnknown(
          data['keywords_csv']!,
          _keywordsCsvMeta,
        ),
      );
    }
    if (data.containsKey('imdb_id')) {
      context.handle(
        _imdbIdMeta,
        imdbId.isAcceptableOrUnknown(data['imdb_id']!, _imdbIdMeta),
      );
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedDetail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDetail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      streamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      castCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast_csv'],
      ),
      directorsCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}directors_csv'],
      ),
      genresCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres_csv'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      runtimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}runtime_seconds'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_date'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      backdropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_url'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      originalTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_title'],
      ),
      localizedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}localized_title'],
      ),
      keywordsCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keywords_csv'],
      ),
      imdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imdb_id'],
      ),
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_id'],
      ),
    );
  }

  @override
  $CachedDetailsTable createAlias(String alias) {
    return $CachedDetailsTable(attachedDatabase, alias);
  }
}

class CachedDetail extends DataClass implements Insertable<CachedDetail> {
  final String id;
  final String sourceId;
  final String streamId;
  final String kind;
  final String? castCsv;
  final String? directorsCsv;
  final String? genresCsv;
  final String? plot;
  final String? country;
  final int? runtimeSeconds;
  final String? releaseDate;
  final String? coverUrl;
  final String? backdropUrl;
  final double? rating;
  final DateTime cachedAt;

  /// TMDB'den çözülen orijinal başlık (ör. panel "Kara Şövalye" derken
  /// TMDB "The Dark Knight"). Arama hem panel adı hem original_title
  /// üzerinde çalışıyor; ayrıca detay sayfaları orijinal başlığı altta
  /// italik gösteriyor. Null ise TMDB henüz çözememiş demektir.
  final String? originalTitle;

  /// TMDB'nin lokalize başlığı. Panel'in `name` alanı her zaman
  /// kullanıcının diline çevrili gelmediğinden TMDB'nin verdiği lokalize
  /// başlığı ayrı tutuyoruz; arama indeksi her ikisini birden kontrol
  /// eder.
  final String? localizedTitle;

  /// TMDB `/keywords` çıktısının virgülle ayrılmış lokalize/orijinal
  /// keyword listesi. Kişisel öneri motoru "alien-invasion",
  /// "heist-gone-wrong" gibi keskin sinyaller için bunu kullanır;
  /// sadece genre kümesi öneriyi çok geniş bırakıyordu.
  final String? keywordsCsv;

  /// TMDB `external_ids.imdb_id` - şimdilik UI'da kullanılmıyor ama
  /// gelecekte RT/Letterboxd entegrasyonu için kalıcı tutuyoruz, ikinci
  /// TMDB roundtrip yapmadan eşleştirebilmek için.
  final String? imdbId;

  /// TMDB film/dizi kimliği. Panel-bağımsız evrensel kimlik: aynı film
  /// farklı panellerde de aynı tmdbId'ye sahip olur. Puan/izleme sinyalleri
  /// okuma tarafında bu id üzerinden birleştirilir. TMDB lookup çözülünce
  /// (detay açılışında) yazılır; çözülmemişse null.
  final int? tmdbId;
  const CachedDetail({
    required this.id,
    required this.sourceId,
    required this.streamId,
    required this.kind,
    this.castCsv,
    this.directorsCsv,
    this.genresCsv,
    this.plot,
    this.country,
    this.runtimeSeconds,
    this.releaseDate,
    this.coverUrl,
    this.backdropUrl,
    this.rating,
    required this.cachedAt,
    this.originalTitle,
    this.localizedTitle,
    this.keywordsCsv,
    this.imdbId,
    this.tmdbId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['stream_id'] = Variable<String>(streamId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || castCsv != null) {
      map['cast_csv'] = Variable<String>(castCsv);
    }
    if (!nullToAbsent || directorsCsv != null) {
      map['directors_csv'] = Variable<String>(directorsCsv);
    }
    if (!nullToAbsent || genresCsv != null) {
      map['genres_csv'] = Variable<String>(genresCsv);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || runtimeSeconds != null) {
      map['runtime_seconds'] = Variable<int>(runtimeSeconds);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<String>(releaseDate);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    if (!nullToAbsent || originalTitle != null) {
      map['original_title'] = Variable<String>(originalTitle);
    }
    if (!nullToAbsent || localizedTitle != null) {
      map['localized_title'] = Variable<String>(localizedTitle);
    }
    if (!nullToAbsent || keywordsCsv != null) {
      map['keywords_csv'] = Variable<String>(keywordsCsv);
    }
    if (!nullToAbsent || imdbId != null) {
      map['imdb_id'] = Variable<String>(imdbId);
    }
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    return map;
  }

  CachedDetailsCompanion toCompanion(bool nullToAbsent) {
    return CachedDetailsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      streamId: Value(streamId),
      kind: Value(kind),
      castCsv: castCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(castCsv),
      directorsCsv: directorsCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(directorsCsv),
      genresCsv: genresCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(genresCsv),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      runtimeSeconds: runtimeSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(runtimeSeconds),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      cachedAt: Value(cachedAt),
      originalTitle: originalTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(originalTitle),
      localizedTitle: localizedTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(localizedTitle),
      keywordsCsv: keywordsCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(keywordsCsv),
      imdbId: imdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(imdbId),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
    );
  }

  factory CachedDetail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDetail(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      streamId: serializer.fromJson<String>(json['streamId']),
      kind: serializer.fromJson<String>(json['kind']),
      castCsv: serializer.fromJson<String?>(json['castCsv']),
      directorsCsv: serializer.fromJson<String?>(json['directorsCsv']),
      genresCsv: serializer.fromJson<String?>(json['genresCsv']),
      plot: serializer.fromJson<String?>(json['plot']),
      country: serializer.fromJson<String?>(json['country']),
      runtimeSeconds: serializer.fromJson<int?>(json['runtimeSeconds']),
      releaseDate: serializer.fromJson<String?>(json['releaseDate']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      rating: serializer.fromJson<double?>(json['rating']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      originalTitle: serializer.fromJson<String?>(json['originalTitle']),
      localizedTitle: serializer.fromJson<String?>(json['localizedTitle']),
      keywordsCsv: serializer.fromJson<String?>(json['keywordsCsv']),
      imdbId: serializer.fromJson<String?>(json['imdbId']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'streamId': serializer.toJson<String>(streamId),
      'kind': serializer.toJson<String>(kind),
      'castCsv': serializer.toJson<String?>(castCsv),
      'directorsCsv': serializer.toJson<String?>(directorsCsv),
      'genresCsv': serializer.toJson<String?>(genresCsv),
      'plot': serializer.toJson<String?>(plot),
      'country': serializer.toJson<String?>(country),
      'runtimeSeconds': serializer.toJson<int?>(runtimeSeconds),
      'releaseDate': serializer.toJson<String?>(releaseDate),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'rating': serializer.toJson<double?>(rating),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'originalTitle': serializer.toJson<String?>(originalTitle),
      'localizedTitle': serializer.toJson<String?>(localizedTitle),
      'keywordsCsv': serializer.toJson<String?>(keywordsCsv),
      'imdbId': serializer.toJson<String?>(imdbId),
      'tmdbId': serializer.toJson<int?>(tmdbId),
    };
  }

  CachedDetail copyWith({
    String? id,
    String? sourceId,
    String? streamId,
    String? kind,
    Value<String?> castCsv = const Value.absent(),
    Value<String?> directorsCsv = const Value.absent(),
    Value<String?> genresCsv = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<String?> country = const Value.absent(),
    Value<int?> runtimeSeconds = const Value.absent(),
    Value<String?> releaseDate = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> backdropUrl = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    DateTime? cachedAt,
    Value<String?> originalTitle = const Value.absent(),
    Value<String?> localizedTitle = const Value.absent(),
    Value<String?> keywordsCsv = const Value.absent(),
    Value<String?> imdbId = const Value.absent(),
    Value<int?> tmdbId = const Value.absent(),
  }) => CachedDetail(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    streamId: streamId ?? this.streamId,
    kind: kind ?? this.kind,
    castCsv: castCsv.present ? castCsv.value : this.castCsv,
    directorsCsv: directorsCsv.present ? directorsCsv.value : this.directorsCsv,
    genresCsv: genresCsv.present ? genresCsv.value : this.genresCsv,
    plot: plot.present ? plot.value : this.plot,
    country: country.present ? country.value : this.country,
    runtimeSeconds: runtimeSeconds.present
        ? runtimeSeconds.value
        : this.runtimeSeconds,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
    rating: rating.present ? rating.value : this.rating,
    cachedAt: cachedAt ?? this.cachedAt,
    originalTitle: originalTitle.present
        ? originalTitle.value
        : this.originalTitle,
    localizedTitle: localizedTitle.present
        ? localizedTitle.value
        : this.localizedTitle,
    keywordsCsv: keywordsCsv.present ? keywordsCsv.value : this.keywordsCsv,
    imdbId: imdbId.present ? imdbId.value : this.imdbId,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
  );
  CachedDetail copyWithCompanion(CachedDetailsCompanion data) {
    return CachedDetail(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      streamId: data.streamId.present ? data.streamId.value : this.streamId,
      kind: data.kind.present ? data.kind.value : this.kind,
      castCsv: data.castCsv.present ? data.castCsv.value : this.castCsv,
      directorsCsv: data.directorsCsv.present
          ? data.directorsCsv.value
          : this.directorsCsv,
      genresCsv: data.genresCsv.present ? data.genresCsv.value : this.genresCsv,
      plot: data.plot.present ? data.plot.value : this.plot,
      country: data.country.present ? data.country.value : this.country,
      runtimeSeconds: data.runtimeSeconds.present
          ? data.runtimeSeconds.value
          : this.runtimeSeconds,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      backdropUrl: data.backdropUrl.present
          ? data.backdropUrl.value
          : this.backdropUrl,
      rating: data.rating.present ? data.rating.value : this.rating,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      originalTitle: data.originalTitle.present
          ? data.originalTitle.value
          : this.originalTitle,
      localizedTitle: data.localizedTitle.present
          ? data.localizedTitle.value
          : this.localizedTitle,
      keywordsCsv: data.keywordsCsv.present
          ? data.keywordsCsv.value
          : this.keywordsCsv,
      imdbId: data.imdbId.present ? data.imdbId.value : this.imdbId,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDetail(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('streamId: $streamId, ')
          ..write('kind: $kind, ')
          ..write('castCsv: $castCsv, ')
          ..write('directorsCsv: $directorsCsv, ')
          ..write('genresCsv: $genresCsv, ')
          ..write('plot: $plot, ')
          ..write('country: $country, ')
          ..write('runtimeSeconds: $runtimeSeconds, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('rating: $rating, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('localizedTitle: $localizedTitle, ')
          ..write('keywordsCsv: $keywordsCsv, ')
          ..write('imdbId: $imdbId, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    streamId,
    kind,
    castCsv,
    directorsCsv,
    genresCsv,
    plot,
    country,
    runtimeSeconds,
    releaseDate,
    coverUrl,
    backdropUrl,
    rating,
    cachedAt,
    originalTitle,
    localizedTitle,
    keywordsCsv,
    imdbId,
    tmdbId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDetail &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.streamId == this.streamId &&
          other.kind == this.kind &&
          other.castCsv == this.castCsv &&
          other.directorsCsv == this.directorsCsv &&
          other.genresCsv == this.genresCsv &&
          other.plot == this.plot &&
          other.country == this.country &&
          other.runtimeSeconds == this.runtimeSeconds &&
          other.releaseDate == this.releaseDate &&
          other.coverUrl == this.coverUrl &&
          other.backdropUrl == this.backdropUrl &&
          other.rating == this.rating &&
          other.cachedAt == this.cachedAt &&
          other.originalTitle == this.originalTitle &&
          other.localizedTitle == this.localizedTitle &&
          other.keywordsCsv == this.keywordsCsv &&
          other.imdbId == this.imdbId &&
          other.tmdbId == this.tmdbId);
}

class CachedDetailsCompanion extends UpdateCompanion<CachedDetail> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> streamId;
  final Value<String> kind;
  final Value<String?> castCsv;
  final Value<String?> directorsCsv;
  final Value<String?> genresCsv;
  final Value<String?> plot;
  final Value<String?> country;
  final Value<int?> runtimeSeconds;
  final Value<String?> releaseDate;
  final Value<String?> coverUrl;
  final Value<String?> backdropUrl;
  final Value<double?> rating;
  final Value<DateTime> cachedAt;
  final Value<String?> originalTitle;
  final Value<String?> localizedTitle;
  final Value<String?> keywordsCsv;
  final Value<String?> imdbId;
  final Value<int?> tmdbId;
  final Value<int> rowid;
  const CachedDetailsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.streamId = const Value.absent(),
    this.kind = const Value.absent(),
    this.castCsv = const Value.absent(),
    this.directorsCsv = const Value.absent(),
    this.genresCsv = const Value.absent(),
    this.plot = const Value.absent(),
    this.country = const Value.absent(),
    this.runtimeSeconds = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.originalTitle = const Value.absent(),
    this.localizedTitle = const Value.absent(),
    this.keywordsCsv = const Value.absent(),
    this.imdbId = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDetailsCompanion.insert({
    required String id,
    required String sourceId,
    required String streamId,
    required String kind,
    this.castCsv = const Value.absent(),
    this.directorsCsv = const Value.absent(),
    this.genresCsv = const Value.absent(),
    this.plot = const Value.absent(),
    this.country = const Value.absent(),
    this.runtimeSeconds = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.rating = const Value.absent(),
    required DateTime cachedAt,
    this.originalTitle = const Value.absent(),
    this.localizedTitle = const Value.absent(),
    this.keywordsCsv = const Value.absent(),
    this.imdbId = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       streamId = Value(streamId),
       kind = Value(kind),
       cachedAt = Value(cachedAt);
  static Insertable<CachedDetail> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? streamId,
    Expression<String>? kind,
    Expression<String>? castCsv,
    Expression<String>? directorsCsv,
    Expression<String>? genresCsv,
    Expression<String>? plot,
    Expression<String>? country,
    Expression<int>? runtimeSeconds,
    Expression<String>? releaseDate,
    Expression<String>? coverUrl,
    Expression<String>? backdropUrl,
    Expression<double>? rating,
    Expression<DateTime>? cachedAt,
    Expression<String>? originalTitle,
    Expression<String>? localizedTitle,
    Expression<String>? keywordsCsv,
    Expression<String>? imdbId,
    Expression<int>? tmdbId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (streamId != null) 'stream_id': streamId,
      if (kind != null) 'kind': kind,
      if (castCsv != null) 'cast_csv': castCsv,
      if (directorsCsv != null) 'directors_csv': directorsCsv,
      if (genresCsv != null) 'genres_csv': genresCsv,
      if (plot != null) 'plot': plot,
      if (country != null) 'country': country,
      if (runtimeSeconds != null) 'runtime_seconds': runtimeSeconds,
      if (releaseDate != null) 'release_date': releaseDate,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (rating != null) 'rating': rating,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (originalTitle != null) 'original_title': originalTitle,
      if (localizedTitle != null) 'localized_title': localizedTitle,
      if (keywordsCsv != null) 'keywords_csv': keywordsCsv,
      if (imdbId != null) 'imdb_id': imdbId,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDetailsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? streamId,
    Value<String>? kind,
    Value<String?>? castCsv,
    Value<String?>? directorsCsv,
    Value<String?>? genresCsv,
    Value<String?>? plot,
    Value<String?>? country,
    Value<int?>? runtimeSeconds,
    Value<String?>? releaseDate,
    Value<String?>? coverUrl,
    Value<String?>? backdropUrl,
    Value<double?>? rating,
    Value<DateTime>? cachedAt,
    Value<String?>? originalTitle,
    Value<String?>? localizedTitle,
    Value<String?>? keywordsCsv,
    Value<String?>? imdbId,
    Value<int?>? tmdbId,
    Value<int>? rowid,
  }) {
    return CachedDetailsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      streamId: streamId ?? this.streamId,
      kind: kind ?? this.kind,
      castCsv: castCsv ?? this.castCsv,
      directorsCsv: directorsCsv ?? this.directorsCsv,
      genresCsv: genresCsv ?? this.genresCsv,
      plot: plot ?? this.plot,
      country: country ?? this.country,
      runtimeSeconds: runtimeSeconds ?? this.runtimeSeconds,
      releaseDate: releaseDate ?? this.releaseDate,
      coverUrl: coverUrl ?? this.coverUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      rating: rating ?? this.rating,
      cachedAt: cachedAt ?? this.cachedAt,
      originalTitle: originalTitle ?? this.originalTitle,
      localizedTitle: localizedTitle ?? this.localizedTitle,
      keywordsCsv: keywordsCsv ?? this.keywordsCsv,
      imdbId: imdbId ?? this.imdbId,
      tmdbId: tmdbId ?? this.tmdbId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (streamId.present) {
      map['stream_id'] = Variable<String>(streamId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (castCsv.present) {
      map['cast_csv'] = Variable<String>(castCsv.value);
    }
    if (directorsCsv.present) {
      map['directors_csv'] = Variable<String>(directorsCsv.value);
    }
    if (genresCsv.present) {
      map['genres_csv'] = Variable<String>(genresCsv.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (runtimeSeconds.present) {
      map['runtime_seconds'] = Variable<int>(runtimeSeconds.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (originalTitle.present) {
      map['original_title'] = Variable<String>(originalTitle.value);
    }
    if (localizedTitle.present) {
      map['localized_title'] = Variable<String>(localizedTitle.value);
    }
    if (keywordsCsv.present) {
      map['keywords_csv'] = Variable<String>(keywordsCsv.value);
    }
    if (imdbId.present) {
      map['imdb_id'] = Variable<String>(imdbId.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDetailsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('streamId: $streamId, ')
          ..write('kind: $kind, ')
          ..write('castCsv: $castCsv, ')
          ..write('directorsCsv: $directorsCsv, ')
          ..write('genresCsv: $genresCsv, ')
          ..write('plot: $plot, ')
          ..write('country: $country, ')
          ..write('runtimeSeconds: $runtimeSeconds, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('rating: $rating, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('localizedTitle: $localizedTitle, ')
          ..write('keywordsCsv: $keywordsCsv, ')
          ..write('imdbId: $imdbId, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [contentId, sourceId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId, sourceId};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final String contentId;
  final String sourceId;
  final DateTime addedAt;
  const Favorite({
    required this.contentId,
    required this.sourceId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<String>(contentId);
    map['source_id'] = Variable<String>(sourceId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      contentId: Value(contentId),
      sourceId: Value(sourceId),
      addedAt: Value(addedAt),
    );
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      contentId: serializer.fromJson<String>(json['contentId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentId': serializer.toJson<String>(contentId),
      'sourceId': serializer.toJson<String>(sourceId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Favorite copyWith({String? contentId, String? sourceId, DateTime? addedAt}) =>
      Favorite(
        contentId: contentId ?? this.contentId,
        sourceId: sourceId ?? this.sourceId,
        addedAt: addedAt ?? this.addedAt,
      );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(contentId, sourceId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.contentId == this.contentId &&
          other.sourceId == this.sourceId &&
          other.addedAt == this.addedAt);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<String> contentId;
  final Value<String> sourceId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.contentId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String contentId,
    required String sourceId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : contentId = Value(contentId),
       sourceId = Value(sourceId),
       addedAt = Value(addedAt);
  static Insertable<Favorite> custom({
    Expression<String>? contentId,
    Expression<String>? sourceId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (sourceId != null) 'source_id': sourceId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? contentId,
    Value<String>? sourceId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      contentId: contentId ?? this.contentId,
      sourceId: sourceId ?? this.sourceId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchHistoryTable extends WatchHistory
    with TableInfo<$WatchHistoryTable, WatchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastWatchedAtMeta = const VerificationMeta(
    'lastWatchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastWatchedAt =
      GeneratedColumn<DateTime>(
        'last_watched_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _actualWatchMsMeta = const VerificationMeta(
    'actualWatchMs',
  );
  @override
  late final GeneratedColumn<int> actualWatchMs = GeneratedColumn<int>(
    'actual_watch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seekForwardCountMeta = const VerificationMeta(
    'seekForwardCount',
  );
  @override
  late final GeneratedColumn<int> seekForwardCount = GeneratedColumn<int>(
    'seek_forward_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seekBackwardCountMeta = const VerificationMeta(
    'seekBackwardCount',
  );
  @override
  late final GeneratedColumn<int> seekBackwardCount = GeneratedColumn<int>(
    'seek_backward_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seekForwardMsMeta = const VerificationMeta(
    'seekForwardMs',
  );
  @override
  late final GeneratedColumn<int> seekForwardMs = GeneratedColumn<int>(
    'seek_forward_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seekBackwardMsMeta = const VerificationMeta(
    'seekBackwardMs',
  );
  @override
  late final GeneratedColumn<int> seekBackwardMs = GeneratedColumn<int>(
    'seek_backward_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _episodeLabelMeta = const VerificationMeta(
    'episodeLabel',
  );
  @override
  late final GeneratedColumn<String> episodeLabel = GeneratedColumn<String>(
    'episode_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryNameMeta = const VerificationMeta(
    'categoryName',
  );
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
    'category_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    contentId,
    sourceId,
    parentId,
    positionMs,
    durationMs,
    lastWatchedAt,
    actualWatchMs,
    seekForwardCount,
    seekBackwardCount,
    seekForwardMs,
    seekBackwardMs,
    episodeLabel,
    categoryName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('last_watched_at')) {
      context.handle(
        _lastWatchedAtMeta,
        lastWatchedAt.isAcceptableOrUnknown(
          data['last_watched_at']!,
          _lastWatchedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWatchedAtMeta);
    }
    if (data.containsKey('actual_watch_ms')) {
      context.handle(
        _actualWatchMsMeta,
        actualWatchMs.isAcceptableOrUnknown(
          data['actual_watch_ms']!,
          _actualWatchMsMeta,
        ),
      );
    }
    if (data.containsKey('seek_forward_count')) {
      context.handle(
        _seekForwardCountMeta,
        seekForwardCount.isAcceptableOrUnknown(
          data['seek_forward_count']!,
          _seekForwardCountMeta,
        ),
      );
    }
    if (data.containsKey('seek_backward_count')) {
      context.handle(
        _seekBackwardCountMeta,
        seekBackwardCount.isAcceptableOrUnknown(
          data['seek_backward_count']!,
          _seekBackwardCountMeta,
        ),
      );
    }
    if (data.containsKey('seek_forward_ms')) {
      context.handle(
        _seekForwardMsMeta,
        seekForwardMs.isAcceptableOrUnknown(
          data['seek_forward_ms']!,
          _seekForwardMsMeta,
        ),
      );
    }
    if (data.containsKey('seek_backward_ms')) {
      context.handle(
        _seekBackwardMsMeta,
        seekBackwardMs.isAcceptableOrUnknown(
          data['seek_backward_ms']!,
          _seekBackwardMsMeta,
        ),
      );
    }
    if (data.containsKey('episode_label')) {
      context.handle(
        _episodeLabelMeta,
        episodeLabel.isAcceptableOrUnknown(
          data['episode_label']!,
          _episodeLabelMeta,
        ),
      );
    }
    if (data.containsKey('category_name')) {
      context.handle(
        _categoryNameMeta,
        categoryName.isAcceptableOrUnknown(
          data['category_name']!,
          _categoryNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId, sourceId};
  @override
  WatchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchHistoryData(
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      lastWatchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_watched_at'],
      )!,
      actualWatchMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_watch_ms'],
      )!,
      seekForwardCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seek_forward_count'],
      )!,
      seekBackwardCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seek_backward_count'],
      )!,
      seekForwardMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seek_forward_ms'],
      )!,
      seekBackwardMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seek_backward_ms'],
      )!,
      episodeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_label'],
      ),
      categoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_name'],
      ),
    );
  }

  @override
  $WatchHistoryTable createAlias(String alias) {
    return $WatchHistoryTable(attachedDatabase, alias);
  }
}

class WatchHistoryData extends DataClass
    implements Insertable<WatchHistoryData> {
  final String contentId;
  final String sourceId;
  final String? parentId;
  final int positionMs;
  final int durationMs;
  final DateTime lastWatchedAt;

  /// Kullanıcının player önünde geçirdiği gerçek zaman (ms). Seek yapılan
  /// saniyeler bu sayaca dahil edilmez. `actualWatchMs / durationMs < 0.6`
  /// ya da seekForwardCount > 8 ise UI ve öneri motoru "geçerek izlendi"
  /// kabul eder.
  final int actualWatchMs;

  /// Toplam ileri seek sayısı. Çok sayıda ileri atlama "skim" sinyalidir;
  /// kullanıcı içeriği tüketmedi sayılır.
  final int seekForwardCount;

  /// Toplam geri seek sayısı. Tekrar izleme ya da kaçırılan diyalog
  /// sinyali; öneri motorunda "beğenmiş olabilir" tarafına ağırlık verir.
  final int seekBackwardCount;

  /// İleri yönde atlanan toplam saniye (ms cinsinden). Geçerek izleme
  /// rozetinin ikinci sinyali.
  final int seekForwardMs;
  final int seekBackwardMs;

  /// Dizi bölümleri için "S1E3" gibi kısa etiket. İzleme geçmişi
  /// sayfası bunu poster altında gösterir; series detail provider'ı
  /// runtime'da çağırmak yerine player save'i sırasında bir kez
  /// yazıyoruz. Filmlerde null kalır.
  final String? episodeLabel;

  /// Panel kategorisi (örn. "Aksiyon", "Türk Filmleri"). UI rozet
  /// olarak gösterir; aynı şekilde denormalize tutuyoruz çünkü
  /// kullanıcı silinen kaynak için bile geçmişi görmek isteyebilir.
  final String? categoryName;
  const WatchHistoryData({
    required this.contentId,
    required this.sourceId,
    this.parentId,
    required this.positionMs,
    required this.durationMs,
    required this.lastWatchedAt,
    required this.actualWatchMs,
    required this.seekForwardCount,
    required this.seekBackwardCount,
    required this.seekForwardMs,
    required this.seekBackwardMs,
    this.episodeLabel,
    this.categoryName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<String>(contentId);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['last_watched_at'] = Variable<DateTime>(lastWatchedAt);
    map['actual_watch_ms'] = Variable<int>(actualWatchMs);
    map['seek_forward_count'] = Variable<int>(seekForwardCount);
    map['seek_backward_count'] = Variable<int>(seekBackwardCount);
    map['seek_forward_ms'] = Variable<int>(seekForwardMs);
    map['seek_backward_ms'] = Variable<int>(seekBackwardMs);
    if (!nullToAbsent || episodeLabel != null) {
      map['episode_label'] = Variable<String>(episodeLabel);
    }
    if (!nullToAbsent || categoryName != null) {
      map['category_name'] = Variable<String>(categoryName);
    }
    return map;
  }

  WatchHistoryCompanion toCompanion(bool nullToAbsent) {
    return WatchHistoryCompanion(
      contentId: Value(contentId),
      sourceId: Value(sourceId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      lastWatchedAt: Value(lastWatchedAt),
      actualWatchMs: Value(actualWatchMs),
      seekForwardCount: Value(seekForwardCount),
      seekBackwardCount: Value(seekBackwardCount),
      seekForwardMs: Value(seekForwardMs),
      seekBackwardMs: Value(seekBackwardMs),
      episodeLabel: episodeLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeLabel),
      categoryName: categoryName == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryName),
    );
  }

  factory WatchHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchHistoryData(
      contentId: serializer.fromJson<String>(json['contentId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      lastWatchedAt: serializer.fromJson<DateTime>(json['lastWatchedAt']),
      actualWatchMs: serializer.fromJson<int>(json['actualWatchMs']),
      seekForwardCount: serializer.fromJson<int>(json['seekForwardCount']),
      seekBackwardCount: serializer.fromJson<int>(json['seekBackwardCount']),
      seekForwardMs: serializer.fromJson<int>(json['seekForwardMs']),
      seekBackwardMs: serializer.fromJson<int>(json['seekBackwardMs']),
      episodeLabel: serializer.fromJson<String?>(json['episodeLabel']),
      categoryName: serializer.fromJson<String?>(json['categoryName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentId': serializer.toJson<String>(contentId),
      'sourceId': serializer.toJson<String>(sourceId),
      'parentId': serializer.toJson<String?>(parentId),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'lastWatchedAt': serializer.toJson<DateTime>(lastWatchedAt),
      'actualWatchMs': serializer.toJson<int>(actualWatchMs),
      'seekForwardCount': serializer.toJson<int>(seekForwardCount),
      'seekBackwardCount': serializer.toJson<int>(seekBackwardCount),
      'seekForwardMs': serializer.toJson<int>(seekForwardMs),
      'seekBackwardMs': serializer.toJson<int>(seekBackwardMs),
      'episodeLabel': serializer.toJson<String?>(episodeLabel),
      'categoryName': serializer.toJson<String?>(categoryName),
    };
  }

  WatchHistoryData copyWith({
    String? contentId,
    String? sourceId,
    Value<String?> parentId = const Value.absent(),
    int? positionMs,
    int? durationMs,
    DateTime? lastWatchedAt,
    int? actualWatchMs,
    int? seekForwardCount,
    int? seekBackwardCount,
    int? seekForwardMs,
    int? seekBackwardMs,
    Value<String?> episodeLabel = const Value.absent(),
    Value<String?> categoryName = const Value.absent(),
  }) => WatchHistoryData(
    contentId: contentId ?? this.contentId,
    sourceId: sourceId ?? this.sourceId,
    parentId: parentId.present ? parentId.value : this.parentId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    actualWatchMs: actualWatchMs ?? this.actualWatchMs,
    seekForwardCount: seekForwardCount ?? this.seekForwardCount,
    seekBackwardCount: seekBackwardCount ?? this.seekBackwardCount,
    seekForwardMs: seekForwardMs ?? this.seekForwardMs,
    seekBackwardMs: seekBackwardMs ?? this.seekBackwardMs,
    episodeLabel: episodeLabel.present ? episodeLabel.value : this.episodeLabel,
    categoryName: categoryName.present ? categoryName.value : this.categoryName,
  );
  WatchHistoryData copyWithCompanion(WatchHistoryCompanion data) {
    return WatchHistoryData(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      lastWatchedAt: data.lastWatchedAt.present
          ? data.lastWatchedAt.value
          : this.lastWatchedAt,
      actualWatchMs: data.actualWatchMs.present
          ? data.actualWatchMs.value
          : this.actualWatchMs,
      seekForwardCount: data.seekForwardCount.present
          ? data.seekForwardCount.value
          : this.seekForwardCount,
      seekBackwardCount: data.seekBackwardCount.present
          ? data.seekBackwardCount.value
          : this.seekBackwardCount,
      seekForwardMs: data.seekForwardMs.present
          ? data.seekForwardMs.value
          : this.seekForwardMs,
      seekBackwardMs: data.seekBackwardMs.present
          ? data.seekBackwardMs.value
          : this.seekBackwardMs,
      episodeLabel: data.episodeLabel.present
          ? data.episodeLabel.value
          : this.episodeLabel,
      categoryName: data.categoryName.present
          ? data.categoryName.value
          : this.categoryName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryData(')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('parentId: $parentId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('lastWatchedAt: $lastWatchedAt, ')
          ..write('actualWatchMs: $actualWatchMs, ')
          ..write('seekForwardCount: $seekForwardCount, ')
          ..write('seekBackwardCount: $seekBackwardCount, ')
          ..write('seekForwardMs: $seekForwardMs, ')
          ..write('seekBackwardMs: $seekBackwardMs, ')
          ..write('episodeLabel: $episodeLabel, ')
          ..write('categoryName: $categoryName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    contentId,
    sourceId,
    parentId,
    positionMs,
    durationMs,
    lastWatchedAt,
    actualWatchMs,
    seekForwardCount,
    seekBackwardCount,
    seekForwardMs,
    seekBackwardMs,
    episodeLabel,
    categoryName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryData &&
          other.contentId == this.contentId &&
          other.sourceId == this.sourceId &&
          other.parentId == this.parentId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.lastWatchedAt == this.lastWatchedAt &&
          other.actualWatchMs == this.actualWatchMs &&
          other.seekForwardCount == this.seekForwardCount &&
          other.seekBackwardCount == this.seekBackwardCount &&
          other.seekForwardMs == this.seekForwardMs &&
          other.seekBackwardMs == this.seekBackwardMs &&
          other.episodeLabel == this.episodeLabel &&
          other.categoryName == this.categoryName);
}

class WatchHistoryCompanion extends UpdateCompanion<WatchHistoryData> {
  final Value<String> contentId;
  final Value<String> sourceId;
  final Value<String?> parentId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<DateTime> lastWatchedAt;
  final Value<int> actualWatchMs;
  final Value<int> seekForwardCount;
  final Value<int> seekBackwardCount;
  final Value<int> seekForwardMs;
  final Value<int> seekBackwardMs;
  final Value<String?> episodeLabel;
  final Value<String?> categoryName;
  final Value<int> rowid;
  const WatchHistoryCompanion({
    this.contentId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.actualWatchMs = const Value.absent(),
    this.seekForwardCount = const Value.absent(),
    this.seekBackwardCount = const Value.absent(),
    this.seekForwardMs = const Value.absent(),
    this.seekBackwardMs = const Value.absent(),
    this.episodeLabel = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchHistoryCompanion.insert({
    required String contentId,
    required String sourceId,
    this.parentId = const Value.absent(),
    required int positionMs,
    required int durationMs,
    required DateTime lastWatchedAt,
    this.actualWatchMs = const Value.absent(),
    this.seekForwardCount = const Value.absent(),
    this.seekBackwardCount = const Value.absent(),
    this.seekForwardMs = const Value.absent(),
    this.seekBackwardMs = const Value.absent(),
    this.episodeLabel = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : contentId = Value(contentId),
       sourceId = Value(sourceId),
       positionMs = Value(positionMs),
       durationMs = Value(durationMs),
       lastWatchedAt = Value(lastWatchedAt);
  static Insertable<WatchHistoryData> custom({
    Expression<String>? contentId,
    Expression<String>? sourceId,
    Expression<String>? parentId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<DateTime>? lastWatchedAt,
    Expression<int>? actualWatchMs,
    Expression<int>? seekForwardCount,
    Expression<int>? seekBackwardCount,
    Expression<int>? seekForwardMs,
    Expression<int>? seekBackwardMs,
    Expression<String>? episodeLabel,
    Expression<String>? categoryName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (sourceId != null) 'source_id': sourceId,
      if (parentId != null) 'parent_id': parentId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (lastWatchedAt != null) 'last_watched_at': lastWatchedAt,
      if (actualWatchMs != null) 'actual_watch_ms': actualWatchMs,
      if (seekForwardCount != null) 'seek_forward_count': seekForwardCount,
      if (seekBackwardCount != null) 'seek_backward_count': seekBackwardCount,
      if (seekForwardMs != null) 'seek_forward_ms': seekForwardMs,
      if (seekBackwardMs != null) 'seek_backward_ms': seekBackwardMs,
      if (episodeLabel != null) 'episode_label': episodeLabel,
      if (categoryName != null) 'category_name': categoryName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchHistoryCompanion copyWith({
    Value<String>? contentId,
    Value<String>? sourceId,
    Value<String?>? parentId,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<DateTime>? lastWatchedAt,
    Value<int>? actualWatchMs,
    Value<int>? seekForwardCount,
    Value<int>? seekBackwardCount,
    Value<int>? seekForwardMs,
    Value<int>? seekBackwardMs,
    Value<String?>? episodeLabel,
    Value<String?>? categoryName,
    Value<int>? rowid,
  }) {
    return WatchHistoryCompanion(
      contentId: contentId ?? this.contentId,
      sourceId: sourceId ?? this.sourceId,
      parentId: parentId ?? this.parentId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      actualWatchMs: actualWatchMs ?? this.actualWatchMs,
      seekForwardCount: seekForwardCount ?? this.seekForwardCount,
      seekBackwardCount: seekBackwardCount ?? this.seekBackwardCount,
      seekForwardMs: seekForwardMs ?? this.seekForwardMs,
      seekBackwardMs: seekBackwardMs ?? this.seekBackwardMs,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      categoryName: categoryName ?? this.categoryName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (lastWatchedAt.present) {
      map['last_watched_at'] = Variable<DateTime>(lastWatchedAt.value);
    }
    if (actualWatchMs.present) {
      map['actual_watch_ms'] = Variable<int>(actualWatchMs.value);
    }
    if (seekForwardCount.present) {
      map['seek_forward_count'] = Variable<int>(seekForwardCount.value);
    }
    if (seekBackwardCount.present) {
      map['seek_backward_count'] = Variable<int>(seekBackwardCount.value);
    }
    if (seekForwardMs.present) {
      map['seek_forward_ms'] = Variable<int>(seekForwardMs.value);
    }
    if (seekBackwardMs.present) {
      map['seek_backward_ms'] = Variable<int>(seekBackwardMs.value);
    }
    if (episodeLabel.present) {
      map['episode_label'] = Variable<String>(episodeLabel.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryCompanion(')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('parentId: $parentId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('lastWatchedAt: $lastWatchedAt, ')
          ..write('actualWatchMs: $actualWatchMs, ')
          ..write('seekForwardCount: $seekForwardCount, ')
          ..write('seekBackwardCount: $seekBackwardCount, ')
          ..write('seekForwardMs: $seekForwardMs, ')
          ..write('seekBackwardMs: $seekBackwardMs, ')
          ..write('episodeLabel: $episodeLabel, ')
          ..write('categoryName: $categoryName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgProgramsTable extends EpgPrograms
    with TableInfo<$EpgProgramsTable, EpgProgramRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgProgramsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stopMeta = const VerificationMeta('stop');
  @override
  late final GeneratedColumn<DateTime> stop = GeneratedColumn<DateTime>(
    'stop',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesCsvMeta = const VerificationMeta(
    'categoriesCsv',
  );
  @override
  late final GeneratedColumn<String> categoriesCsv = GeneratedColumn<String>(
    'categories_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    channelId,
    start,
    stop,
    title,
    description,
    categoriesCsv,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_programs';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgProgramRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('stop')) {
      context.handle(
        _stopMeta,
        stop.isAcceptableOrUnknown(data['stop']!, _stopMeta),
      );
    } else if (isInserting) {
      context.missing(_stopMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('categories_csv')) {
      context.handle(
        _categoriesCsvMeta,
        categoriesCsv.isAcceptableOrUnknown(
          data['categories_csv']!,
          _categoriesCsvMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, channelId, start};
  @override
  EpgProgramRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgProgramRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start'],
      )!,
      stop: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stop'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      categoriesCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories_csv'],
      ),
    );
  }

  @override
  $EpgProgramsTable createAlias(String alias) {
    return $EpgProgramsTable(attachedDatabase, alias);
  }
}

class EpgProgramRow extends DataClass implements Insertable<EpgProgramRow> {
  final String sourceId;
  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;
  final String? categoriesCsv;
  const EpgProgramRow({
    required this.sourceId,
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.description,
    this.categoriesCsv,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['channel_id'] = Variable<String>(channelId);
    map['start'] = Variable<DateTime>(start);
    map['stop'] = Variable<DateTime>(stop);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || categoriesCsv != null) {
      map['categories_csv'] = Variable<String>(categoriesCsv);
    }
    return map;
  }

  EpgProgramsCompanion toCompanion(bool nullToAbsent) {
    return EpgProgramsCompanion(
      sourceId: Value(sourceId),
      channelId: Value(channelId),
      start: Value(start),
      stop: Value(stop),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      categoriesCsv: categoriesCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(categoriesCsv),
    );
  }

  factory EpgProgramRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgProgramRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      start: serializer.fromJson<DateTime>(json['start']),
      stop: serializer.fromJson<DateTime>(json['stop']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      categoriesCsv: serializer.fromJson<String?>(json['categoriesCsv']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'channelId': serializer.toJson<String>(channelId),
      'start': serializer.toJson<DateTime>(start),
      'stop': serializer.toJson<DateTime>(stop),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'categoriesCsv': serializer.toJson<String?>(categoriesCsv),
    };
  }

  EpgProgramRow copyWith({
    String? sourceId,
    String? channelId,
    DateTime? start,
    DateTime? stop,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> categoriesCsv = const Value.absent(),
  }) => EpgProgramRow(
    sourceId: sourceId ?? this.sourceId,
    channelId: channelId ?? this.channelId,
    start: start ?? this.start,
    stop: stop ?? this.stop,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    categoriesCsv: categoriesCsv.present
        ? categoriesCsv.value
        : this.categoriesCsv,
  );
  EpgProgramRow copyWithCompanion(EpgProgramsCompanion data) {
    return EpgProgramRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      start: data.start.present ? data.start.value : this.start,
      stop: data.stop.present ? data.stop.value : this.stop,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      categoriesCsv: data.categoriesCsv.present
          ? data.categoriesCsv.value
          : this.categoriesCsv,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramRow(')
          ..write('sourceId: $sourceId, ')
          ..write('channelId: $channelId, ')
          ..write('start: $start, ')
          ..write('stop: $stop, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('categoriesCsv: $categoriesCsv')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    channelId,
    start,
    stop,
    title,
    description,
    categoriesCsv,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgProgramRow &&
          other.sourceId == this.sourceId &&
          other.channelId == this.channelId &&
          other.start == this.start &&
          other.stop == this.stop &&
          other.title == this.title &&
          other.description == this.description &&
          other.categoriesCsv == this.categoriesCsv);
}

class EpgProgramsCompanion extends UpdateCompanion<EpgProgramRow> {
  final Value<String> sourceId;
  final Value<String> channelId;
  final Value<DateTime> start;
  final Value<DateTime> stop;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> categoriesCsv;
  final Value<int> rowid;
  const EpgProgramsCompanion({
    this.sourceId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.start = const Value.absent(),
    this.stop = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.categoriesCsv = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgProgramsCompanion.insert({
    required String sourceId,
    required String channelId,
    required DateTime start,
    required DateTime stop,
    required String title,
    this.description = const Value.absent(),
    this.categoriesCsv = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       channelId = Value(channelId),
       start = Value(start),
       stop = Value(stop),
       title = Value(title);
  static Insertable<EpgProgramRow> custom({
    Expression<String>? sourceId,
    Expression<String>? channelId,
    Expression<DateTime>? start,
    Expression<DateTime>? stop,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? categoriesCsv,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (channelId != null) 'channel_id': channelId,
      if (start != null) 'start': start,
      if (stop != null) 'stop': stop,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (categoriesCsv != null) 'categories_csv': categoriesCsv,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgProgramsCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? channelId,
    Value<DateTime>? start,
    Value<DateTime>? stop,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? categoriesCsv,
    Value<int>? rowid,
  }) {
    return EpgProgramsCompanion(
      sourceId: sourceId ?? this.sourceId,
      channelId: channelId ?? this.channelId,
      start: start ?? this.start,
      stop: stop ?? this.stop,
      title: title ?? this.title,
      description: description ?? this.description,
      categoriesCsv: categoriesCsv ?? this.categoriesCsv,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (stop.present) {
      map['stop'] = Variable<DateTime>(stop.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (categoriesCsv.present) {
      map['categories_csv'] = Variable<String>(categoriesCsv.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('channelId: $channelId, ')
          ..write('start: $start, ')
          ..write('stop: $stop, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('categoriesCsv: $categoriesCsv, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserRatingsTable extends UserRatings
    with TableInfo<$UserRatingsTable, UserRating> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserRatingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratedAtMeta = const VerificationMeta(
    'ratedAt',
  );
  @override
  late final GeneratedColumn<DateTime> ratedAt = GeneratedColumn<DateTime>(
    'rated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    contentId,
    sourceId,
    parentId,
    score,
    comment,
    ratedAt,
    tmdbId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_ratings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserRating> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('rated_at')) {
      context.handle(
        _ratedAtMeta,
        ratedAt.isAcceptableOrUnknown(data['rated_at']!, _ratedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_ratedAtMeta);
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId, sourceId};
  @override
  UserRating map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRating(
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      ratedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}rated_at'],
      )!,
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_id'],
      ),
    );
  }

  @override
  $UserRatingsTable createAlias(String alias) {
    return $UserRatingsTable(attachedDatabase, alias);
  }
}

class UserRating extends DataClass implements Insertable<UserRating> {
  final String contentId;
  final String sourceId;

  /// Dizi bölümleri ayrı puanlanabilir; root dizi puanı parentId=null
  /// olur. Şu an UI sadece root puanlamayı gösteriyor ama kolon ileride
  /// bölüm bazlı puana açık kalsın diye burada.
  final String? parentId;
  final double score;
  final String? comment;
  final DateTime ratedAt;

  /// Puan verilen içeriğin TMDB kimliği (varsa). Kaynak silinip farklı bir
  /// panel eklense bile, yeni paneldeki aynı tmdbId'li film bu puanla
  /// eşleştirilebilsin diye puanla birlikte kalıcı tutulur. Puan verme
  /// anında TMDB çözülmemişse null kalır.
  final int? tmdbId;
  const UserRating({
    required this.contentId,
    required this.sourceId,
    this.parentId,
    required this.score,
    this.comment,
    required this.ratedAt,
    this.tmdbId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<String>(contentId);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['score'] = Variable<double>(score);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['rated_at'] = Variable<DateTime>(ratedAt);
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    return map;
  }

  UserRatingsCompanion toCompanion(bool nullToAbsent) {
    return UserRatingsCompanion(
      contentId: Value(contentId),
      sourceId: Value(sourceId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      score: Value(score),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      ratedAt: Value(ratedAt),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
    );
  }

  factory UserRating.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRating(
      contentId: serializer.fromJson<String>(json['contentId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      score: serializer.fromJson<double>(json['score']),
      comment: serializer.fromJson<String?>(json['comment']),
      ratedAt: serializer.fromJson<DateTime>(json['ratedAt']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentId': serializer.toJson<String>(contentId),
      'sourceId': serializer.toJson<String>(sourceId),
      'parentId': serializer.toJson<String?>(parentId),
      'score': serializer.toJson<double>(score),
      'comment': serializer.toJson<String?>(comment),
      'ratedAt': serializer.toJson<DateTime>(ratedAt),
      'tmdbId': serializer.toJson<int?>(tmdbId),
    };
  }

  UserRating copyWith({
    String? contentId,
    String? sourceId,
    Value<String?> parentId = const Value.absent(),
    double? score,
    Value<String?> comment = const Value.absent(),
    DateTime? ratedAt,
    Value<int?> tmdbId = const Value.absent(),
  }) => UserRating(
    contentId: contentId ?? this.contentId,
    sourceId: sourceId ?? this.sourceId,
    parentId: parentId.present ? parentId.value : this.parentId,
    score: score ?? this.score,
    comment: comment.present ? comment.value : this.comment,
    ratedAt: ratedAt ?? this.ratedAt,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
  );
  UserRating copyWithCompanion(UserRatingsCompanion data) {
    return UserRating(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      score: data.score.present ? data.score.value : this.score,
      comment: data.comment.present ? data.comment.value : this.comment,
      ratedAt: data.ratedAt.present ? data.ratedAt.value : this.ratedAt,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRating(')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('parentId: $parentId, ')
          ..write('score: $score, ')
          ..write('comment: $comment, ')
          ..write('ratedAt: $ratedAt, ')
          ..write('tmdbId: $tmdbId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    contentId,
    sourceId,
    parentId,
    score,
    comment,
    ratedAt,
    tmdbId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRating &&
          other.contentId == this.contentId &&
          other.sourceId == this.sourceId &&
          other.parentId == this.parentId &&
          other.score == this.score &&
          other.comment == this.comment &&
          other.ratedAt == this.ratedAt &&
          other.tmdbId == this.tmdbId);
}

class UserRatingsCompanion extends UpdateCompanion<UserRating> {
  final Value<String> contentId;
  final Value<String> sourceId;
  final Value<String?> parentId;
  final Value<double> score;
  final Value<String?> comment;
  final Value<DateTime> ratedAt;
  final Value<int?> tmdbId;
  final Value<int> rowid;
  const UserRatingsCompanion({
    this.contentId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.score = const Value.absent(),
    this.comment = const Value.absent(),
    this.ratedAt = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserRatingsCompanion.insert({
    required String contentId,
    required String sourceId,
    this.parentId = const Value.absent(),
    required double score,
    this.comment = const Value.absent(),
    required DateTime ratedAt,
    this.tmdbId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : contentId = Value(contentId),
       sourceId = Value(sourceId),
       score = Value(score),
       ratedAt = Value(ratedAt);
  static Insertable<UserRating> custom({
    Expression<String>? contentId,
    Expression<String>? sourceId,
    Expression<String>? parentId,
    Expression<double>? score,
    Expression<String>? comment,
    Expression<DateTime>? ratedAt,
    Expression<int>? tmdbId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (sourceId != null) 'source_id': sourceId,
      if (parentId != null) 'parent_id': parentId,
      if (score != null) 'score': score,
      if (comment != null) 'comment': comment,
      if (ratedAt != null) 'rated_at': ratedAt,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserRatingsCompanion copyWith({
    Value<String>? contentId,
    Value<String>? sourceId,
    Value<String?>? parentId,
    Value<double>? score,
    Value<String?>? comment,
    Value<DateTime>? ratedAt,
    Value<int?>? tmdbId,
    Value<int>? rowid,
  }) {
    return UserRatingsCompanion(
      contentId: contentId ?? this.contentId,
      sourceId: sourceId ?? this.sourceId,
      parentId: parentId ?? this.parentId,
      score: score ?? this.score,
      comment: comment ?? this.comment,
      ratedAt: ratedAt ?? this.ratedAt,
      tmdbId: tmdbId ?? this.tmdbId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (ratedAt.present) {
      map['rated_at'] = Variable<DateTime>(ratedAt.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserRatingsCompanion(')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('parentId: $parentId, ')
          ..write('score: $score, ')
          ..write('comment: $comment, ')
          ..write('ratedAt: $ratedAt, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchlistsTable extends Watchlists
    with TableInfo<$WatchlistsTable, Watchlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    position,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Watchlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Watchlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Watchlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WatchlistsTable createAlias(String alias) {
    return $WatchlistsTable(attachedDatabase, alias);
  }
}

class Watchlist extends DataClass implements Insertable<Watchlist> {
  final String id;
  final String name;
  final String? description;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Watchlist({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WatchlistsCompanion toCompanion(bool nullToAbsent) {
    return WatchlistsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      position: Value(position),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Watchlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Watchlist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Watchlist copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Watchlist(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Watchlist copyWithCompanion(WatchlistsCompanion data) {
    return Watchlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Watchlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, position, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Watchlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.position == this.position &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WatchlistsCompanion extends UpdateCompanion<Watchlist> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> position;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WatchlistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchlistsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.position = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Watchlist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? position,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchlistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? position,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WatchlistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchlistItemsTable extends WatchlistItems
    with TableInfo<$WatchlistItemsTable, WatchlistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _watchlistIdMeta = const VerificationMeta(
    'watchlistId',
  );
  @override
  late final GeneratedColumn<String> watchlistId = GeneratedColumn<String>(
    'watchlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    watchlistId,
    contentId,
    sourceId,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchlistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('watchlist_id')) {
      context.handle(
        _watchlistIdMeta,
        watchlistId.isAcceptableOrUnknown(
          data['watchlist_id']!,
          _watchlistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_watchlistIdMeta);
    }
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {watchlistId, contentId, sourceId};
  @override
  WatchlistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistItem(
      watchlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}watchlist_id'],
      )!,
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $WatchlistItemsTable createAlias(String alias) {
    return $WatchlistItemsTable(attachedDatabase, alias);
  }
}

class WatchlistItem extends DataClass implements Insertable<WatchlistItem> {
  final String watchlistId;
  final String contentId;
  final String sourceId;
  final DateTime addedAt;
  const WatchlistItem({
    required this.watchlistId,
    required this.contentId,
    required this.sourceId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['watchlist_id'] = Variable<String>(watchlistId);
    map['content_id'] = Variable<String>(contentId);
    map['source_id'] = Variable<String>(sourceId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  WatchlistItemsCompanion toCompanion(bool nullToAbsent) {
    return WatchlistItemsCompanion(
      watchlistId: Value(watchlistId),
      contentId: Value(contentId),
      sourceId: Value(sourceId),
      addedAt: Value(addedAt),
    );
  }

  factory WatchlistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistItem(
      watchlistId: serializer.fromJson<String>(json['watchlistId']),
      contentId: serializer.fromJson<String>(json['contentId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'watchlistId': serializer.toJson<String>(watchlistId),
      'contentId': serializer.toJson<String>(contentId),
      'sourceId': serializer.toJson<String>(sourceId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  WatchlistItem copyWith({
    String? watchlistId,
    String? contentId,
    String? sourceId,
    DateTime? addedAt,
  }) => WatchlistItem(
    watchlistId: watchlistId ?? this.watchlistId,
    contentId: contentId ?? this.contentId,
    sourceId: sourceId ?? this.sourceId,
    addedAt: addedAt ?? this.addedAt,
  );
  WatchlistItem copyWithCompanion(WatchlistItemsCompanion data) {
    return WatchlistItem(
      watchlistId: data.watchlistId.present
          ? data.watchlistId.value
          : this.watchlistId,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistItem(')
          ..write('watchlistId: $watchlistId, ')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(watchlistId, contentId, sourceId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistItem &&
          other.watchlistId == this.watchlistId &&
          other.contentId == this.contentId &&
          other.sourceId == this.sourceId &&
          other.addedAt == this.addedAt);
}

class WatchlistItemsCompanion extends UpdateCompanion<WatchlistItem> {
  final Value<String> watchlistId;
  final Value<String> contentId;
  final Value<String> sourceId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const WatchlistItemsCompanion({
    this.watchlistId = const Value.absent(),
    this.contentId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchlistItemsCompanion.insert({
    required String watchlistId,
    required String contentId,
    required String sourceId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : watchlistId = Value(watchlistId),
       contentId = Value(contentId),
       sourceId = Value(sourceId),
       addedAt = Value(addedAt);
  static Insertable<WatchlistItem> custom({
    Expression<String>? watchlistId,
    Expression<String>? contentId,
    Expression<String>? sourceId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (watchlistId != null) 'watchlist_id': watchlistId,
      if (contentId != null) 'content_id': contentId,
      if (sourceId != null) 'source_id': sourceId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchlistItemsCompanion copyWith({
    Value<String>? watchlistId,
    Value<String>? contentId,
    Value<String>? sourceId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return WatchlistItemsCompanion(
      watchlistId: watchlistId ?? this.watchlistId,
      contentId: contentId ?? this.contentId,
      sourceId: sourceId ?? this.sourceId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (watchlistId.present) {
      map['watchlist_id'] = Variable<String>(watchlistId.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistItemsCompanion(')
          ..write('watchlistId: $watchlistId, ')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TmdbOverridesTable extends TmdbOverrides
    with TableInfo<$TmdbOverridesTable, TmdbOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TmdbOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isMovieMeta = const VerificationMeta(
    'isMovie',
  );
  @override
  late final GeneratedColumn<bool> isMovie = GeneratedColumn<bool>(
    'is_movie',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_movie" IN (0, 1))',
    ),
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    contentId,
    sourceId,
    tmdbId,
    isMovie,
    savedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tmdb_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<TmdbOverride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tmdbIdMeta);
    }
    if (data.containsKey('is_movie')) {
      context.handle(
        _isMovieMeta,
        isMovie.isAcceptableOrUnknown(data['is_movie']!, _isMovieMeta),
      );
    } else if (isInserting) {
      context.missing(_isMovieMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentId, sourceId};
  @override
  TmdbOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TmdbOverride(
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_id'],
      )!,
      isMovie: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_movie'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $TmdbOverridesTable createAlias(String alias) {
    return $TmdbOverridesTable(attachedDatabase, alias);
  }
}

class TmdbOverride extends DataClass implements Insertable<TmdbOverride> {
  final String contentId;
  final String sourceId;
  final int tmdbId;
  final bool isMovie;
  final DateTime savedAt;
  const TmdbOverride({
    required this.contentId,
    required this.sourceId,
    required this.tmdbId,
    required this.isMovie,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<String>(contentId);
    map['source_id'] = Variable<String>(sourceId);
    map['tmdb_id'] = Variable<int>(tmdbId);
    map['is_movie'] = Variable<bool>(isMovie);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  TmdbOverridesCompanion toCompanion(bool nullToAbsent) {
    return TmdbOverridesCompanion(
      contentId: Value(contentId),
      sourceId: Value(sourceId),
      tmdbId: Value(tmdbId),
      isMovie: Value(isMovie),
      savedAt: Value(savedAt),
    );
  }

  factory TmdbOverride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TmdbOverride(
      contentId: serializer.fromJson<String>(json['contentId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      tmdbId: serializer.fromJson<int>(json['tmdbId']),
      isMovie: serializer.fromJson<bool>(json['isMovie']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentId': serializer.toJson<String>(contentId),
      'sourceId': serializer.toJson<String>(sourceId),
      'tmdbId': serializer.toJson<int>(tmdbId),
      'isMovie': serializer.toJson<bool>(isMovie),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  TmdbOverride copyWith({
    String? contentId,
    String? sourceId,
    int? tmdbId,
    bool? isMovie,
    DateTime? savedAt,
  }) => TmdbOverride(
    contentId: contentId ?? this.contentId,
    sourceId: sourceId ?? this.sourceId,
    tmdbId: tmdbId ?? this.tmdbId,
    isMovie: isMovie ?? this.isMovie,
    savedAt: savedAt ?? this.savedAt,
  );
  TmdbOverride copyWithCompanion(TmdbOverridesCompanion data) {
    return TmdbOverride(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      isMovie: data.isMovie.present ? data.isMovie.value : this.isMovie,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TmdbOverride(')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('isMovie: $isMovie, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(contentId, sourceId, tmdbId, isMovie, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TmdbOverride &&
          other.contentId == this.contentId &&
          other.sourceId == this.sourceId &&
          other.tmdbId == this.tmdbId &&
          other.isMovie == this.isMovie &&
          other.savedAt == this.savedAt);
}

class TmdbOverridesCompanion extends UpdateCompanion<TmdbOverride> {
  final Value<String> contentId;
  final Value<String> sourceId;
  final Value<int> tmdbId;
  final Value<bool> isMovie;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const TmdbOverridesCompanion({
    this.contentId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.isMovie = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TmdbOverridesCompanion.insert({
    required String contentId,
    required String sourceId,
    required int tmdbId,
    required bool isMovie,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : contentId = Value(contentId),
       sourceId = Value(sourceId),
       tmdbId = Value(tmdbId),
       isMovie = Value(isMovie),
       savedAt = Value(savedAt);
  static Insertable<TmdbOverride> custom({
    Expression<String>? contentId,
    Expression<String>? sourceId,
    Expression<int>? tmdbId,
    Expression<bool>? isMovie,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (sourceId != null) 'source_id': sourceId,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (isMovie != null) 'is_movie': isMovie,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TmdbOverridesCompanion copyWith({
    Value<String>? contentId,
    Value<String>? sourceId,
    Value<int>? tmdbId,
    Value<bool>? isMovie,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return TmdbOverridesCompanion(
      contentId: contentId ?? this.contentId,
      sourceId: sourceId ?? this.sourceId,
      tmdbId: tmdbId ?? this.tmdbId,
      isMovie: isMovie ?? this.isMovie,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (isMovie.present) {
      map['is_movie'] = Variable<bool>(isMovie.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TmdbOverridesCompanion(')
          ..write('contentId: $contentId, ')
          ..write('sourceId: $sourceId, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('isMovie: $isMovie, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $CachedChannelsTable cachedChannels = $CachedChannelsTable(this);
  late final $CachedDetailsTable cachedDetails = $CachedDetailsTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $WatchHistoryTable watchHistory = $WatchHistoryTable(this);
  late final $EpgProgramsTable epgPrograms = $EpgProgramsTable(this);
  late final $UserRatingsTable userRatings = $UserRatingsTable(this);
  late final $WatchlistsTable watchlists = $WatchlistsTable(this);
  late final $WatchlistItemsTable watchlistItems = $WatchlistItemsTable(this);
  late final $TmdbOverridesTable tmdbOverrides = $TmdbOverridesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sources,
    cachedChannels,
    cachedDetails,
    favorites,
    watchHistory,
    epgPrograms,
    userRatings,
    watchlists,
    watchlistItems,
    tmdbOverrides,
  ];
}

typedef $$SourcesTableCreateCompanionBuilder =
    SourcesCompanion Function({
      required String id,
      required String name,
      required String type,
      required String configJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SourcesTableUpdateCompanionBuilder =
    SourcesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String> configJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SourcesTableFilterComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourcesTable,
          Source,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (Source, BaseReferences<_$AppDatabase, $SourcesTable, Source>),
          Source,
          PrefetchHooks Function()
        > {
  $$SourcesTableTableManager(_$AppDatabase db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                name: name,
                type: type,
                configJson: configJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                required String configJson,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                name: name,
                type: type,
                configJson: configJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourcesTable,
      Source,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (Source, BaseReferences<_$AppDatabase, $SourcesTable, Source>),
      Source,
      PrefetchHooks Function()
    >;
typedef $$CachedChannelsTableCreateCompanionBuilder =
    CachedChannelsCompanion Function({
      required String id,
      required String sourceId,
      required String streamId,
      required String name,
      Value<String?> logoUrl,
      required String streamUrl,
      Value<String?> categoryId,
      Value<String?> categoryName,
      required String kind,
      Value<String?> plot,
      Value<String?> backdropUrl,
      Value<int?> year,
      Value<double?> rating,
      Value<int> position,
      required DateTime cachedAt,
      Value<String?> epgChannelId,
      Value<DateTime?> addedAt,
      Value<String?> seriesId,
      Value<int> rowid,
    });
typedef $$CachedChannelsTableUpdateCompanionBuilder =
    CachedChannelsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> streamId,
      Value<String> name,
      Value<String?> logoUrl,
      Value<String> streamUrl,
      Value<String?> categoryId,
      Value<String?> categoryName,
      Value<String> kind,
      Value<String?> plot,
      Value<String?> backdropUrl,
      Value<int?> year,
      Value<double?> rating,
      Value<int> position,
      Value<DateTime> cachedAt,
      Value<String?> epgChannelId,
      Value<DateTime?> addedAt,
      Value<String?> seriesId,
      Value<int> rowid,
    });

class $$CachedChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedChannelsTable> {
  $$CachedChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamId => $composableBuilder(
    column: $table.streamId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedChannelsTable> {
  $$CachedChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamId => $composableBuilder(
    column: $table.streamId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedChannelsTable> {
  $$CachedChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get streamId =>
      $composableBuilder(column: $table.streamId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);
}

class $$CachedChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedChannelsTable,
          CachedChannel,
          $$CachedChannelsTableFilterComposer,
          $$CachedChannelsTableOrderingComposer,
          $$CachedChannelsTableAnnotationComposer,
          $$CachedChannelsTableCreateCompanionBuilder,
          $$CachedChannelsTableUpdateCompanionBuilder,
          (
            CachedChannel,
            BaseReferences<_$AppDatabase, $CachedChannelsTable, CachedChannel>,
          ),
          CachedChannel,
          PrefetchHooks Function()
        > {
  $$CachedChannelsTableTableManager(
    _$AppDatabase db,
    $CachedChannelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> streamId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String> streamUrl = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> categoryName = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String?> epgChannelId = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedChannelsCompanion(
                id: id,
                sourceId: sourceId,
                streamId: streamId,
                name: name,
                logoUrl: logoUrl,
                streamUrl: streamUrl,
                categoryId: categoryId,
                categoryName: categoryName,
                kind: kind,
                plot: plot,
                backdropUrl: backdropUrl,
                year: year,
                rating: rating,
                position: position,
                cachedAt: cachedAt,
                epgChannelId: epgChannelId,
                addedAt: addedAt,
                seriesId: seriesId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String streamId,
                required String name,
                Value<String?> logoUrl = const Value.absent(),
                required String streamUrl,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> categoryName = const Value.absent(),
                required String kind,
                Value<String?> plot = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int> position = const Value.absent(),
                required DateTime cachedAt,
                Value<String?> epgChannelId = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedChannelsCompanion.insert(
                id: id,
                sourceId: sourceId,
                streamId: streamId,
                name: name,
                logoUrl: logoUrl,
                streamUrl: streamUrl,
                categoryId: categoryId,
                categoryName: categoryName,
                kind: kind,
                plot: plot,
                backdropUrl: backdropUrl,
                year: year,
                rating: rating,
                position: position,
                cachedAt: cachedAt,
                epgChannelId: epgChannelId,
                addedAt: addedAt,
                seriesId: seriesId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedChannelsTable,
      CachedChannel,
      $$CachedChannelsTableFilterComposer,
      $$CachedChannelsTableOrderingComposer,
      $$CachedChannelsTableAnnotationComposer,
      $$CachedChannelsTableCreateCompanionBuilder,
      $$CachedChannelsTableUpdateCompanionBuilder,
      (
        CachedChannel,
        BaseReferences<_$AppDatabase, $CachedChannelsTable, CachedChannel>,
      ),
      CachedChannel,
      PrefetchHooks Function()
    >;
typedef $$CachedDetailsTableCreateCompanionBuilder =
    CachedDetailsCompanion Function({
      required String id,
      required String sourceId,
      required String streamId,
      required String kind,
      Value<String?> castCsv,
      Value<String?> directorsCsv,
      Value<String?> genresCsv,
      Value<String?> plot,
      Value<String?> country,
      Value<int?> runtimeSeconds,
      Value<String?> releaseDate,
      Value<String?> coverUrl,
      Value<String?> backdropUrl,
      Value<double?> rating,
      required DateTime cachedAt,
      Value<String?> originalTitle,
      Value<String?> localizedTitle,
      Value<String?> keywordsCsv,
      Value<String?> imdbId,
      Value<int?> tmdbId,
      Value<int> rowid,
    });
typedef $$CachedDetailsTableUpdateCompanionBuilder =
    CachedDetailsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> streamId,
      Value<String> kind,
      Value<String?> castCsv,
      Value<String?> directorsCsv,
      Value<String?> genresCsv,
      Value<String?> plot,
      Value<String?> country,
      Value<int?> runtimeSeconds,
      Value<String?> releaseDate,
      Value<String?> coverUrl,
      Value<String?> backdropUrl,
      Value<double?> rating,
      Value<DateTime> cachedAt,
      Value<String?> originalTitle,
      Value<String?> localizedTitle,
      Value<String?> keywordsCsv,
      Value<String?> imdbId,
      Value<int?> tmdbId,
      Value<int> rowid,
    });

class $$CachedDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDetailsTable> {
  $$CachedDetailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamId => $composableBuilder(
    column: $table.streamId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get castCsv => $composableBuilder(
    column: $table.castCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directorsCsv => $composableBuilder(
    column: $table.directorsCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genresCsv => $composableBuilder(
    column: $table.genresCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runtimeSeconds => $composableBuilder(
    column: $table.runtimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localizedTitle => $composableBuilder(
    column: $table.localizedTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keywordsCsv => $composableBuilder(
    column: $table.keywordsCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imdbId => $composableBuilder(
    column: $table.imdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDetailsTable> {
  $$CachedDetailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamId => $composableBuilder(
    column: $table.streamId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get castCsv => $composableBuilder(
    column: $table.castCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directorsCsv => $composableBuilder(
    column: $table.directorsCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genresCsv => $composableBuilder(
    column: $table.genresCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runtimeSeconds => $composableBuilder(
    column: $table.runtimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localizedTitle => $composableBuilder(
    column: $table.localizedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keywordsCsv => $composableBuilder(
    column: $table.keywordsCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imdbId => $composableBuilder(
    column: $table.imdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDetailsTable> {
  $$CachedDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get streamId =>
      $composableBuilder(column: $table.streamId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get castCsv =>
      $composableBuilder(column: $table.castCsv, builder: (column) => column);

  GeneratedColumn<String> get directorsCsv => $composableBuilder(
    column: $table.directorsCsv,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genresCsv =>
      $composableBuilder(column: $table.genresCsv, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<int> get runtimeSeconds => $composableBuilder(
    column: $table.runtimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localizedTitle => $composableBuilder(
    column: $table.localizedTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get keywordsCsv => $composableBuilder(
    column: $table.keywordsCsv,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imdbId =>
      $composableBuilder(column: $table.imdbId, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);
}

class $$CachedDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDetailsTable,
          CachedDetail,
          $$CachedDetailsTableFilterComposer,
          $$CachedDetailsTableOrderingComposer,
          $$CachedDetailsTableAnnotationComposer,
          $$CachedDetailsTableCreateCompanionBuilder,
          $$CachedDetailsTableUpdateCompanionBuilder,
          (
            CachedDetail,
            BaseReferences<_$AppDatabase, $CachedDetailsTable, CachedDetail>,
          ),
          CachedDetail,
          PrefetchHooks Function()
        > {
  $$CachedDetailsTableTableManager(_$AppDatabase db, $CachedDetailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> streamId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> castCsv = const Value.absent(),
                Value<String?> directorsCsv = const Value.absent(),
                Value<String?> genresCsv = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<int?> runtimeSeconds = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String?> originalTitle = const Value.absent(),
                Value<String?> localizedTitle = const Value.absent(),
                Value<String?> keywordsCsv = const Value.absent(),
                Value<String?> imdbId = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDetailsCompanion(
                id: id,
                sourceId: sourceId,
                streamId: streamId,
                kind: kind,
                castCsv: castCsv,
                directorsCsv: directorsCsv,
                genresCsv: genresCsv,
                plot: plot,
                country: country,
                runtimeSeconds: runtimeSeconds,
                releaseDate: releaseDate,
                coverUrl: coverUrl,
                backdropUrl: backdropUrl,
                rating: rating,
                cachedAt: cachedAt,
                originalTitle: originalTitle,
                localizedTitle: localizedTitle,
                keywordsCsv: keywordsCsv,
                imdbId: imdbId,
                tmdbId: tmdbId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String streamId,
                required String kind,
                Value<String?> castCsv = const Value.absent(),
                Value<String?> directorsCsv = const Value.absent(),
                Value<String?> genresCsv = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<int?> runtimeSeconds = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                required DateTime cachedAt,
                Value<String?> originalTitle = const Value.absent(),
                Value<String?> localizedTitle = const Value.absent(),
                Value<String?> keywordsCsv = const Value.absent(),
                Value<String?> imdbId = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDetailsCompanion.insert(
                id: id,
                sourceId: sourceId,
                streamId: streamId,
                kind: kind,
                castCsv: castCsv,
                directorsCsv: directorsCsv,
                genresCsv: genresCsv,
                plot: plot,
                country: country,
                runtimeSeconds: runtimeSeconds,
                releaseDate: releaseDate,
                coverUrl: coverUrl,
                backdropUrl: backdropUrl,
                rating: rating,
                cachedAt: cachedAt,
                originalTitle: originalTitle,
                localizedTitle: localizedTitle,
                keywordsCsv: keywordsCsv,
                imdbId: imdbId,
                tmdbId: tmdbId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDetailsTable,
      CachedDetail,
      $$CachedDetailsTableFilterComposer,
      $$CachedDetailsTableOrderingComposer,
      $$CachedDetailsTableAnnotationComposer,
      $$CachedDetailsTableCreateCompanionBuilder,
      $$CachedDetailsTableUpdateCompanionBuilder,
      (
        CachedDetail,
        BaseReferences<_$AppDatabase, $CachedDetailsTable, CachedDetail>,
      ),
      CachedDetail,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      required String contentId,
      required String sourceId,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<String> contentId,
      Value<String> sourceId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
          Favorite,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> contentId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                contentId: contentId,
                sourceId: sourceId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentId,
                required String sourceId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                contentId: contentId,
                sourceId: sourceId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
      Favorite,
      PrefetchHooks Function()
    >;
typedef $$WatchHistoryTableCreateCompanionBuilder =
    WatchHistoryCompanion Function({
      required String contentId,
      required String sourceId,
      Value<String?> parentId,
      required int positionMs,
      required int durationMs,
      required DateTime lastWatchedAt,
      Value<int> actualWatchMs,
      Value<int> seekForwardCount,
      Value<int> seekBackwardCount,
      Value<int> seekForwardMs,
      Value<int> seekBackwardMs,
      Value<String?> episodeLabel,
      Value<String?> categoryName,
      Value<int> rowid,
    });
typedef $$WatchHistoryTableUpdateCompanionBuilder =
    WatchHistoryCompanion Function({
      Value<String> contentId,
      Value<String> sourceId,
      Value<String?> parentId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<DateTime> lastWatchedAt,
      Value<int> actualWatchMs,
      Value<int> seekForwardCount,
      Value<int> seekBackwardCount,
      Value<int> seekForwardMs,
      Value<int> seekBackwardMs,
      Value<String?> episodeLabel,
      Value<String?> categoryName,
      Value<int> rowid,
    });

class $$WatchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualWatchMs => $composableBuilder(
    column: $table.actualWatchMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seekForwardCount => $composableBuilder(
    column: $table.seekForwardCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seekBackwardCount => $composableBuilder(
    column: $table.seekBackwardCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seekForwardMs => $composableBuilder(
    column: $table.seekForwardMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seekBackwardMs => $composableBuilder(
    column: $table.seekBackwardMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualWatchMs => $composableBuilder(
    column: $table.actualWatchMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seekForwardCount => $composableBuilder(
    column: $table.seekForwardCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seekBackwardCount => $composableBuilder(
    column: $table.seekBackwardCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seekForwardMs => $composableBuilder(
    column: $table.seekForwardMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seekBackwardMs => $composableBuilder(
    column: $table.seekBackwardMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualWatchMs => $composableBuilder(
    column: $table.actualWatchMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seekForwardCount => $composableBuilder(
    column: $table.seekForwardCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seekBackwardCount => $composableBuilder(
    column: $table.seekBackwardCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seekForwardMs => $composableBuilder(
    column: $table.seekForwardMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seekBackwardMs => $composableBuilder(
    column: $table.seekBackwardMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => column,
  );
}

class $$WatchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchHistoryTable,
          WatchHistoryData,
          $$WatchHistoryTableFilterComposer,
          $$WatchHistoryTableOrderingComposer,
          $$WatchHistoryTableAnnotationComposer,
          $$WatchHistoryTableCreateCompanionBuilder,
          $$WatchHistoryTableUpdateCompanionBuilder,
          (
            WatchHistoryData,
            BaseReferences<_$AppDatabase, $WatchHistoryTable, WatchHistoryData>,
          ),
          WatchHistoryData,
          PrefetchHooks Function()
        > {
  $$WatchHistoryTableTableManager(_$AppDatabase db, $WatchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> contentId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> lastWatchedAt = const Value.absent(),
                Value<int> actualWatchMs = const Value.absent(),
                Value<int> seekForwardCount = const Value.absent(),
                Value<int> seekBackwardCount = const Value.absent(),
                Value<int> seekForwardMs = const Value.absent(),
                Value<int> seekBackwardMs = const Value.absent(),
                Value<String?> episodeLabel = const Value.absent(),
                Value<String?> categoryName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchHistoryCompanion(
                contentId: contentId,
                sourceId: sourceId,
                parentId: parentId,
                positionMs: positionMs,
                durationMs: durationMs,
                lastWatchedAt: lastWatchedAt,
                actualWatchMs: actualWatchMs,
                seekForwardCount: seekForwardCount,
                seekBackwardCount: seekBackwardCount,
                seekForwardMs: seekForwardMs,
                seekBackwardMs: seekBackwardMs,
                episodeLabel: episodeLabel,
                categoryName: categoryName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentId,
                required String sourceId,
                Value<String?> parentId = const Value.absent(),
                required int positionMs,
                required int durationMs,
                required DateTime lastWatchedAt,
                Value<int> actualWatchMs = const Value.absent(),
                Value<int> seekForwardCount = const Value.absent(),
                Value<int> seekBackwardCount = const Value.absent(),
                Value<int> seekForwardMs = const Value.absent(),
                Value<int> seekBackwardMs = const Value.absent(),
                Value<String?> episodeLabel = const Value.absent(),
                Value<String?> categoryName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchHistoryCompanion.insert(
                contentId: contentId,
                sourceId: sourceId,
                parentId: parentId,
                positionMs: positionMs,
                durationMs: durationMs,
                lastWatchedAt: lastWatchedAt,
                actualWatchMs: actualWatchMs,
                seekForwardCount: seekForwardCount,
                seekBackwardCount: seekBackwardCount,
                seekForwardMs: seekForwardMs,
                seekBackwardMs: seekBackwardMs,
                episodeLabel: episodeLabel,
                categoryName: categoryName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchHistoryTable,
      WatchHistoryData,
      $$WatchHistoryTableFilterComposer,
      $$WatchHistoryTableOrderingComposer,
      $$WatchHistoryTableAnnotationComposer,
      $$WatchHistoryTableCreateCompanionBuilder,
      $$WatchHistoryTableUpdateCompanionBuilder,
      (
        WatchHistoryData,
        BaseReferences<_$AppDatabase, $WatchHistoryTable, WatchHistoryData>,
      ),
      WatchHistoryData,
      PrefetchHooks Function()
    >;
typedef $$EpgProgramsTableCreateCompanionBuilder =
    EpgProgramsCompanion Function({
      required String sourceId,
      required String channelId,
      required DateTime start,
      required DateTime stop,
      required String title,
      Value<String?> description,
      Value<String?> categoriesCsv,
      Value<int> rowid,
    });
typedef $$EpgProgramsTableUpdateCompanionBuilder =
    EpgProgramsCompanion Function({
      Value<String> sourceId,
      Value<String> channelId,
      Value<DateTime> start,
      Value<DateTime> stop,
      Value<String> title,
      Value<String?> description,
      Value<String?> categoriesCsv,
      Value<int> rowid,
    });

class $$EpgProgramsTableFilterComposer
    extends Composer<_$AppDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get stop => $composableBuilder(
    column: $table.stop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriesCsv => $composableBuilder(
    column: $table.categoriesCsv,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpgProgramsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get stop => $composableBuilder(
    column: $table.stop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriesCsv => $composableBuilder(
    column: $table.categoriesCsv,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgProgramsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get stop =>
      $composableBuilder(column: $table.stop, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoriesCsv => $composableBuilder(
    column: $table.categoriesCsv,
    builder: (column) => column,
  );
}

class $$EpgProgramsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgProgramsTable,
          EpgProgramRow,
          $$EpgProgramsTableFilterComposer,
          $$EpgProgramsTableOrderingComposer,
          $$EpgProgramsTableAnnotationComposer,
          $$EpgProgramsTableCreateCompanionBuilder,
          $$EpgProgramsTableUpdateCompanionBuilder,
          (
            EpgProgramRow,
            BaseReferences<_$AppDatabase, $EpgProgramsTable, EpgProgramRow>,
          ),
          EpgProgramRow,
          PrefetchHooks Function()
        > {
  $$EpgProgramsTableTableManager(_$AppDatabase db, $EpgProgramsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgProgramsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgProgramsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgProgramsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<DateTime> start = const Value.absent(),
                Value<DateTime> stop = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> categoriesCsv = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgProgramsCompanion(
                sourceId: sourceId,
                channelId: channelId,
                start: start,
                stop: stop,
                title: title,
                description: description,
                categoriesCsv: categoriesCsv,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String channelId,
                required DateTime start,
                required DateTime stop,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> categoriesCsv = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgProgramsCompanion.insert(
                sourceId: sourceId,
                channelId: channelId,
                start: start,
                stop: stop,
                title: title,
                description: description,
                categoriesCsv: categoriesCsv,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpgProgramsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgProgramsTable,
      EpgProgramRow,
      $$EpgProgramsTableFilterComposer,
      $$EpgProgramsTableOrderingComposer,
      $$EpgProgramsTableAnnotationComposer,
      $$EpgProgramsTableCreateCompanionBuilder,
      $$EpgProgramsTableUpdateCompanionBuilder,
      (
        EpgProgramRow,
        BaseReferences<_$AppDatabase, $EpgProgramsTable, EpgProgramRow>,
      ),
      EpgProgramRow,
      PrefetchHooks Function()
    >;
typedef $$UserRatingsTableCreateCompanionBuilder =
    UserRatingsCompanion Function({
      required String contentId,
      required String sourceId,
      Value<String?> parentId,
      required double score,
      Value<String?> comment,
      required DateTime ratedAt,
      Value<int?> tmdbId,
      Value<int> rowid,
    });
typedef $$UserRatingsTableUpdateCompanionBuilder =
    UserRatingsCompanion Function({
      Value<String> contentId,
      Value<String> sourceId,
      Value<String?> parentId,
      Value<double> score,
      Value<String?> comment,
      Value<DateTime> ratedAt,
      Value<int?> tmdbId,
      Value<int> rowid,
    });

class $$UserRatingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserRatingsTable> {
  $$UserRatingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ratedAt => $composableBuilder(
    column: $table.ratedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserRatingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserRatingsTable> {
  $$UserRatingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ratedAt => $composableBuilder(
    column: $table.ratedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserRatingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserRatingsTable> {
  $$UserRatingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<DateTime> get ratedAt =>
      $composableBuilder(column: $table.ratedAt, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);
}

class $$UserRatingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserRatingsTable,
          UserRating,
          $$UserRatingsTableFilterComposer,
          $$UserRatingsTableOrderingComposer,
          $$UserRatingsTableAnnotationComposer,
          $$UserRatingsTableCreateCompanionBuilder,
          $$UserRatingsTableUpdateCompanionBuilder,
          (
            UserRating,
            BaseReferences<_$AppDatabase, $UserRatingsTable, UserRating>,
          ),
          UserRating,
          PrefetchHooks Function()
        > {
  $$UserRatingsTableTableManager(_$AppDatabase db, $UserRatingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserRatingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserRatingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserRatingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> contentId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<DateTime> ratedAt = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRatingsCompanion(
                contentId: contentId,
                sourceId: sourceId,
                parentId: parentId,
                score: score,
                comment: comment,
                ratedAt: ratedAt,
                tmdbId: tmdbId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentId,
                required String sourceId,
                Value<String?> parentId = const Value.absent(),
                required double score,
                Value<String?> comment = const Value.absent(),
                required DateTime ratedAt,
                Value<int?> tmdbId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserRatingsCompanion.insert(
                contentId: contentId,
                sourceId: sourceId,
                parentId: parentId,
                score: score,
                comment: comment,
                ratedAt: ratedAt,
                tmdbId: tmdbId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserRatingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserRatingsTable,
      UserRating,
      $$UserRatingsTableFilterComposer,
      $$UserRatingsTableOrderingComposer,
      $$UserRatingsTableAnnotationComposer,
      $$UserRatingsTableCreateCompanionBuilder,
      $$UserRatingsTableUpdateCompanionBuilder,
      (
        UserRating,
        BaseReferences<_$AppDatabase, $UserRatingsTable, UserRating>,
      ),
      UserRating,
      PrefetchHooks Function()
    >;
typedef $$WatchlistsTableCreateCompanionBuilder =
    WatchlistsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<int> position,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WatchlistsTableUpdateCompanionBuilder =
    WatchlistsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<int> position,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$WatchlistsTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistsTable> {
  $$WatchlistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchlistsTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistsTable> {
  $$WatchlistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchlistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistsTable> {
  $$WatchlistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WatchlistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchlistsTable,
          Watchlist,
          $$WatchlistsTableFilterComposer,
          $$WatchlistsTableOrderingComposer,
          $$WatchlistsTableAnnotationComposer,
          $$WatchlistsTableCreateCompanionBuilder,
          $$WatchlistsTableUpdateCompanionBuilder,
          (
            Watchlist,
            BaseReferences<_$AppDatabase, $WatchlistsTable, Watchlist>,
          ),
          Watchlist,
          PrefetchHooks Function()
        > {
  $$WatchlistsTableTableManager(_$AppDatabase db, $WatchlistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchlistsCompanion(
                id: id,
                name: name,
                description: description,
                position: position,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<int> position = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchlistsCompanion.insert(
                id: id,
                name: name,
                description: description,
                position: position,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchlistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchlistsTable,
      Watchlist,
      $$WatchlistsTableFilterComposer,
      $$WatchlistsTableOrderingComposer,
      $$WatchlistsTableAnnotationComposer,
      $$WatchlistsTableCreateCompanionBuilder,
      $$WatchlistsTableUpdateCompanionBuilder,
      (Watchlist, BaseReferences<_$AppDatabase, $WatchlistsTable, Watchlist>),
      Watchlist,
      PrefetchHooks Function()
    >;
typedef $$WatchlistItemsTableCreateCompanionBuilder =
    WatchlistItemsCompanion Function({
      required String watchlistId,
      required String contentId,
      required String sourceId,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$WatchlistItemsTableUpdateCompanionBuilder =
    WatchlistItemsCompanion Function({
      Value<String> watchlistId,
      Value<String> contentId,
      Value<String> sourceId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$WatchlistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistItemsTable> {
  $$WatchlistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get watchlistId => $composableBuilder(
    column: $table.watchlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchlistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistItemsTable> {
  $$WatchlistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get watchlistId => $composableBuilder(
    column: $table.watchlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchlistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistItemsTable> {
  $$WatchlistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get watchlistId => $composableBuilder(
    column: $table.watchlistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$WatchlistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchlistItemsTable,
          WatchlistItem,
          $$WatchlistItemsTableFilterComposer,
          $$WatchlistItemsTableOrderingComposer,
          $$WatchlistItemsTableAnnotationComposer,
          $$WatchlistItemsTableCreateCompanionBuilder,
          $$WatchlistItemsTableUpdateCompanionBuilder,
          (
            WatchlistItem,
            BaseReferences<_$AppDatabase, $WatchlistItemsTable, WatchlistItem>,
          ),
          WatchlistItem,
          PrefetchHooks Function()
        > {
  $$WatchlistItemsTableTableManager(
    _$AppDatabase db,
    $WatchlistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> watchlistId = const Value.absent(),
                Value<String> contentId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchlistItemsCompanion(
                watchlistId: watchlistId,
                contentId: contentId,
                sourceId: sourceId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String watchlistId,
                required String contentId,
                required String sourceId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchlistItemsCompanion.insert(
                watchlistId: watchlistId,
                contentId: contentId,
                sourceId: sourceId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchlistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchlistItemsTable,
      WatchlistItem,
      $$WatchlistItemsTableFilterComposer,
      $$WatchlistItemsTableOrderingComposer,
      $$WatchlistItemsTableAnnotationComposer,
      $$WatchlistItemsTableCreateCompanionBuilder,
      $$WatchlistItemsTableUpdateCompanionBuilder,
      (
        WatchlistItem,
        BaseReferences<_$AppDatabase, $WatchlistItemsTable, WatchlistItem>,
      ),
      WatchlistItem,
      PrefetchHooks Function()
    >;
typedef $$TmdbOverridesTableCreateCompanionBuilder =
    TmdbOverridesCompanion Function({
      required String contentId,
      required String sourceId,
      required int tmdbId,
      required bool isMovie,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$TmdbOverridesTableUpdateCompanionBuilder =
    TmdbOverridesCompanion Function({
      Value<String> contentId,
      Value<String> sourceId,
      Value<int> tmdbId,
      Value<bool> isMovie,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$TmdbOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $TmdbOverridesTable> {
  $$TmdbOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMovie => $composableBuilder(
    column: $table.isMovie,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TmdbOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $TmdbOverridesTable> {
  $$TmdbOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMovie => $composableBuilder(
    column: $table.isMovie,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TmdbOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TmdbOverridesTable> {
  $$TmdbOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<bool> get isMovie =>
      $composableBuilder(column: $table.isMovie, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$TmdbOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TmdbOverridesTable,
          TmdbOverride,
          $$TmdbOverridesTableFilterComposer,
          $$TmdbOverridesTableOrderingComposer,
          $$TmdbOverridesTableAnnotationComposer,
          $$TmdbOverridesTableCreateCompanionBuilder,
          $$TmdbOverridesTableUpdateCompanionBuilder,
          (
            TmdbOverride,
            BaseReferences<_$AppDatabase, $TmdbOverridesTable, TmdbOverride>,
          ),
          TmdbOverride,
          PrefetchHooks Function()
        > {
  $$TmdbOverridesTableTableManager(_$AppDatabase db, $TmdbOverridesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TmdbOverridesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TmdbOverridesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TmdbOverridesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> contentId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> tmdbId = const Value.absent(),
                Value<bool> isMovie = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TmdbOverridesCompanion(
                contentId: contentId,
                sourceId: sourceId,
                tmdbId: tmdbId,
                isMovie: isMovie,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentId,
                required String sourceId,
                required int tmdbId,
                required bool isMovie,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => TmdbOverridesCompanion.insert(
                contentId: contentId,
                sourceId: sourceId,
                tmdbId: tmdbId,
                isMovie: isMovie,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TmdbOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TmdbOverridesTable,
      TmdbOverride,
      $$TmdbOverridesTableFilterComposer,
      $$TmdbOverridesTableOrderingComposer,
      $$TmdbOverridesTableAnnotationComposer,
      $$TmdbOverridesTableCreateCompanionBuilder,
      $$TmdbOverridesTableUpdateCompanionBuilder,
      (
        TmdbOverride,
        BaseReferences<_$AppDatabase, $TmdbOverridesTable, TmdbOverride>,
      ),
      TmdbOverride,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$CachedChannelsTableTableManager get cachedChannels =>
      $$CachedChannelsTableTableManager(_db, _db.cachedChannels);
  $$CachedDetailsTableTableManager get cachedDetails =>
      $$CachedDetailsTableTableManager(_db, _db.cachedDetails);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$WatchHistoryTableTableManager get watchHistory =>
      $$WatchHistoryTableTableManager(_db, _db.watchHistory);
  $$EpgProgramsTableTableManager get epgPrograms =>
      $$EpgProgramsTableTableManager(_db, _db.epgPrograms);
  $$UserRatingsTableTableManager get userRatings =>
      $$UserRatingsTableTableManager(_db, _db.userRatings);
  $$WatchlistsTableTableManager get watchlists =>
      $$WatchlistsTableTableManager(_db, _db.watchlists);
  $$WatchlistItemsTableTableManager get watchlistItems =>
      $$WatchlistItemsTableTableManager(_db, _db.watchlistItems);
  $$TmdbOverridesTableTableManager get tmdbOverrides =>
      $$TmdbOverridesTableTableManager(_db, _db.tmdbOverrides);
}
