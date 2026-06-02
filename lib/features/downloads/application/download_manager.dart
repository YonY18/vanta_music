import '../domain/download_item.dart';
import '../infrastructure/download_database.dart';
import '../infrastructure/file_download_storage.dart';

class DownloadRequest {
  const DownloadRequest({
    required this.identity,
    required this.title,
    required this.artist,
    required this.album,
    this.coverArtId,
    this.fileExtension,
  });

  final DownloadIdentity identity;
  final String title;
  final String artist;
  final String album;
  final String? coverArtId;
  final String? fileExtension;
}

abstract class DownloadSourceAdapter {
  bool canHandle(String providerFamily);
  Stream<List<int>> open(DownloadRequest request);
}

class DownloadTransferException implements Exception {
  const DownloadTransferException({
    required this.code,
    required this.message,
    required this.retryable,
  });

  final String code;
  final String message;
  final bool retryable;
}

class DownloadManager {
  DownloadManager({
    required this.database,
    required this.storage,
    required this.adapters,
    this.maxConcurrent = 2,
  });

  final DownloadDatabase database;
  final FileDownloadStorage storage;
  final List<DownloadSourceAdapter> adapters;
  final int maxConcurrent;
  final Set<String> _pendingKeys = <String>{};
  final Set<String> _cancelledKeys = <String>{};

  Set<String> get pendingKeys => Set<String>.unmodifiable(_pendingKeys);

  Future<DownloadItem> enqueue(DownloadRequest request) async {
    final now = DateTime.now().toUtc();
    final paths = await storage.resolvePaths(
      request.identity,
      fileExtension: request.fileExtension,
    );
    final queued =
        DownloadItem.createQueued(
          identity: request.identity,
          title: request.title,
          artist: request.artist,
          album: request.album,
          coverArtId: request.coverArtId,
          now: now,
        ).copyWith(
          localRelativePath: paths.finalRelativePath,
          tempRelativePath: paths.tempRelativePath,
        );
    final item = await database.enqueue(queued);
    if (item.status == DownloadStatus.queued) {
      _pendingKeys.add(item.downloadKey);
    }
    return item;
  }

  Future<List<DownloadItem>> listDownloads() => database.getAllDownloads();

  Future<DownloadItem?> getDownload(String key) => database.getDownload(key);

  Future<void> recoverInterruptedDownloads() async {
    final interrupted = await database.findByStatus(DownloadStatus.downloading);
    for (final item in interrupted) {
      await storage.deleteArtifacts(tempRelativePath: item.tempRelativePath);
    }
    await database.recoverInterruptedDownloads();
    await _refreshPendingKeys();
  }

  Future<void> processQueue() async {
    final queued = await database.findByStatus(DownloadStatus.queued);
    for (final item in queued) {
      await _processItem(item);
    }
    await _refreshPendingKeys();
  }

  Future<void> cancel(String key) async {
    final item = await database.getDownload(key);
    if (item == null) return;
    _cancelledKeys.add(key);
    await storage.deleteArtifacts(tempRelativePath: item.tempRelativePath);
    await database.putDownload(
      item.copyWith(
        status: DownloadStatus.failed,
        retryable: true,
        errorCode: 'cancelled',
        errorMessage: 'Download cancelled by user.',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    _pendingKeys.remove(key);
  }

  Future<void> retry(String key) async {
    final item = await database.getDownload(key);
    if (item == null) return;
    _cancelledKeys.remove(key);
    final queued = item.copyWith(
      status: DownloadStatus.queued,
      progressBytes: 0,
      totalBytes: null,
      sizeBytes: null,
      errorCode: null,
      errorMessage: null,
      retryable: false,
      completedAt: null,
      updatedAt: DateTime.now().toUtc(),
    );
    await database.putDownload(queued);
    _pendingKeys.add(key);
  }

  Future<void> delete(String key) async {
    final item = await database.getDownload(key);
    if (item == null) return;
    await database.putDownload(
      item.copyWith(
        status: DownloadStatus.removing,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await storage.deleteArtifacts(
      finalRelativePath: item.localRelativePath,
      tempRelativePath: item.tempRelativePath,
    );
    await database.deleteDownload(key);
    _pendingKeys.remove(key);
  }

  Future<void> _processItem(DownloadItem item) async {
    final adapter = adapters
        .where((candidate) => candidate.canHandle(item.providerFamily))
        .firstOrNull;
    if (adapter == null) {
      await database.putDownload(
        item.copyWith(
          status: DownloadStatus.failed,
          retryable: false,
          errorCode: 'unsupported-provider',
          errorMessage: 'No download adapter registered for this provider.',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      _pendingKeys.remove(item.downloadKey);
      return;
    }

    final request = DownloadRequest(
      identity: item.identity,
      title: item.title,
      artist: item.artist,
      album: item.album,
      coverArtId: item.coverArtId,
      fileExtension: item.localRelativePath?.split('.').last,
    );
    final paths = await storage.resolvePaths(
      item.identity,
      fileExtension: request.fileExtension ?? 'bin',
    );
    var progress = 0;
    final started = item.copyWith(
      status: DownloadStatus.downloading,
      localRelativePath: paths.finalRelativePath,
      tempRelativePath: paths.tempRelativePath,
      updatedAt: DateTime.now().toUtc(),
    );
    await database.putDownload(started);

    try {
      await storage.deleteArtifacts(tempRelativePath: paths.tempRelativePath);
      await for (final chunk in adapter.open(request)) {
        _throwIfCancelled(item.downloadKey);
        progress += chunk.length;
        await storage.writeTempChunk(paths.tempRelativePath, chunk);
        _throwIfCancelled(item.downloadKey);
        await database.putDownload(
          started.copyWith(
            progressBytes: progress,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }
      _throwIfCancelled(item.downloadKey);
      final file = await storage.promoteCompletedFile(
        tempRelativePath: paths.tempRelativePath,
        finalRelativePath: paths.finalRelativePath,
      );
      await database.putDownload(
        started.copyWith(
          status: DownloadStatus.completed,
          progressBytes: progress,
          totalBytes: progress,
          sizeBytes: await file.length(),
          retryable: false,
          errorCode: null,
          errorMessage: null,
          completedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } on _DownloadCancelledException {
      await storage.deleteArtifacts(tempRelativePath: paths.tempRelativePath);
      await database.putDownload(
        started.copyWith(
          status: DownloadStatus.failed,
          retryable: true,
          errorCode: 'cancelled',
          errorMessage: 'Download cancelled by user.',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } on DownloadTransferException catch (error) {
      await storage.deleteArtifacts(tempRelativePath: paths.tempRelativePath);
      await database.putDownload(
        started.copyWith(
          status: DownloadStatus.failed,
          retryable: error.retryable,
          errorCode: error.code,
          errorMessage: error.message,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {
      await storage.deleteArtifacts(tempRelativePath: paths.tempRelativePath);
      await database.putDownload(
        started.copyWith(
          status: DownloadStatus.failed,
          retryable: false,
          errorCode: 'unexpected',
          errorMessage: 'Unexpected download failure.',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } finally {
      _pendingKeys.remove(item.downloadKey);
      _cancelledKeys.remove(item.downloadKey);
    }
  }

  void _throwIfCancelled(String key) {
    if (_cancelledKeys.contains(key)) throw const _DownloadCancelledException();
  }

  Future<void> _refreshPendingKeys() async {
    _pendingKeys
      ..clear()
      ..addAll(
        (await database.findByStatus(
          DownloadStatus.queued,
        )).map((item) => item.downloadKey),
      );
  }
}

class _DownloadCancelledException implements Exception {
  const _DownloadCancelledException();
}
