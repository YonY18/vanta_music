import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/application/download_providers.dart';
import 'package:vanta_music/features/downloads/application/download_manager.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/download_database.dart';
import 'package:vanta_music/features/downloads/infrastructure/file_download_storage.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/player/application/player_controller.dart';

void main() {
  late Directory tempDir;
  late DownloadDatabase database;
  late FileDownloadStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download-providers-test');
    database = DownloadDatabase.inMemory();
    storage = FileDownloadStorage(appSupportDirectory: () async => tempDir);
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('maps a valid remote Subsonic track into a download request', () {
    final track = _remoteTrack('song-1', coverArtId: 'cover-1');

    final request = downloadRequestFromRemoteTrack(track);

    expect(request, isNotNull);
    expect(request!.identity.providerFamily, 'subsonic');
    expect(request.identity.providerId, 'subsonic:server-a');
    expect(request.identity.serverId, 'server-a');
    expect(request.identity.trackId, 'song-1');
    expect(request.identity.remoteItemId, 'subsonic:server-a:song-1');
    expect(request.identity.canonicalUri, track.uri.toString());
    expect(request.title, 'Track song-1');
    expect(request.artist, 'Artist');
    expect(request.album, 'Album');
    expect(request.coverArtId, 'cover-1');
  });

  test('returns null for malformed or non-remote tracks', () {
    final invalidTracks = [
      Track(
        id: 'local-1',
        providerId: 'local',
        title: 'Local track',
        artist: 'Artist',
        album: 'Album',
        uri: Uri.file('/music/local-1.mp3'),
      ),
      Track(
        id: 'subsonic:server-a:song-2',
        providerId: 'subsonic:server-a',
        title: 'Missing server',
        artist: 'Artist',
        album: 'Album',
        uri: Uri.parse('subsonic://track?id=song-2'),
      ),
      Track(
        id: '',
        providerId: 'subsonic:server-a',
        title: 'Missing remote id',
        artist: 'Artist',
        album: 'Album',
        uri: Uri.parse('subsonic://track?serverId=server-a&id=song-3'),
      ),
    ];

    for (final track in invalidTracks) {
      expect(downloadRequestFromRemoteTrack(track), isNull);
      final actions = downloadActionsForTrack(track: track, download: null);
      expect(actions.isVisible, isFalse);
      expect(actions.availableActions, isEmpty);
    }
  });

  test('maps action availability to persisted download state', () {
    final remoteTrack = _remoteTrack('song-state');

    final notDownloaded = downloadActionsForTrack(
      track: remoteTrack,
      download: null,
    );
    final downloading = downloadActionsForTrack(
      track: remoteTrack,
      download: _queuedDownload(
        trackId: 'song-state',
      ).copyWith(status: DownloadStatus.downloading),
    );
    final failedRetryable = downloadActionsForTrack(
      track: remoteTrack,
      download: _queuedDownload(
        trackId: 'song-state',
      ).copyWith(status: DownloadStatus.failed, retryable: true),
    );
    final completed = downloadActionsForTrack(
      track: remoteTrack,
      download: _queuedDownload(
        trackId: 'song-state',
      ).copyWith(status: DownloadStatus.completed),
    );

    expect(notDownloaded.availableActions, [DownloadTrackAction.download]);
    expect(downloading.availableActions, [DownloadTrackAction.cancel]);
    expect(failedRetryable.availableActions, [
      DownloadTrackAction.retry,
      DownloadTrackAction.delete,
    ]);
    expect(completed.availableActions, [DownloadTrackAction.delete]);
  });

  test(
    'download status provider only updates the requested download key',
    () async {
      final songA = _queuedDownload(trackId: 'song-a');
      final songB = _queuedDownload(trackId: 'song-b');
      await database.putDownload(songA);
      await database.putDownload(songB);

      final container = ProviderContainer(
        overrides: [
          downloadDatabaseProvider.overrideWith((ref) async => database),
          downloadStorageProvider.overrideWith((ref) async => storage),
        ],
      );
      addTearDown(container.dispose);

      final events = <AsyncValue<DownloadStatus?>>[];
      final subscription = container.listen<AsyncValue<DownloadStatus?>>(
        downloadStatusProvider(songA.downloadKey),
        (previous, next) => events.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(
        await container.read(downloadStatusProvider(songA.downloadKey).future),
        DownloadStatus.queued,
      );
      await pumpEventQueue();
      events.clear();

      await database.putDownload(
        songB.copyWith(
          status: DownloadStatus.completed,
          progressBytes: 256,
          totalBytes: 256,
          sizeBytes: 256,
          updatedAt: songB.updatedAt.add(const Duration(minutes: 1)),
        ),
      );
      await pumpEventQueue();

      expect(events, isEmpty);

      await database.putDownload(
        songA.copyWith(
          status: DownloadStatus.completed,
          progressBytes: 512,
          totalBytes: 512,
          sizeBytes: 512,
          updatedAt: songA.updatedAt.add(const Duration(minutes: 1)),
        ),
      );
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single.value, DownloadStatus.completed);
    },
  );

  test(
    'download progress and storage summary reflect persisted manifest state',
    () async {
      final downloading = _queuedDownload(trackId: 'song-progress').copyWith(
        status: DownloadStatus.downloading,
        progressBytes: 128,
        totalBytes: 256,
      );
      final completed = _queuedDownload(trackId: 'song-complete').copyWith(
        status: DownloadStatus.completed,
        progressBytes: 300,
        totalBytes: 300,
        sizeBytes: 300,
      );
      final failed = _queuedDownload(trackId: 'song-failed').copyWith(
        status: DownloadStatus.failed,
        progressBytes: 64,
        totalBytes: 128,
        sizeBytes: 128,
      );
      await database.putDownload(downloading);
      await database.putDownload(completed);
      await database.putDownload(failed);

      final container = ProviderContainer(
        overrides: [
          downloadDatabaseProvider.overrideWith((ref) async => database),
          downloadStorageProvider.overrideWith((ref) async => storage),
        ],
      );
      addTearDown(container.dispose);

      final progress = await container.read(
        downloadProgressProvider(downloading.downloadKey).future,
      );
      final summary = await container.read(
        downloadStorageSummaryProvider.future,
      );

      expect(progress, isNotNull);
      expect(progress!.status, DownloadStatus.downloading);
      expect(progress.progressBytes, 128);
      expect(progress.totalBytes, 256);
      expect(progress.progressFraction, 0.5);
      expect(summary.completedCount, 1);
      expect(summary.totalBytes, 300);
    },
  );

  test(
    'groups downloads and builds future screen summaries deterministically',
    () async {
      final queued = _queuedDownload(
        trackId: 'queued',
      ).copyWith(updatedAt: DateTime.utc(2026, 5, 31, 18, 0, 0));
      final downloading = _queuedDownload(trackId: 'downloading').copyWith(
        status: DownloadStatus.downloading,
        updatedAt: DateTime.utc(2026, 5, 31, 18, 5, 0),
      );
      final completed = _queuedDownload(trackId: 'completed').copyWith(
        status: DownloadStatus.completed,
        sizeBytes: 512,
        updatedAt: DateTime.utc(2026, 5, 31, 18, 4, 0),
      );
      final failed = _queuedDownload(trackId: 'failed').copyWith(
        status: DownloadStatus.failed,
        retryable: true,
        updatedAt: DateTime.utc(2026, 5, 31, 18, 3, 0),
      );
      await database.putDownload(queued);
      await database.putDownload(downloading);
      await database.putDownload(completed);
      await database.putDownload(failed);

      final container = ProviderContainer(
        overrides: [
          downloadDatabaseProvider.overrideWith((ref) async => database),
          downloadStorageProvider.overrideWith((ref) async => storage),
        ],
      );
      addTearDown(container.dispose);

      await container.read(allDownloadsProvider.future);
      final grouped = container.read(groupedDownloadsProvider).requireValue;
      final summary = container.read(downloadsSummaryProvider).requireValue;
      final failedCount = container
          .read(failedDownloadsCountProvider)
          .requireValue;

      expect(grouped.active.map((item) => item.trackId).toList(), [
        'downloading',
        'queued',
      ]);
      expect(grouped.completed.map((item) => item.trackId).toList(), [
        'completed',
      ]);
      expect(grouped.failed.map((item) => item.trackId).toList(), ['failed']);
      expect(summary.totalCount, 4);
      expect(summary.activeCount, 2);
      expect(summary.completedCount, 1);
      expect(summary.failedCount, 1);
      expect(failedCount, 1);
    },
  );

  test('controller enqueues and retries by processing the queue', () async {
    final manager = _FakeDownloadManager(database: database, storage: storage);
    final container = ProviderContainer(
      overrides: [
        downloadDatabaseProvider.overrideWith((ref) async => database),
        downloadStorageProvider.overrideWith((ref) async => storage),
        downloadManagerProvider.overrideWith((ref) async => manager),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(downloadControllerProvider);

    await controller.enqueueTrack(_remoteTrack('enqueue-1'));
    await controller.retry('subsonic:server-a::enqueue-1');

    expect(manager.enqueuedTrackIds, ['enqueue-1']);
    expect(manager.retriedKeys, ['subsonic:server-a::enqueue-1']);
    expect(manager.processQueueCalls, 2);
  });

  test('controller cancels, deletes, and clears failed downloads', () async {
    final failedA = _queuedDownload(
      trackId: 'failed-a',
    ).copyWith(status: DownloadStatus.failed, retryable: true);
    final failedB = _queuedDownload(
      trackId: 'failed-b',
    ).copyWith(status: DownloadStatus.failed);
    await database.putDownload(failedA);
    await database.putDownload(failedB);

    final manager = _FakeDownloadManager(database: database, storage: storage);
    final container = ProviderContainer(
      overrides: [
        downloadDatabaseProvider.overrideWith((ref) async => database),
        downloadStorageProvider.overrideWith((ref) async => storage),
        downloadManagerProvider.overrideWith((ref) async => manager),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(downloadControllerProvider);

    await controller.cancel(failedA.downloadKey);
    await controller.delete(failedA.downloadKey);
    final cleared = await controller.clearFailed();

    expect(manager.cancelledKeys, [failedA.downloadKey]);
    expect(manager.deletedKeys, [
      failedA.downloadKey,
      failedA.downloadKey,
      failedB.downloadKey,
    ]);
    expect(cleared, 2);
  });

  test('delete guard blocks the currently playing download key only', () async {
    final currentItem = MediaItem(
      id: 'subsonic://track?serverId=server-a&id=guarded',
      title: 'Guarded',
      extras: {'providerId': 'subsonic:server-a', 'trackId': 'guarded'},
    );
    final container = ProviderContainer(
      overrides: [
        mediaItemProvider.overrideWith((ref) => Stream.value(currentItem)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(mediaItemProvider.future);

    final blocked = container.read(
      deleteDownloadGuardProvider('subsonic:server-a::guarded'),
    );
    final allowed = container.read(
      deleteDownloadGuardProvider('subsonic:server-a::other'),
    );

    expect(blocked.isBlocked, isTrue);
    expect(blocked.reason, contains('Stop playback first'));
    expect(allowed.isBlocked, isFalse);
  });

  test(
    'bootstrap recovers interrupted downloads before processing the queue',
    () async {
      final manager = _FakeDownloadManager(
        database: database,
        storage: storage,
      );
      final container = ProviderContainer(
        overrides: [
          downloadDatabaseProvider.overrideWith((ref) async => database),
          downloadStorageProvider.overrideWith((ref) async => storage),
          downloadManagerProvider.overrideWith((ref) async => manager),
        ],
      );
      addTearDown(container.dispose);

      await container.read(downloadBootstrapProvider.future);

      expect(manager.lifecycleEvents, ['recover', 'process']);
    },
  );
}

DownloadItem _queuedDownload({required String trackId}) {
  return DownloadItem.createQueued(
    identity: DownloadIdentity(
      providerFamily: 'subsonic',
      providerId: 'subsonic:home',
      serverId: 'home',
      trackId: trackId,
      remoteItemId: 'subsonic:home:$trackId',
      canonicalUri: 'subsonic://track?serverId=home&id=$trackId',
    ),
    title: 'Track $trackId',
    artist: 'Artist',
    album: 'Album',
    now: DateTime.utc(2026, 5, 31, 18),
  );
}

Track _remoteTrack(String trackId, {String? coverArtId}) {
  final queryParameters = <String, String>{
    'serverId': 'server-a',
    'id': trackId,
  };
  if (coverArtId != null) {
    queryParameters['coverArtId'] = coverArtId;
  }

  return Track(
    id: 'subsonic:server-a:$trackId',
    providerId: 'subsonic:server-a',
    title: 'Track $trackId',
    artist: 'Artist',
    album: 'Album',
    uri: Uri(
      scheme: 'subsonic',
      host: 'track',
      queryParameters: queryParameters,
    ),
  );
}

class _FakeDownloadManager extends DownloadManager {
  _FakeDownloadManager({required super.database, required super.storage})
    : super(adapters: const <DownloadSourceAdapter>[]);

  final List<String> enqueuedTrackIds = <String>[];
  final List<String> retriedKeys = <String>[];
  final List<String> cancelledKeys = <String>[];
  final List<String> deletedKeys = <String>[];
  final List<String> lifecycleEvents = <String>[];
  int processQueueCalls = 0;

  @override
  Future<DownloadItem> enqueue(DownloadRequest request) async {
    enqueuedTrackIds.add(request.identity.trackId);
    return DownloadItem.createQueued(
      identity: request.identity,
      title: request.title,
      artist: request.artist,
      album: request.album,
      coverArtId: request.coverArtId,
      now: DateTime.utc(2026, 6, 1, 12),
    );
  }

  @override
  Future<void> retry(String key) async {
    retriedKeys.add(key);
  }

  @override
  Future<void> cancel(String key) async {
    cancelledKeys.add(key);
  }

  @override
  Future<void> delete(String key) async {
    deletedKeys.add(key);
  }

  @override
  Future<void> recoverInterruptedDownloads() async {
    lifecycleEvents.add('recover');
  }

  @override
  Future<void> processQueue() async {
    processQueueCalls += 1;
    lifecycleEvents.add('process');
  }
}
