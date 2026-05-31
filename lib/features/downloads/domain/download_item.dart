enum DownloadStatus { queued, downloading, completed, failed, removing }

class DownloadIdentity {
  const DownloadIdentity({
    required this.providerFamily,
    required this.providerId,
    required this.serverId,
    required this.trackId,
    required this.remoteItemId,
    required this.canonicalUri,
  });

  final String providerFamily;
  final String providerId;
  final String serverId;
  final String trackId;
  final String remoteItemId;
  final String canonicalUri;

  String get downloadKey => '$providerId::$trackId';
  String get safeServerSegment =>
      _safePathSegment(serverId, fallback: 'server');
  String get safeTrackSegment => _safePathSegment(trackId, fallback: 'track');
}

class DownloadItem {
  const DownloadItem({
    required this.identity,
    required this.title,
    required this.artist,
    required this.album,
    required this.status,
    required this.progressBytes,
    required this.createdAt,
    required this.updatedAt,
    this.coverArtId,
    this.totalBytes,
    this.sizeBytes,
    this.localRelativePath,
    this.tempRelativePath,
    this.contentType,
    this.etag,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
    this.completedAt,
    this.lastValidatedAt,
  });

  factory DownloadItem.createQueued({
    required DownloadIdentity identity,
    required String title,
    required String artist,
    required String album,
    required DateTime now,
    String? coverArtId,
  }) {
    return DownloadItem(
      identity: identity,
      title: title,
      artist: artist,
      album: album,
      coverArtId: coverArtId,
      status: DownloadStatus.queued,
      progressBytes: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  final DownloadIdentity identity;
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

  String get downloadKey => identity.downloadKey;
  String get providerFamily => identity.providerFamily;
  String get providerId => identity.providerId;
  String get serverId => identity.serverId;
  String get trackId => identity.trackId;
  String get remoteItemId => identity.remoteItemId;
  String get canonicalUri => identity.canonicalUri;

  DownloadItem copyWith({
    DownloadIdentity? identity,
    String? title,
    String? artist,
    String? album,
    Object? coverArtId = _sentinel,
    DownloadStatus? status,
    int? progressBytes,
    Object? totalBytes = _sentinel,
    Object? sizeBytes = _sentinel,
    Object? localRelativePath = _sentinel,
    Object? tempRelativePath = _sentinel,
    Object? contentType = _sentinel,
    Object? etag = _sentinel,
    Object? errorCode = _sentinel,
    Object? errorMessage = _sentinel,
    bool? retryable,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _sentinel,
    Object? lastValidatedAt = _sentinel,
  }) {
    return DownloadItem(
      identity: identity ?? this.identity,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverArtId: identical(coverArtId, _sentinel)
          ? this.coverArtId
          : coverArtId as String?,
      status: status ?? this.status,
      progressBytes: progressBytes ?? this.progressBytes,
      totalBytes: identical(totalBytes, _sentinel)
          ? this.totalBytes
          : totalBytes as int?,
      sizeBytes: identical(sizeBytes, _sentinel)
          ? this.sizeBytes
          : sizeBytes as int?,
      localRelativePath: identical(localRelativePath, _sentinel)
          ? this.localRelativePath
          : localRelativePath as String?,
      tempRelativePath: identical(tempRelativePath, _sentinel)
          ? this.tempRelativePath
          : tempRelativePath as String?,
      contentType: identical(contentType, _sentinel)
          ? this.contentType
          : contentType as String?,
      etag: identical(etag, _sentinel) ? this.etag : etag as String?,
      errorCode: identical(errorCode, _sentinel)
          ? this.errorCode
          : errorCode as String?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      retryable: retryable ?? this.retryable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _sentinel)
          ? this.completedAt
          : completedAt as DateTime?,
      lastValidatedAt: identical(lastValidatedAt, _sentinel)
          ? this.lastValidatedAt
          : lastValidatedAt as DateTime?,
    );
  }
}

const Object _sentinel = Object();

String _safePathSegment(String value, {required String fallback}) {
  final safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return safe.isEmpty ? fallback : safe;
}
