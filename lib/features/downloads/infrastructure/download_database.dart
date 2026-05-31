import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../domain/download_item.dart';

part 'download_database.g.dart';

class Downloads extends Table {
  TextColumn get downloadKey => text()();
  TextColumn get providerFamily => text()();
  TextColumn get providerId => text()();
  TextColumn get serverId => text()();
  TextColumn get trackId => text()();
  TextColumn get remoteItemId => text()();
  TextColumn get canonicalUri => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  TextColumn get coverArtId => text().nullable()();
  TextColumn get status => textEnum<DownloadStatus>()();
  IntColumn get progressBytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get localRelativePath => text().nullable()();
  TextColumn get tempRelativePath => text().nullable()();
  TextColumn get contentType => text().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  BoolColumn get retryable => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get lastValidatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {downloadKey};
}

@DriftDatabase(tables: [Downloads])
class DownloadDatabase extends _$DownloadDatabase {
  DownloadDatabase._(super.executor);

  static final Map<String, DownloadDatabase> _sharedFileDatabases = {};

  factory DownloadDatabase.inMemory() =>
      DownloadDatabase._(NativeDatabase.memory());

  factory DownloadDatabase.file(File file) {
    file.parent.createSync(recursive: true);
    return DownloadDatabase._(NativeDatabase(file));
  }

  factory DownloadDatabase.sharedFile(File file) {
    file.parent.createSync(recursive: true);
    final key = file.absolute.path;
    return _sharedFileDatabases.putIfAbsent(
      key,
      () => DownloadDatabase._(NativeDatabase(file)),
    );
  }

  @override
  int get schemaVersion => 1;

  Future<DownloadItem> enqueue(DownloadItem item) async {
    final existing = await getDownload(item.downloadKey);
    if (existing != null &&
        existing.status != DownloadStatus.failed &&
        existing.status != DownloadStatus.removing) {
      return existing;
    }
    final queued = existing == null
        ? item
        : item.copyWith(
            createdAt: existing.createdAt,
            updatedAt: item.updatedAt,
          );
    await putDownload(queued);
    return queued;
  }

  Future<void> putDownload(DownloadItem item) {
    return into(downloads).insertOnConflictUpdate(_companion(item));
  }

  Future<DownloadItem?> getDownload(String key) async {
    final row = await (select(
      downloads,
    )..where((tbl) => tbl.downloadKey.equals(key))).getSingleOrNull();
    return row == null ? null : _itemFromRow(row);
  }

  Future<List<DownloadItem>> getAllDownloads() async {
    final rows = await (select(
      downloads,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)])).get();
    return rows.map(_itemFromRow).toList(growable: false);
  }

  Stream<List<DownloadItem>> watchAllDownloads() {
    return (select(downloads)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .watch()
        .map((rows) => rows.map(_itemFromRow).toList(growable: false));
  }

  Stream<DownloadItem?> watchDownload(String key) {
    return (select(downloads)..where((tbl) => tbl.downloadKey.equals(key)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _itemFromRow(row));
  }

  Future<List<DownloadItem>> findByStatus(DownloadStatus statusValue) async {
    final rows =
        await (select(downloads)
              ..where((tbl) => tbl.status.equals(statusValue.name))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
            .get();
    return rows.map(_itemFromRow).toList(growable: false);
  }

  Future<List<DownloadItem>> findByServer(
    String serverId, {
    String? providerFamily,
  }) async {
    final rows =
        await (select(downloads)
              ..where((tbl) => tbl.serverId.equals(serverId))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
            .get();
    return rows
        .map(_itemFromRow)
        .where(
          (item) =>
              providerFamily == null || item.providerFamily == providerFamily,
        )
        .toList(growable: false);
  }

  Future<void> recoverInterruptedDownloads({DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    await (update(downloads)
          ..where((tbl) => tbl.status.equals(DownloadStatus.downloading.name)))
        .write(
          DownloadsCompanion(
            status: const Value(DownloadStatus.failed),
            retryable: const Value(true),
            errorCode: const Value('interrupted'),
            errorMessage: const Value(
              'Download interrupted before completion.',
            ),
            updatedAt: Value(timestamp),
          ),
        );
  }

  Future<void> deleteDownload(String key) {
    return (delete(
      downloads,
    )..where((tbl) => tbl.downloadKey.equals(key))).go();
  }

  DownloadsCompanion _companion(DownloadItem item) {
    return DownloadsCompanion.insert(
      downloadKey: item.downloadKey,
      providerFamily: item.providerFamily,
      providerId: item.providerId,
      serverId: item.serverId,
      trackId: item.trackId,
      remoteItemId: item.remoteItemId,
      canonicalUri: item.canonicalUri,
      title: item.title,
      artist: item.artist,
      album: item.album,
      coverArtId: Value(item.coverArtId),
      status: item.status,
      progressBytes: Value(item.progressBytes),
      totalBytes: Value(item.totalBytes),
      sizeBytes: Value(item.sizeBytes),
      localRelativePath: Value(item.localRelativePath),
      tempRelativePath: Value(item.tempRelativePath),
      contentType: Value(item.contentType),
      etag: Value(item.etag),
      errorCode: Value(item.errorCode),
      errorMessage: Value(item.errorMessage),
      retryable: Value(item.retryable),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      completedAt: Value(item.completedAt),
      lastValidatedAt: Value(item.lastValidatedAt),
    );
  }

  DownloadItem _itemFromRow(Download row) {
    return DownloadItem(
      identity: DownloadIdentity(
        providerFamily: row.providerFamily,
        providerId: row.providerId,
        serverId: row.serverId,
        trackId: row.trackId,
        remoteItemId: row.remoteItemId,
        canonicalUri: row.canonicalUri,
      ),
      title: row.title,
      artist: row.artist,
      album: row.album,
      coverArtId: row.coverArtId,
      status: row.status,
      progressBytes: row.progressBytes,
      totalBytes: row.totalBytes,
      sizeBytes: row.sizeBytes,
      localRelativePath: row.localRelativePath,
      tempRelativePath: row.tempRelativePath,
      contentType: row.contentType,
      etag: row.etag,
      errorCode: row.errorCode,
      errorMessage: row.errorMessage,
      retryable: row.retryable,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      completedAt: row.completedAt?.toUtc(),
      lastValidatedAt: row.lastValidatedAt?.toUtc(),
    );
  }
}
