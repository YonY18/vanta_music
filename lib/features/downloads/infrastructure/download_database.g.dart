// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_database.dart';

// ignore_for_file: type=lint
class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _downloadKeyMeta = const VerificationMeta(
    'downloadKey',
  );
  @override
  late final GeneratedColumn<String> downloadKey = GeneratedColumn<String>(
    'download_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerFamilyMeta = const VerificationMeta(
    'providerFamily',
  );
  @override
  late final GeneratedColumn<String> providerFamily = GeneratedColumn<String>(
    'provider_family',
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
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteItemIdMeta = const VerificationMeta(
    'remoteItemId',
  );
  @override
  late final GeneratedColumn<String> remoteItemId = GeneratedColumn<String>(
    'remote_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalUriMeta = const VerificationMeta(
    'canonicalUri',
  );
  @override
  late final GeneratedColumn<String> canonicalUri = GeneratedColumn<String>(
    'canonical_uri',
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
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverArtIdMeta = const VerificationMeta(
    'coverArtId',
  );
  @override
  late final GeneratedColumn<String> coverArtId = GeneratedColumn<String>(
    'cover_art_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DownloadStatus>($DownloadsTable.$converterstatus);
  static const VerificationMeta _progressBytesMeta = const VerificationMeta(
    'progressBytes',
  );
  @override
  late final GeneratedColumn<int> progressBytes = GeneratedColumn<int>(
    'progress_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRelativePathMeta = const VerificationMeta(
    'localRelativePath',
  );
  @override
  late final GeneratedColumn<String> localRelativePath =
      GeneratedColumn<String>(
        'local_relative_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _tempRelativePathMeta = const VerificationMeta(
    'tempRelativePath',
  );
  @override
  late final GeneratedColumn<String> tempRelativePath = GeneratedColumn<String>(
    'temp_relative_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryableMeta = const VerificationMeta(
    'retryable',
  );
  @override
  late final GeneratedColumn<bool> retryable = GeneratedColumn<bool>(
    'retryable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("retryable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastValidatedAtMeta = const VerificationMeta(
    'lastValidatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastValidatedAt =
      GeneratedColumn<DateTime>(
        'last_validated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    downloadKey,
    providerFamily,
    providerId,
    serverId,
    trackId,
    remoteItemId,
    canonicalUri,
    title,
    artist,
    album,
    coverArtId,
    status,
    progressBytes,
    totalBytes,
    sizeBytes,
    localRelativePath,
    tempRelativePath,
    contentType,
    etag,
    errorCode,
    errorMessage,
    retryable,
    createdAt,
    updatedAt,
    completedAt,
    lastValidatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Download> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('download_key')) {
      context.handle(
        _downloadKeyMeta,
        downloadKey.isAcceptableOrUnknown(
          data['download_key']!,
          _downloadKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadKeyMeta);
    }
    if (data.containsKey('provider_family')) {
      context.handle(
        _providerFamilyMeta,
        providerFamily.isAcceptableOrUnknown(
          data['provider_family']!,
          _providerFamilyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerFamilyMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('remote_item_id')) {
      context.handle(
        _remoteItemIdMeta,
        remoteItemId.isAcceptableOrUnknown(
          data['remote_item_id']!,
          _remoteItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteItemIdMeta);
    }
    if (data.containsKey('canonical_uri')) {
      context.handle(
        _canonicalUriMeta,
        canonicalUri.isAcceptableOrUnknown(
          data['canonical_uri']!,
          _canonicalUriMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalUriMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    } else if (isInserting) {
      context.missing(_albumMeta);
    }
    if (data.containsKey('cover_art_id')) {
      context.handle(
        _coverArtIdMeta,
        coverArtId.isAcceptableOrUnknown(
          data['cover_art_id']!,
          _coverArtIdMeta,
        ),
      );
    }
    if (data.containsKey('progress_bytes')) {
      context.handle(
        _progressBytesMeta,
        progressBytes.isAcceptableOrUnknown(
          data['progress_bytes']!,
          _progressBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('local_relative_path')) {
      context.handle(
        _localRelativePathMeta,
        localRelativePath.isAcceptableOrUnknown(
          data['local_relative_path']!,
          _localRelativePathMeta,
        ),
      );
    }
    if (data.containsKey('temp_relative_path')) {
      context.handle(
        _tempRelativePathMeta,
        tempRelativePath.isAcceptableOrUnknown(
          data['temp_relative_path']!,
          _tempRelativePathMeta,
        ),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('retryable')) {
      context.handle(
        _retryableMeta,
        retryable.isAcceptableOrUnknown(data['retryable']!, _retryableMeta),
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_validated_at')) {
      context.handle(
        _lastValidatedAtMeta,
        lastValidatedAt.isAcceptableOrUnknown(
          data['last_validated_at']!,
          _lastValidatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {downloadKey};
  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      downloadKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_key'],
      )!,
      providerFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_family'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      remoteItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_item_id'],
      )!,
      canonicalUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_uri'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      coverArtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_art_id'],
      ),
      status: $DownloadsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      progressBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      localRelativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_relative_path'],
      ),
      tempRelativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temp_relative_path'],
      ),
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      retryable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}retryable'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      lastValidatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_validated_at'],
      ),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadStatus, String, String> $converterstatus =
      const EnumNameConverter<DownloadStatus>(DownloadStatus.values);
}

class Download extends DataClass implements Insertable<Download> {
  final String downloadKey;
  final String providerFamily;
  final String providerId;
  final String serverId;
  final String trackId;
  final String remoteItemId;
  final String canonicalUri;
  final String title;
  final String artist;
  final String album;
  final String? coverArtId;
  final DownloadStatus status;
  final int progressBytes;
  final int? totalBytes;
  final int? sizeBytes;
  final String? localRelativePath;
  final String? tempRelativePath;
  final String? contentType;
  final String? etag;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? lastValidatedAt;
  const Download({
    required this.downloadKey,
    required this.providerFamily,
    required this.providerId,
    required this.serverId,
    required this.trackId,
    required this.remoteItemId,
    required this.canonicalUri,
    required this.title,
    required this.artist,
    required this.album,
    this.coverArtId,
    required this.status,
    required this.progressBytes,
    this.totalBytes,
    this.sizeBytes,
    this.localRelativePath,
    this.tempRelativePath,
    this.contentType,
    this.etag,
    this.errorCode,
    this.errorMessage,
    required this.retryable,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.lastValidatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['download_key'] = Variable<String>(downloadKey);
    map['provider_family'] = Variable<String>(providerFamily);
    map['provider_id'] = Variable<String>(providerId);
    map['server_id'] = Variable<String>(serverId);
    map['track_id'] = Variable<String>(trackId);
    map['remote_item_id'] = Variable<String>(remoteItemId);
    map['canonical_uri'] = Variable<String>(canonicalUri);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    if (!nullToAbsent || coverArtId != null) {
      map['cover_art_id'] = Variable<String>(coverArtId);
    }
    {
      map['status'] = Variable<String>(
        $DownloadsTable.$converterstatus.toSql(status),
      );
    }
    map['progress_bytes'] = Variable<int>(progressBytes);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || localRelativePath != null) {
      map['local_relative_path'] = Variable<String>(localRelativePath);
    }
    if (!nullToAbsent || tempRelativePath != null) {
      map['temp_relative_path'] = Variable<String>(tempRelativePath);
    }
    if (!nullToAbsent || contentType != null) {
      map['content_type'] = Variable<String>(contentType);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['retryable'] = Variable<bool>(retryable);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || lastValidatedAt != null) {
      map['last_validated_at'] = Variable<DateTime>(lastValidatedAt);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      downloadKey: Value(downloadKey),
      providerFamily: Value(providerFamily),
      providerId: Value(providerId),
      serverId: Value(serverId),
      trackId: Value(trackId),
      remoteItemId: Value(remoteItemId),
      canonicalUri: Value(canonicalUri),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      coverArtId: coverArtId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArtId),
      status: Value(status),
      progressBytes: Value(progressBytes),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      localRelativePath: localRelativePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localRelativePath),
      tempRelativePath: tempRelativePath == null && nullToAbsent
          ? const Value.absent()
          : Value(tempRelativePath),
      contentType: contentType == null && nullToAbsent
          ? const Value.absent()
          : Value(contentType),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      retryable: Value(retryable),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      lastValidatedAt: lastValidatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastValidatedAt),
    );
  }

  factory Download.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      downloadKey: serializer.fromJson<String>(json['downloadKey']),
      providerFamily: serializer.fromJson<String>(json['providerFamily']),
      providerId: serializer.fromJson<String>(json['providerId']),
      serverId: serializer.fromJson<String>(json['serverId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      remoteItemId: serializer.fromJson<String>(json['remoteItemId']),
      canonicalUri: serializer.fromJson<String>(json['canonicalUri']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      coverArtId: serializer.fromJson<String?>(json['coverArtId']),
      status: $DownloadsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      progressBytes: serializer.fromJson<int>(json['progressBytes']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      localRelativePath: serializer.fromJson<String?>(
        json['localRelativePath'],
      ),
      tempRelativePath: serializer.fromJson<String?>(json['tempRelativePath']),
      contentType: serializer.fromJson<String?>(json['contentType']),
      etag: serializer.fromJson<String?>(json['etag']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      retryable: serializer.fromJson<bool>(json['retryable']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      lastValidatedAt: serializer.fromJson<DateTime?>(json['lastValidatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'downloadKey': serializer.toJson<String>(downloadKey),
      'providerFamily': serializer.toJson<String>(providerFamily),
      'providerId': serializer.toJson<String>(providerId),
      'serverId': serializer.toJson<String>(serverId),
      'trackId': serializer.toJson<String>(trackId),
      'remoteItemId': serializer.toJson<String>(remoteItemId),
      'canonicalUri': serializer.toJson<String>(canonicalUri),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'coverArtId': serializer.toJson<String?>(coverArtId),
      'status': serializer.toJson<String>(
        $DownloadsTable.$converterstatus.toJson(status),
      ),
      'progressBytes': serializer.toJson<int>(progressBytes),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'localRelativePath': serializer.toJson<String?>(localRelativePath),
      'tempRelativePath': serializer.toJson<String?>(tempRelativePath),
      'contentType': serializer.toJson<String?>(contentType),
      'etag': serializer.toJson<String?>(etag),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'retryable': serializer.toJson<bool>(retryable),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'lastValidatedAt': serializer.toJson<DateTime?>(lastValidatedAt),
    };
  }

  Download copyWith({
    String? downloadKey,
    String? providerFamily,
    String? providerId,
    String? serverId,
    String? trackId,
    String? remoteItemId,
    String? canonicalUri,
    String? title,
    String? artist,
    String? album,
    Value<String?> coverArtId = const Value.absent(),
    DownloadStatus? status,
    int? progressBytes,
    Value<int?> totalBytes = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<String?> localRelativePath = const Value.absent(),
    Value<String?> tempRelativePath = const Value.absent(),
    Value<String?> contentType = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    bool? retryable,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> lastValidatedAt = const Value.absent(),
  }) => Download(
    downloadKey: downloadKey ?? this.downloadKey,
    providerFamily: providerFamily ?? this.providerFamily,
    providerId: providerId ?? this.providerId,
    serverId: serverId ?? this.serverId,
    trackId: trackId ?? this.trackId,
    remoteItemId: remoteItemId ?? this.remoteItemId,
    canonicalUri: canonicalUri ?? this.canonicalUri,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    coverArtId: coverArtId.present ? coverArtId.value : this.coverArtId,
    status: status ?? this.status,
    progressBytes: progressBytes ?? this.progressBytes,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    localRelativePath: localRelativePath.present
        ? localRelativePath.value
        : this.localRelativePath,
    tempRelativePath: tempRelativePath.present
        ? tempRelativePath.value
        : this.tempRelativePath,
    contentType: contentType.present ? contentType.value : this.contentType,
    etag: etag.present ? etag.value : this.etag,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    retryable: retryable ?? this.retryable,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    lastValidatedAt: lastValidatedAt.present
        ? lastValidatedAt.value
        : this.lastValidatedAt,
  );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      downloadKey: data.downloadKey.present
          ? data.downloadKey.value
          : this.downloadKey,
      providerFamily: data.providerFamily.present
          ? data.providerFamily.value
          : this.providerFamily,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      remoteItemId: data.remoteItemId.present
          ? data.remoteItemId.value
          : this.remoteItemId,
      canonicalUri: data.canonicalUri.present
          ? data.canonicalUri.value
          : this.canonicalUri,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      coverArtId: data.coverArtId.present
          ? data.coverArtId.value
          : this.coverArtId,
      status: data.status.present ? data.status.value : this.status,
      progressBytes: data.progressBytes.present
          ? data.progressBytes.value
          : this.progressBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      localRelativePath: data.localRelativePath.present
          ? data.localRelativePath.value
          : this.localRelativePath,
      tempRelativePath: data.tempRelativePath.present
          ? data.tempRelativePath.value
          : this.tempRelativePath,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      etag: data.etag.present ? data.etag.value : this.etag,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      retryable: data.retryable.present ? data.retryable.value : this.retryable,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      lastValidatedAt: data.lastValidatedAt.present
          ? data.lastValidatedAt.value
          : this.lastValidatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('downloadKey: $downloadKey, ')
          ..write('providerFamily: $providerFamily, ')
          ..write('providerId: $providerId, ')
          ..write('serverId: $serverId, ')
          ..write('trackId: $trackId, ')
          ..write('remoteItemId: $remoteItemId, ')
          ..write('canonicalUri: $canonicalUri, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('status: $status, ')
          ..write('progressBytes: $progressBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('localRelativePath: $localRelativePath, ')
          ..write('tempRelativePath: $tempRelativePath, ')
          ..write('contentType: $contentType, ')
          ..write('etag: $etag, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('retryable: $retryable, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('lastValidatedAt: $lastValidatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    downloadKey,
    providerFamily,
    providerId,
    serverId,
    trackId,
    remoteItemId,
    canonicalUri,
    title,
    artist,
    album,
    coverArtId,
    status,
    progressBytes,
    totalBytes,
    sizeBytes,
    localRelativePath,
    tempRelativePath,
    contentType,
    etag,
    errorCode,
    errorMessage,
    retryable,
    createdAt,
    updatedAt,
    completedAt,
    lastValidatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.downloadKey == this.downloadKey &&
          other.providerFamily == this.providerFamily &&
          other.providerId == this.providerId &&
          other.serverId == this.serverId &&
          other.trackId == this.trackId &&
          other.remoteItemId == this.remoteItemId &&
          other.canonicalUri == this.canonicalUri &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.coverArtId == this.coverArtId &&
          other.status == this.status &&
          other.progressBytes == this.progressBytes &&
          other.totalBytes == this.totalBytes &&
          other.sizeBytes == this.sizeBytes &&
          other.localRelativePath == this.localRelativePath &&
          other.tempRelativePath == this.tempRelativePath &&
          other.contentType == this.contentType &&
          other.etag == this.etag &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.retryable == this.retryable &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.lastValidatedAt == this.lastValidatedAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> downloadKey;
  final Value<String> providerFamily;
  final Value<String> providerId;
  final Value<String> serverId;
  final Value<String> trackId;
  final Value<String> remoteItemId;
  final Value<String> canonicalUri;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<String?> coverArtId;
  final Value<DownloadStatus> status;
  final Value<int> progressBytes;
  final Value<int?> totalBytes;
  final Value<int?> sizeBytes;
  final Value<String?> localRelativePath;
  final Value<String?> tempRelativePath;
  final Value<String?> contentType;
  final Value<String?> etag;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<bool> retryable;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> lastValidatedAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.downloadKey = const Value.absent(),
    this.providerFamily = const Value.absent(),
    this.providerId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.remoteItemId = const Value.absent(),
    this.canonicalUri = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.coverArtId = const Value.absent(),
    this.status = const Value.absent(),
    this.progressBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.localRelativePath = const Value.absent(),
    this.tempRelativePath = const Value.absent(),
    this.contentType = const Value.absent(),
    this.etag = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.retryable = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.lastValidatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String downloadKey,
    required String providerFamily,
    required String providerId,
    required String serverId,
    required String trackId,
    required String remoteItemId,
    required String canonicalUri,
    required String title,
    required String artist,
    required String album,
    this.coverArtId = const Value.absent(),
    required DownloadStatus status,
    this.progressBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.localRelativePath = const Value.absent(),
    this.tempRelativePath = const Value.absent(),
    this.contentType = const Value.absent(),
    this.etag = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.retryable = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
    this.lastValidatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : downloadKey = Value(downloadKey),
       providerFamily = Value(providerFamily),
       providerId = Value(providerId),
       serverId = Value(serverId),
       trackId = Value(trackId),
       remoteItemId = Value(remoteItemId),
       canonicalUri = Value(canonicalUri),
       title = Value(title),
       artist = Value(artist),
       album = Value(album),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Download> custom({
    Expression<String>? downloadKey,
    Expression<String>? providerFamily,
    Expression<String>? providerId,
    Expression<String>? serverId,
    Expression<String>? trackId,
    Expression<String>? remoteItemId,
    Expression<String>? canonicalUri,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? coverArtId,
    Expression<String>? status,
    Expression<int>? progressBytes,
    Expression<int>? totalBytes,
    Expression<int>? sizeBytes,
    Expression<String>? localRelativePath,
    Expression<String>? tempRelativePath,
    Expression<String>? contentType,
    Expression<String>? etag,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<bool>? retryable,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? lastValidatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (downloadKey != null) 'download_key': downloadKey,
      if (providerFamily != null) 'provider_family': providerFamily,
      if (providerId != null) 'provider_id': providerId,
      if (serverId != null) 'server_id': serverId,
      if (trackId != null) 'track_id': trackId,
      if (remoteItemId != null) 'remote_item_id': remoteItemId,
      if (canonicalUri != null) 'canonical_uri': canonicalUri,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (coverArtId != null) 'cover_art_id': coverArtId,
      if (status != null) 'status': status,
      if (progressBytes != null) 'progress_bytes': progressBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (localRelativePath != null) 'local_relative_path': localRelativePath,
      if (tempRelativePath != null) 'temp_relative_path': tempRelativePath,
      if (contentType != null) 'content_type': contentType,
      if (etag != null) 'etag': etag,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (retryable != null) 'retryable': retryable,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (lastValidatedAt != null) 'last_validated_at': lastValidatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith({
    Value<String>? downloadKey,
    Value<String>? providerFamily,
    Value<String>? providerId,
    Value<String>? serverId,
    Value<String>? trackId,
    Value<String>? remoteItemId,
    Value<String>? canonicalUri,
    Value<String>? title,
    Value<String>? artist,
    Value<String>? album,
    Value<String?>? coverArtId,
    Value<DownloadStatus>? status,
    Value<int>? progressBytes,
    Value<int?>? totalBytes,
    Value<int?>? sizeBytes,
    Value<String?>? localRelativePath,
    Value<String?>? tempRelativePath,
    Value<String?>? contentType,
    Value<String?>? etag,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<bool>? retryable,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? lastValidatedAt,
    Value<int>? rowid,
  }) {
    return DownloadsCompanion(
      downloadKey: downloadKey ?? this.downloadKey,
      providerFamily: providerFamily ?? this.providerFamily,
      providerId: providerId ?? this.providerId,
      serverId: serverId ?? this.serverId,
      trackId: trackId ?? this.trackId,
      remoteItemId: remoteItemId ?? this.remoteItemId,
      canonicalUri: canonicalUri ?? this.canonicalUri,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverArtId: coverArtId ?? this.coverArtId,
      status: status ?? this.status,
      progressBytes: progressBytes ?? this.progressBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localRelativePath: localRelativePath ?? this.localRelativePath,
      tempRelativePath: tempRelativePath ?? this.tempRelativePath,
      contentType: contentType ?? this.contentType,
      etag: etag ?? this.etag,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      retryable: retryable ?? this.retryable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (downloadKey.present) {
      map['download_key'] = Variable<String>(downloadKey.value);
    }
    if (providerFamily.present) {
      map['provider_family'] = Variable<String>(providerFamily.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (remoteItemId.present) {
      map['remote_item_id'] = Variable<String>(remoteItemId.value);
    }
    if (canonicalUri.present) {
      map['canonical_uri'] = Variable<String>(canonicalUri.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (coverArtId.present) {
      map['cover_art_id'] = Variable<String>(coverArtId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $DownloadsTable.$converterstatus.toSql(status.value),
      );
    }
    if (progressBytes.present) {
      map['progress_bytes'] = Variable<int>(progressBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (localRelativePath.present) {
      map['local_relative_path'] = Variable<String>(localRelativePath.value);
    }
    if (tempRelativePath.present) {
      map['temp_relative_path'] = Variable<String>(tempRelativePath.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (retryable.present) {
      map['retryable'] = Variable<bool>(retryable.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (lastValidatedAt.present) {
      map['last_validated_at'] = Variable<DateTime>(lastValidatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('downloadKey: $downloadKey, ')
          ..write('providerFamily: $providerFamily, ')
          ..write('providerId: $providerId, ')
          ..write('serverId: $serverId, ')
          ..write('trackId: $trackId, ')
          ..write('remoteItemId: $remoteItemId, ')
          ..write('canonicalUri: $canonicalUri, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('coverArtId: $coverArtId, ')
          ..write('status: $status, ')
          ..write('progressBytes: $progressBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('localRelativePath: $localRelativePath, ')
          ..write('tempRelativePath: $tempRelativePath, ')
          ..write('contentType: $contentType, ')
          ..write('etag: $etag, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('retryable: $retryable, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('lastValidatedAt: $lastValidatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DownloadDatabase extends GeneratedDatabase {
  _$DownloadDatabase(QueryExecutor e) : super(e);
  $DownloadDatabaseManager get managers => $DownloadDatabaseManager(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [downloads];
}

typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      required String downloadKey,
      required String providerFamily,
      required String providerId,
      required String serverId,
      required String trackId,
      required String remoteItemId,
      required String canonicalUri,
      required String title,
      required String artist,
      required String album,
      Value<String?> coverArtId,
      required DownloadStatus status,
      Value<int> progressBytes,
      Value<int?> totalBytes,
      Value<int?> sizeBytes,
      Value<String?> localRelativePath,
      Value<String?> tempRelativePath,
      Value<String?> contentType,
      Value<String?> etag,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<bool> retryable,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> lastValidatedAt,
      Value<int> rowid,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<String> downloadKey,
      Value<String> providerFamily,
      Value<String> providerId,
      Value<String> serverId,
      Value<String> trackId,
      Value<String> remoteItemId,
      Value<String> canonicalUri,
      Value<String> title,
      Value<String> artist,
      Value<String> album,
      Value<String?> coverArtId,
      Value<DownloadStatus> status,
      Value<int> progressBytes,
      Value<int?> totalBytes,
      Value<int?> sizeBytes,
      Value<String?> localRelativePath,
      Value<String?> tempRelativePath,
      Value<String?> contentType,
      Value<String?> etag,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<bool> retryable,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> lastValidatedAt,
      Value<int> rowid,
    });

class $$DownloadsTableFilterComposer
    extends Composer<_$DownloadDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get downloadKey => $composableBuilder(
    column: $table.downloadKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerFamily => $composableBuilder(
    column: $table.providerFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteItemId => $composableBuilder(
    column: $table.remoteItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalUri => $composableBuilder(
    column: $table.canonicalUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadStatus, DownloadStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get progressBytes => $composableBuilder(
    column: $table.progressBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localRelativePath => $composableBuilder(
    column: $table.localRelativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tempRelativePath => $composableBuilder(
    column: $table.tempRelativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get retryable => $composableBuilder(
    column: $table.retryable,
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

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastValidatedAt => $composableBuilder(
    column: $table.lastValidatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$DownloadDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get downloadKey => $composableBuilder(
    column: $table.downloadKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerFamily => $composableBuilder(
    column: $table.providerFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteItemId => $composableBuilder(
    column: $table.remoteItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalUri => $composableBuilder(
    column: $table.canonicalUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressBytes => $composableBuilder(
    column: $table.progressBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localRelativePath => $composableBuilder(
    column: $table.localRelativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tempRelativePath => $composableBuilder(
    column: $table.tempRelativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get retryable => $composableBuilder(
    column: $table.retryable,
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

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastValidatedAt => $composableBuilder(
    column: $table.lastValidatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$DownloadDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get downloadKey => $composableBuilder(
    column: $table.downloadKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerFamily => $composableBuilder(
    column: $table.providerFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get remoteItemId => $composableBuilder(
    column: $table.remoteItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get canonicalUri => $composableBuilder(
    column: $table.canonicalUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get coverArtId => $composableBuilder(
    column: $table.coverArtId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DownloadStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progressBytes => $composableBuilder(
    column: $table.progressBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get localRelativePath => $composableBuilder(
    column: $table.localRelativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tempRelativePath => $composableBuilder(
    column: $table.tempRelativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get retryable =>
      $composableBuilder(column: $table.retryable, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastValidatedAt => $composableBuilder(
    column: $table.lastValidatedAt,
    builder: (column) => column,
  );
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$DownloadDatabase,
          $DownloadsTable,
          Download,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (
            Download,
            BaseReferences<_$DownloadDatabase, $DownloadsTable, Download>,
          ),
          Download,
          PrefetchHooks Function()
        > {
  $$DownloadsTableTableManager(_$DownloadDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> downloadKey = const Value.absent(),
                Value<String> providerFamily = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<String> remoteItemId = const Value.absent(),
                Value<String> canonicalUri = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<String?> coverArtId = const Value.absent(),
                Value<DownloadStatus> status = const Value.absent(),
                Value<int> progressBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> localRelativePath = const Value.absent(),
                Value<String?> tempRelativePath = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<bool> retryable = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> lastValidatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion(
                downloadKey: downloadKey,
                providerFamily: providerFamily,
                providerId: providerId,
                serverId: serverId,
                trackId: trackId,
                remoteItemId: remoteItemId,
                canonicalUri: canonicalUri,
                title: title,
                artist: artist,
                album: album,
                coverArtId: coverArtId,
                status: status,
                progressBytes: progressBytes,
                totalBytes: totalBytes,
                sizeBytes: sizeBytes,
                localRelativePath: localRelativePath,
                tempRelativePath: tempRelativePath,
                contentType: contentType,
                etag: etag,
                errorCode: errorCode,
                errorMessage: errorMessage,
                retryable: retryable,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                lastValidatedAt: lastValidatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String downloadKey,
                required String providerFamily,
                required String providerId,
                required String serverId,
                required String trackId,
                required String remoteItemId,
                required String canonicalUri,
                required String title,
                required String artist,
                required String album,
                Value<String?> coverArtId = const Value.absent(),
                required DownloadStatus status,
                Value<int> progressBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> localRelativePath = const Value.absent(),
                Value<String?> tempRelativePath = const Value.absent(),
                Value<String?> contentType = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<bool> retryable = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> lastValidatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion.insert(
                downloadKey: downloadKey,
                providerFamily: providerFamily,
                providerId: providerId,
                serverId: serverId,
                trackId: trackId,
                remoteItemId: remoteItemId,
                canonicalUri: canonicalUri,
                title: title,
                artist: artist,
                album: album,
                coverArtId: coverArtId,
                status: status,
                progressBytes: progressBytes,
                totalBytes: totalBytes,
                sizeBytes: sizeBytes,
                localRelativePath: localRelativePath,
                tempRelativePath: tempRelativePath,
                contentType: contentType,
                etag: etag,
                errorCode: errorCode,
                errorMessage: errorMessage,
                retryable: retryable,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                lastValidatedAt: lastValidatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$DownloadDatabase,
      $DownloadsTable,
      Download,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (Download, BaseReferences<_$DownloadDatabase, $DownloadsTable, Download>),
      Download,
      PrefetchHooks Function()
    >;

class $DownloadDatabaseManager {
  final _$DownloadDatabase _db;
  $DownloadDatabaseManager(this._db);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
}
