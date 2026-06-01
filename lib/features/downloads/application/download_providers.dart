import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../library/domain/track.dart';
import '../../player/application/player_controller.dart';
import '../../player/infrastructure/vanta_audio_handler.dart';
import '../../providers/application/subsonic_providers.dart';
import 'download_manager.dart';
import '../domain/download_item.dart';
import '../infrastructure/download_database.dart';
import '../infrastructure/file_download_storage.dart';
import '../infrastructure/subsonic_download_adapter.dart';

class DownloadProgressSnapshot {
  const DownloadProgressSnapshot({
    required this.status,
    required this.progressBytes,
    required this.totalBytes,
  });

  final DownloadStatus? status;
  final int progressBytes;
  final int? totalBytes;

  double? get progressFraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return progressBytes / total;
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadProgressSnapshot &&
        other.status == status &&
        other.progressBytes == progressBytes &&
        other.totalBytes == totalBytes;
  }

  @override
  int get hashCode => Object.hash(status, progressBytes, totalBytes);
}

class DownloadStorageSummary {
  const DownloadStorageSummary({
    required this.completedCount,
    required this.totalBytes,
  });

  final int completedCount;
  final int totalBytes;

  @override
  bool operator ==(Object other) {
    return other is DownloadStorageSummary &&
        other.completedCount == completedCount &&
        other.totalBytes == totalBytes;
  }

  @override
  int get hashCode => Object.hash(completedCount, totalBytes);
}

enum DownloadTrackAction { download, cancel, retry, delete }

class DownloadTrackActions {
  const DownloadTrackActions({
    required this.request,
    required this.download,
    required this.availableActions,
  });

  final DownloadRequest? request;
  final DownloadItem? download;
  final List<DownloadTrackAction> availableActions;

  bool get isVisible => request != null;
}

class GroupedDownloads {
  const GroupedDownloads({
    required this.active,
    required this.completed,
    required this.failed,
  });

  final List<DownloadItem> active;
  final List<DownloadItem> completed;
  final List<DownloadItem> failed;
}

class DownloadsSummary {
  const DownloadsSummary({
    required this.totalCount,
    required this.activeCount,
    required this.completedCount,
    required this.failedCount,
  });

  final int totalCount;
  final int activeCount;
  final int completedCount;
  final int failedCount;
}

class DeleteDownloadGuard {
  const DeleteDownloadGuard({required this.isBlocked, this.reason});

  final bool isBlocked;
  final String? reason;
}

final downloadDatabaseProvider = FutureProvider<DownloadDatabase>((ref) async {
  final directory = await getApplicationSupportDirectory();
  return DownloadDatabase.sharedFile(
    File('${directory.path}/downloads.sqlite'),
  );
});

final downloadStorageProvider = FutureProvider<FileDownloadStorage>((
  ref,
) async {
  final directory = await getApplicationSupportDirectory();
  return FileDownloadStorage(appSupportDirectory: () async => directory);
});

final downloadManagerProvider = FutureProvider<DownloadManager>((ref) async {
  final database = await ref.watch(downloadDatabaseProvider.future);
  final storage = await ref.watch(downloadStorageProvider.future);
  final store = await ref.watch(subsonicServerStoreProvider.future);
  final clientFactory = ref.watch(subsonicApiClientFactoryProvider);
  return DownloadManager(
    database: database,
    storage: storage,
    adapters: [
      SubsonicDownloadAdapter(store: store, clientFactory: clientFactory),
    ],
  );
});

final downloadBootstrapProvider = FutureProvider<void>((ref) async {
  final manager = await ref.watch(downloadManagerProvider.future);
  await manager.recoverInterruptedDownloads();
  await manager.processQueue();
});

final downloadControllerProvider = Provider<DownloadController>((ref) {
  return DownloadController(ref);
});

final allDownloadsProvider = StreamProvider<List<DownloadItem>>((ref) async* {
  final database = await ref.watch(downloadDatabaseProvider.future);
  yield* database.watchAllDownloads();
});

final downloadItemProvider = StreamProvider.family<DownloadItem?, String>((
  ref,
  downloadKey,
) async* {
  final database = await ref.watch(downloadDatabaseProvider.future);
  yield* database.watchDownload(downloadKey);
});

