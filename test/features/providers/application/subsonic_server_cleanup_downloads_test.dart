import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/download_database.dart';
import 'package:vanta_music/features/downloads/infrastructure/file_download_storage.dart';
import 'package:vanta_music/features/providers/application/subsonic_providers.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';

void main() {
  late Directory tempDir;
  late DownloadDatabase database;
  late FileDownloadStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'subsonic-download-cleanup',
    );
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
    'deletes only linked download rows and files for the removed server',
    () async {
      final store = await buildSubsonicServerStore(
        directory: tempDir,
        secretStore: InMemorySubsonicSecretStore(),
        downloadDatabase: database,
        downloadStorage: storage,
      );
      await store.saveServer(_server('home'), password: 'home-secret');
      await store.saveServer(_server('work'), password: 'work-secret');

      final homePaths = await storage.resolvePaths(
        _identity('home', 'song-home'),
        fileExtension: 'mp3',
      );
      final workPaths = await storage.resolvePaths(
        _identity('work', 'song-work'),
        fileExtension: 'mp3',
      );
      await homePaths.finalFile.parent.create(recursive: true);
      await homePaths.finalFile.writeAsBytes([1, 2, 3]);
      await workPaths.finalFile.parent.create(recursive: true);
      await workPaths.finalFile.writeAsBytes([4, 5, 6]);
      final extraMetadata = File(
        '${homePaths.finalFile.parent.path}/manual-note.txt',
      );
      await extraMetadata.writeAsString('keep me');

      await database.putDownload(
        _completedDownload(_identity('home', 'song-home')).copyWith(
          localRelativePath: homePaths.finalRelativePath,
          tempRelativePath: homePaths.tempRelativePath,
          sizeBytes: 3,
        ),
      );
      await database.putDownload(
        _completedDownload(_identity('work', 'song-work')).copyWith(
          localRelativePath: workPaths.finalRelativePath,
          tempRelativePath: workPaths.tempRelativePath,
          sizeBytes: 3,
        ),
      );

      await store.deleteServer('home');

      expect(await database.getDownload('subsonic:home::song-home'), isNull);
      expect(await database.getDownload('subsonic:work::song-work'), isNotNull);
      expect(await homePaths.finalFile.exists(), isFalse);
      expect(await workPaths.finalFile.exists(), isTrue);
      expect(await extraMetadata.exists(), isTrue);
    },
  );

  test('removes temp remnants for server-owned failed downloads', () async {
    final store = await buildSubsonicServerStore(
      directory: tempDir,
      secretStore: InMemorySubsonicSecretStore(),
      downloadDatabase: database,
      downloadStorage: storage,
    );
    await store.saveServer(_server('home'), password: 'home-secret');

    final paths = await storage.resolvePaths(
      _identity('home', 'song-temp'),
      fileExtension: 'mp3',
    );
    await storage.writeTempChunk(paths.tempRelativePath, [
      9,
      8,
      7,
    ], append: false);
    await database.putDownload(
      _completedDownload(_identity('home', 'song-temp')).copyWith(
        status: DownloadStatus.failed,
        localRelativePath: paths.finalRelativePath,
        tempRelativePath: paths.tempRelativePath,
        sizeBytes: null,
        completedAt: null,
      ),
    );

    await store.deleteServer('home');

    expect(await database.getDownload('subsonic:home::song-temp'), isNull);
    expect(await paths.tempFile.exists(), isFalse);
  });

  test(
    'cleans queued and downloading rows only for the deleted server',
    () async {
      final store = await buildSubsonicServerStore(
        directory: tempDir,
        secretStore: InMemorySubsonicSecretStore(),
        downloadDatabase: database,
        downloadStorage: storage,
      );
      await store.saveServer(_server('home'), password: 'home-secret');
      await store.saveServer(_server('work'), password: 'work-secret');

      await database.putDownload(
        _completedDownload(
          _identity('home', 'song-queued'),
        ).copyWith(status: DownloadStatus.queued, completedAt: null),
      );
      await database.putDownload(
        _completedDownload(
          _identity('home', 'song-downloading'),
        ).copyWith(status: DownloadStatus.downloading, completedAt: null),
      );
      await database.putDownload(
        _completedDownload(
          _identity('work', 'song-keep'),
        ).copyWith(status: DownloadStatus.downloading, completedAt: null),
      );

      await store.deleteServer('home');

      expect(await database.getDownload('subsonic:home::song-queued'), isNull);
      expect(
        await database.getDownload('subsonic:home::song-downloading'),
        isNull,
      );
      expect(await database.getDownload('subsonic:work::song-keep'), isNotNull);
    },
  );
}

SubsonicServerConfig _server(String id) {
  return SubsonicServerConfig(
    id: id,
    name: id,
    baseUrl: 'https://$id.example.com',
    username: id,
  );
}

DownloadIdentity _identity(String serverId, String trackId) {
  return DownloadIdentity(
    providerFamily: 'subsonic',
    providerId: 'subsonic:$serverId',
    serverId: serverId,
    trackId: trackId,
    remoteItemId: 'subsonic:$serverId:$trackId',
    canonicalUri: 'subsonic://track?serverId=$serverId&id=$trackId',
  );
}

DownloadItem _completedDownload(DownloadIdentity identity) {
  final createdAt = DateTime.utc(2026, 5, 31, 19);
  return DownloadItem.createQueued(
    identity: identity,
    title: 'Track ${identity.trackId}',
    artist: 'Artist',
    album: 'Album',
    now: createdAt,
  ).copyWith(
    status: DownloadStatus.completed,
    progressBytes: 3,
    totalBytes: 3,
    completedAt: createdAt.add(const Duration(minutes: 1)),
    updatedAt: createdAt.add(const Duration(minutes: 1)),
  );
}
