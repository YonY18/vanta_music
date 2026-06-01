import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/application/download_manager.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/download_database.dart';
import 'package:vanta_music/features/downloads/infrastructure/file_download_storage.dart';
import 'package:vanta_music/features/player/application/subsonic_stream_resolver_registry.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_api_client.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';

void main() {
  test(
    'completes the local download lifecycle from enqueue to playback to delete',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'download-lifecycle',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final database = DownloadDatabase.inMemory();
      addTearDown(database.close);
      final storage = FileDownloadStorage(
        appSupportDirectory: () async => tempDir,
      );
      final manager = DownloadManager(
        database: database,
        storage: storage,
        adapters: [_LifecycleDownloadAdapter()],
      );
      final store = SubsonicServerStore(
        metadataStore: _MemorySubsonicMetadataStore(),
        secretStore: InMemorySubsonicSecretStore(),
      );
      await store.saveServer(
        const SubsonicServerConfig(
          id: 'home',
          name: 'Home',
          baseUrl: 'https://music.example.com',
          username: 'alice',
        ),
        password: 'secret',
      );

      final request = DownloadRequest(
        identity: _identity('song-1'),
        title: 'Song 1',
        artist: 'Artist',
        album: 'Album',
        fileExtension: 'mp3',
      );
      final queued = await manager.enqueue(request);

      await manager.processQueue();

      final completed = await database.getDownload(queued.downloadKey);
      expect(completed, isNotNull);
      expect(completed!.status, DownloadStatus.completed);
      final localFile = await storage.resolveFinalFile(
        completed.localRelativePath!,
      );
      expect(await localFile.exists(), isTrue);

      final resolver = SubsonicStreamResolverRegistry(
        store: store,
        clientFactory: ({required server, required password}) =>
            _UnusedSubsonicClient(),
        downloadDatabase: database,
        downloadStorage: storage,
      );

      final playbackUri = await resolver.resolve(
        const MediaItem(
          id: 'subsonic://track?serverId=home&id=song-1',
          title: 'Song 1',
          extras: {
            'providerId': 'subsonic:home',
            'canonicalUri': 'subsonic://track?serverId=home&id=song-1',
            'trackId': 'subsonic:home:song-1',
          },
        ),
      );

      expect(playbackUri, localFile.uri);

      await manager.delete(queued.downloadKey);

      expect(await database.getDownload(queued.downloadKey), isNull);
      expect(await localFile.exists(), isFalse);
    },
  );
}

DownloadIdentity _identity(String trackId) {
  return DownloadIdentity(
    providerFamily: 'subsonic',
    providerId: 'subsonic:home',
    serverId: 'home',
    trackId: trackId,
    remoteItemId: 'subsonic:home:$trackId',
    canonicalUri: 'subsonic://track?serverId=home&id=$trackId',
  );
}

class _LifecycleDownloadAdapter implements DownloadSourceAdapter {
  @override
  bool canHandle(String providerFamily) => providerFamily == 'subsonic';

  @override
  Stream<List<int>> open(DownloadRequest request) async* {
    yield [1, 2, 3, 4];
  }
}

class _UnusedSubsonicClient implements SubsonicApiClientContract {
  @override
  Uri streamUri(String songId) {
    fail('remote stream URI should not be used for a valid completed download');
  }

  @override
  Future<void> ping() => throw UnimplementedError();

  @override
  Future<List<SubsonicArtist>> getArtists() => throw UnimplementedError();

  @override
  Future<List<SubsonicAlbum>> getAlbumList2({
    String type = 'alphabeticalByName',
    int? size,
    int? offset,
  }) => throw UnimplementedError();

  @override
  Future<SubsonicAlbumDetail> getAlbum(String id) => throw UnimplementedError();

  @override
  Future<SubsonicSong> getSong(String id) => throw UnimplementedError();

  @override
  Future<List<SubsonicSong>> search3(String query) =>
      throw UnimplementedError();

  @override
  Uri getCoverArtUri(String coverArtId) => throw UnimplementedError();
}

class _MemorySubsonicMetadataStore implements SubsonicServerMetadataStore {
  SubsonicServerState _state = const SubsonicServerState();

  @override
  Future<SubsonicServerState> read() async => _state;

  @override
  Future<void> write(SubsonicServerState state) async {
    _state = state;
  }
}