final downloadStatusProvider = StreamProvider.family<DownloadStatus?, String>((
  ref,
  downloadKey,
) async* {
  final database = await ref.watch(downloadDatabaseProvider.future);
  yield* database
      .watchDownload(downloadKey)
      .map((item) => item?.status)
      .distinct();
});

final downloadProgressProvider =
    StreamProvider.family<DownloadProgressSnapshot?, String>((
      ref,
      downloadKey,
    ) async* {
      final database = await ref.watch(downloadDatabaseProvider.future);
      yield* database.watchDownload(downloadKey).map((item) {
        if (item == null) return null;
        return DownloadProgressSnapshot(
          status: item.status,
          progressBytes: item.progressBytes,
          totalBytes: item.totalBytes,
        );
      }).distinct();
    });

final downloadStorageSummaryProvider = StreamProvider<DownloadStorageSummary>((
  ref,
) async* {
  final database = await ref.watch(downloadDatabaseProvider.future);
  yield* database.watchAllDownloads().map(_buildStorageSummary).distinct();
});

final groupedDownloadsProvider = Provider<AsyncValue<GroupedDownloads>>((ref) {
  return ref.watch(allDownloadsProvider).whenData(_groupDownloads);
});

final failedDownloadsProvider = Provider<AsyncValue<List<DownloadItem>>>((ref) {
  return ref
      .watch(allDownloadsProvider)
      .whenData((downloads) => _groupDownloads(downloads).failed);
});

final failedDownloadsCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(failedDownloadsProvider)
      .whenData((downloads) => downloads.length);
});

final downloadsSummaryProvider = Provider<AsyncValue<DownloadsSummary>>((ref) {
  return ref.watch(allDownloadsProvider).whenData(_buildDownloadsSummary);
});

final currentPlaybackDownloadKeyProvider = Provider<String?>((ref) {
  final item = ref.watch(mediaItemProvider).valueOrNull;
  if (item == null) return null;
  return VantaAudioHandler.normalizeTrackKey(item);
});

final deleteDownloadGuardProvider =
    Provider.family<DeleteDownloadGuard, String>((ref, downloadKey) {
      final currentKey = ref.watch(currentPlaybackDownloadKeyProvider);
      if (currentKey == downloadKey) {
        return const DeleteDownloadGuard(
          isBlocked: true,
          reason: 'Stop playback first before deleting this download.',
        );
      }
      return const DeleteDownloadGuard(isBlocked: false);
    });

DownloadRequest? downloadRequestFromRemoteTrack(Track track) {
  final providerId = track.providerId.trim();
  if (!providerId.startsWith('subsonic:')) return null;
  if (track.id.trim().isEmpty) return null;
  if (track.uri.scheme != 'subsonic') return null;

  final serverId = track.uri.queryParameters['serverId']?.trim();
  final rawTrackId = track.uri.queryParameters['id']?.trim();
  if (serverId == null || serverId.isEmpty) return null;
  if (rawTrackId == null || rawTrackId.isEmpty) return null;

  return DownloadRequest(
    identity: DownloadIdentity(
      providerFamily: 'subsonic',
      providerId: providerId,
      serverId: serverId,
      trackId: rawTrackId,
      remoteItemId: track.id,
      canonicalUri: track.uri.toString(),
    ),
    title: track.title,
    artist: track.artist,
    album: track.album,
    coverArtId: track.uri.queryParameters['coverArtId'],
  );
}

DownloadTrackActions downloadActionsForTrack({
  required Track track,
  required DownloadItem? download,
}) {
  final request = downloadRequestFromRemoteTrack(track);
  if (request == null) {
    return const DownloadTrackActions(
      request: null,
      download: null,
      availableActions: <DownloadTrackAction>[],
    );
  }

  if (download == null) {
    return DownloadTrackActions(
      request: request,
      download: null,
      availableActions: const [DownloadTrackAction.download],
    );
  }

  return DownloadTrackActions(
    request: request,
    download: download,
    availableActions: _actionsForDownload(download),
  );
}

class DownloadController {
  const DownloadController(this._ref);

  final Ref _ref;

