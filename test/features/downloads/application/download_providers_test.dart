import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/application/download_providers.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/download_database.dart';
import 'package:vanta_music/features/downloads/infrastructure/file_download_storage.dart';

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
