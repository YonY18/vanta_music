import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/application/download_manager.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/download_database.dart';
import 'package:vanta_music/features/downloads/infrastructure/file_download_storage.dart';

void main() {
  late Directory tempDir;
  late DownloadDatabase database;
  late FileDownloadStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download-manager-test');
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
    'reuses manifest rows and in-memory queue entries for duplicates',
    () async {
      final manager = DownloadManager(
        database: database,
        storage: storage,
        adapters: [_FakeDownloadAdapter()],
      );

      final first = await manager.enqueue(_request(trackId: 'song-1'));
      final second = await manager.enqueue(_request(trackId: 'song-1'));

      expect(second.downloadKey, first.downloadKey);
      expect(await manager.listDownloads(), hasLength(1));
      expect(manager.pendingKeys, {'subsonic:home::song-1'});
    },
  );

  test('recovers interrupted downloads and removes partial files', () async {
    final manager = DownloadManager(
      database: database,
      storage: storage,
      adapters: [_FakeDownloadAdapter()],
    );
    final queued = await manager.enqueue(_request(trackId: 'song-2'));
    final paths = await storage.resolvePaths(
      queued.identity,
      fileExtension: 'mp3',
    );
    await storage.writeTempChunk(paths.tempRelativePath, [1, 2, 3]);
    await database.putDownload(
      queued.copyWith(
        status: DownloadStatus.downloading,
        tempRelativePath: paths.tempRelativePath,
      ),
    );

    await manager.recoverInterruptedDownloads();

    final recovered = await manager.getDownload(queued.downloadKey);
    expect(recovered?.status, DownloadStatus.failed);
    expect(recovered?.retryable, isTrue);
    expect(await paths.tempFile.exists(), isFalse);
  });

  test('keeps queue moving when one download fails', () async {
    final manager = DownloadManager(
      database: database,
      storage: storage,
      adapters: [
        _FakeDownloadAdapter(
          streams: {
            'song-a': Stream<List<int>>.fromIterable([
              [1, 2],
            ]),
            'song-b': Stream<List<int>>.error(
              const DownloadTransferException(
                code: 'server-unavailable',
                message: 'Server unavailable',
                retryable: true,
              ),
            ),
            'song-c': Stream<List<int>>.fromIterable([
              [3, 4, 5],
            ]),
          },
        ),
      ],
    );

    await manager.enqueue(_request(trackId: 'song-a'));
    await manager.enqueue(_request(trackId: 'song-b'));
    await manager.enqueue(_request(trackId: 'song-c'));

    await manager.processQueue();

    final states = {
      for (final item in await manager.listDownloads())
        item.trackId: item.status,
    };
    expect(states['song-a'], DownloadStatus.completed);
    expect(states['song-b'], DownloadStatus.failed);
    expect(states['song-c'], DownloadStatus.completed);
  });
}

DownloadRequest _request({required String trackId}) {
  return DownloadRequest(
    identity: DownloadIdentity(
      providerFamily: 'subsonic',
      providerId: 'subsonic:home',
      serverId: 'home',
      trackId: trackId,
      remoteItemId: 'subsonic:home:$trackId',
      canonicalUri: 'subsonic://track?serverId=home&id=$trackId',
    ),
    title: 'Title $trackId',
    artist: 'Artist',
    album: 'Album',
    fileExtension: 'mp3',
  );
}

class _FakeDownloadAdapter implements DownloadSourceAdapter {
  _FakeDownloadAdapter({Map<String, Stream<List<int>>>? streams})
    : _streams = streams ?? <String, Stream<List<int>>>{};

  final Map<String, Stream<List<int>>> _streams;

  @override
  bool canHandle(String providerFamily) => providerFamily == 'subsonic';

  @override
  Stream<List<int>> open(DownloadRequest request) {
    return _streams[request.identity.trackId] ??
        Stream<List<int>>.fromIterable([
          [1, 2, 3],
        ]);
  }
}