  Future<DownloadItem?> enqueueTrack(Track track) async {
    final request = downloadRequestFromRemoteTrack(track);
    if (request == null) return null;
    return enqueue(request);
  }

  Future<DownloadItem> enqueue(DownloadRequest request) async {
    final manager = await _ref.read(downloadManagerProvider.future);
    final item = await manager.enqueue(request);
    await manager.processQueue();
    return item;
  }

  Future<void> cancel(String downloadKey) async {
    final manager = await _ref.read(downloadManagerProvider.future);
    await manager.cancel(downloadKey);
  }

  Future<void> retry(String downloadKey) async {
    final manager = await _ref.read(downloadManagerProvider.future);
    await manager.retry(downloadKey);
    await manager.processQueue();
  }

  Future<void> delete(String downloadKey) async {
    final manager = await _ref.read(downloadManagerProvider.future);
    await manager.delete(downloadKey);
  }

  Future<int> clearFailed() async {
    final database = await _ref.read(downloadDatabaseProvider.future);
    final manager = await _ref.read(downloadManagerProvider.future);
    final failed = await database.findByStatus(DownloadStatus.failed);
    for (final item in failed) {
      await manager.delete(item.downloadKey);
    }
    return failed.length;
  }

  DeleteDownloadGuard deleteGuard(String downloadKey) {
    return _ref.read(deleteDownloadGuardProvider(downloadKey));
  }
}

DownloadStorageSummary _buildStorageSummary(List<DownloadItem> downloads) {
  var completedCount = 0;
  var totalBytes = 0;
  for (final item in downloads) {
    if (item.status != DownloadStatus.completed) continue;
    completedCount += 1;
    totalBytes += item.sizeBytes ?? 0;
  }
  return DownloadStorageSummary(
    completedCount: completedCount,
    totalBytes: totalBytes,
  );
}

GroupedDownloads _groupDownloads(List<DownloadItem> downloads) {
  final active = <DownloadItem>[];
  final completed = <DownloadItem>[];
  final failed = <DownloadItem>[];

  for (final item in downloads) {
    switch (item.status) {
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        active.add(item);
      case DownloadStatus.completed:
        completed.add(item);
      case DownloadStatus.failed:
      case DownloadStatus.removing:
        failed.add(item);
    }
  }

  int compareByUpdatedAt(DownloadItem left, DownloadItem right) {
    final updatedAt = right.updatedAt.compareTo(left.updatedAt);
    if (updatedAt != 0) return updatedAt;
    return right.createdAt.compareTo(left.createdAt);
  }

  active.sort((left, right) {
    final rank = _activeRank(left.status).compareTo(_activeRank(right.status));
    if (rank != 0) return rank;
    return compareByUpdatedAt(left, right);
  });
  completed.sort(compareByUpdatedAt);
  failed.sort(compareByUpdatedAt);

  return GroupedDownloads(
    active: List<DownloadItem>.unmodifiable(active),
    completed: List<DownloadItem>.unmodifiable(completed),
    failed: List<DownloadItem>.unmodifiable(failed),
  );
}

DownloadsSummary _buildDownloadsSummary(List<DownloadItem> downloads) {
  final grouped = _groupDownloads(downloads);
  return DownloadsSummary(
    totalCount: downloads.length,
    activeCount: grouped.active.length,
    completedCount: grouped.completed.length,
    failedCount: grouped.failed.length,
  );
}

List<DownloadTrackAction> _actionsForDownload(DownloadItem download) {
  switch (download.status) {
    case DownloadStatus.queued:
    case DownloadStatus.downloading:
      return const [DownloadTrackAction.cancel];
    case DownloadStatus.completed:
      return const [DownloadTrackAction.delete];
    case DownloadStatus.failed:
      return download.retryable
          ? const [DownloadTrackAction.retry, DownloadTrackAction.delete]
          : const [DownloadTrackAction.delete];
    case DownloadStatus.removing:
      return const <DownloadTrackAction>[];
  }
}

int _activeRank(DownloadStatus status) {
  switch (status) {
    case DownloadStatus.downloading:
      return 0;
    case DownloadStatus.queued:
      return 1;
    case DownloadStatus.completed:
      return 2;
    case DownloadStatus.failed:
      return 3;
    case DownloadStatus.removing:
      return 4;
  }
}
