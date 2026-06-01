import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/download_database.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download-db-test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reuses existing active manifest row for duplicate enqueue', () async {
    final database = DownloadDatabase.inMemory();
    addTearDown(database.close);

    final first = await database.enqueue(
      DownloadItem.createQueued(
        identity: _identity(trackId: 'song-1'),
        title: 'Song 1',
        artist: 'Artist',
        album: 'Album',
        now: DateTime.utc(2026, 5, 31, 15),
      ),
    );
    final second = await database.enqueue(
      DownloadItem.createQueued(
        identity: _identity(trackId: 'song-1'),
        title: 'Song 1 duplicate request',
        artist: 'Artist',
        album: 'Album',
        now: DateTime.utc(2026, 5, 31, 16),
      ),
    );

    expect(second.downloadKey, first.downloadKey);
    expect(second.createdAt, first.createdAt);
    expect(await database.getAllDownloads(), hasLength(1));
  });

  test('persists completed manifest state to sqlite and reloads it', () async {
    final file = File('${tempDir.path}/downloads.sqlite');
    final createdAt = DateTime.utc(2026, 5, 31, 15);

    final writer = DownloadDatabase.file(file);
    await writer.putDownload(
      DownloadItem.createQueued(
        identity: _identity(trackId: 'song-2'),
        title: 'Song 2',
        artist: 'Artist',
        album: 'Album',
        now: createdAt,
      ).copyWith(
        status: DownloadStatus.completed,
        progressBytes: 512,
        totalBytes: 512,
        sizeBytes: 512,
        localRelativePath: 'downloads/subsonic/home/song-2.mp3',
        tempRelativePath: 'downloads/subsonic/home/song-2.mp3.part',
        completedAt: createdAt.add(const Duration(minutes: 1)),
        updatedAt: createdAt.add(const Duration(minutes: 1)),
      ),
    );
    await writer.close();

    final reader = DownloadDatabase.file(file);
    addTearDown(reader.close);
    final persisted = await reader.getDownload('subsonic:home::song-2');

    expect(persisted, isNotNull);
    expect(persisted!.status, DownloadStatus.completed);
    expect(persisted.localRelativePath, 'downloads/subsonic/home/song-2.mp3');
    expect(persisted.sizeBytes, 512);
  });

  test('marks interrupted downloads failed during recovery', () async {
    final database = DownloadDatabase.inMemory();
    addTearDown(database.close);
    final startedAt = DateTime.utc(2026, 5, 31, 15);

    await database.putDownload(
      DownloadItem.createQueued(
        identity: _identity(trackId: 'song-3'),
        title: 'Song 3',
        artist: 'Artist',
        album: 'Album',
        now: startedAt,
      ).copyWith(
        status: DownloadStatus.downloading,
        tempRelativePath: 'downloads/subsonic/home/song-3.mp3.part',
        updatedAt: startedAt.add(const Duration(minutes: 2)),
      ),
    );

    await database.recoverInterruptedDownloads(
      now: startedAt.add(const Duration(minutes: 3)),
    );

    final recovered = await database.getDownload('subsonic:home::song-3');
    expect(recovered, isNotNull);
    expect(recovered!.status, DownloadStatus.failed);
    expect(recovered.retryable, isTrue);
    expect(recovered.errorCode, 'interrupted');
  });
}

DownloadIdentity _identity({required String trackId}) {
  return DownloadIdentity(
    providerFamily: 'subsonic',
    providerId: 'subsonic:home',
    serverId: 'home',
    trackId: trackId,
    remoteItemId: 'subsonic:home:$trackId',
    canonicalUri: 'subsonic://track?serverId=home&id=$trackId',
  );
}
