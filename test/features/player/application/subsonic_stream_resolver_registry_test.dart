import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/download_database.dart';
import 'package:vanta_music/features/downloads/infrastructure/file_download_storage.dart';
import 'package:vanta_music/features/player/application/subsonic_stream_resolver_registry.dart';
import 'package:vanta_music/features/player/infrastructure/vanta_audio_handler.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_api_client.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';

void main() {
  test('resolves saved Subsonic queue items to fresh stream URLs', () async {
    final metadataStore = _MemorySubsonicMetadataStore();
    final secretStore = InMemorySubsonicSecretStore();
    final store = SubsonicServerStore(
      metadataStore: metadataStore,
      secretStore: secretStore,
    );
    final server = const SubsonicServerConfig(
      id: 'https-music-example-com-alice',
      name: 'Home',
      baseUrl: 'https://music.example.com',
      username: 'alice',
    );
    await store.saveServer(server, password: 'secret-password');
    await store.selectActiveServer(server.id);
    late String factoryPassword;

    final resolver = SubsonicStreamResolverRegistry(
      store: store,
      clientFactory: ({required server, required password}) {
        factoryPassword = password;
        return _FakeSubsonicClient(
          stream: Uri.parse(
            'https://music.example.com/rest/stream.view?id=song-1&u=alice&t=fresh-token',
          ),
        );
      },
    );

    final result = await resolver.resolve(
      const MediaItem(
        id: 'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
        title: 'Remote Song',
        extras: {
          'providerId': 'subsonic:https-music-example-com-alice',
          'canonicalUri':
              'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
          'trackId': 'subsonic:https-music-example-com-alice:song-1',
        },
      ),
    );

    expect(result.scheme, 'https');
    expect(result.path, '/rest/stream.view');
    expect(result.queryParameters['t'], 'fresh-token');
    expect(factoryPassword, 'secret-password');
  });

  test('prefers a validated downloaded file before remote streaming', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'resolver-local-first',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final storage = FileDownloadStorage(
      appSupportDirectory: () async => tempDir,
    );
    final database = DownloadDatabase.inMemory();
    addTearDown(database.close);
    final locations = await storage.resolvePaths(
      _identity(),
      fileExtension: 'mp3',
    );
    await locations.finalFile.parent.create(recursive: true);
    await locations.finalFile.writeAsBytes([1, 2, 3]);
    await database.putDownload(
      _completedDownload(
        localRelativePath: locations.finalRelativePath,
        tempRelativePath: locations.tempRelativePath,
        sizeBytes: 3,
      ),
    );

    final resolver = SubsonicStreamResolverRegistry(
      store: await _storeWithServer(),
      clientFactory: ({required server, required password}) {
        fail('remote resolver should not be used when download is valid');
      },
      downloadDatabase: database,
      downloadStorage: storage,
    );
    final item = _canonicalItem();

    final result = await resolver.resolve(item);

    expect(result, locations.finalFile.uri);
    expect(
      item.id,
      'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
    );
    expect(item.extras?['canonicalUri'], item.id);
    expect(
      item.extras?['trackId'],
      'subsonic:https-music-example-com-alice:song-1',
    );
  });

  test('falls back to remote streaming when completed file is missing', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'resolver-missing-file',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final storage = FileDownloadStorage(
      appSupportDirectory: () async => tempDir,
    );
    final database = DownloadDatabase.inMemory();
    addTearDown(database.close);
    final locations = await storage.resolvePaths(
      _identity(),
      fileExtension: 'mp3',
    );
    await database.putDownload(
      _completedDownload(
        localRelativePath: locations.finalRelativePath,
        tempRelativePath: locations.tempRelativePath,
        sizeBytes: 42,
      ),
    );
    final resolver = SubsonicStreamResolverRegistry(
      store: await _storeWithServer(),
      clientFactory: ({required server, required password}) => _FakeSubsonicClient(
        stream: Uri.parse(
          'https://music.example.com/rest/stream.view?id=song-1&u=alice&t=fresh-token',
        ),
      ),
      downloadDatabase: database,
      downloadStorage: storage,
    );

    final result = await resolver.resolve(_canonicalItem());
    final updated = await database.getDownload(_identity().downloadKey);

    expect(result.scheme, 'https');
    expect(updated?.status, DownloadStatus.failed);
    expect(updated?.errorCode, 'offline-file-missing');
    expect(updated?.lastValidatedAt, isNotNull);
  });

  test(
    'fails with offline-unavailable when local file is invalid and remote is down',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'resolver-invalid-file',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final storage = FileDownloadStorage(
        appSupportDirectory: () async => tempDir,
      );
      final database = DownloadDatabase.inMemory();
      addTearDown(database.close);
      final locations = await storage.resolvePaths(
        _identity(),
        fileExtension: 'mp3',
      );
      await locations.finalFile.parent.create(recursive: true);
      await locations.finalFile.writeAsBytes(const []);
      await database.putDownload(
        _completedDownload(
          localRelativePath: locations.finalRelativePath,
          tempRelativePath: locations.tempRelativePath,
          sizeBytes: 0,
        ),
      );
      final resolver = SubsonicStreamResolverRegistry(
        store: await _storeWithServer(),
        clientFactory: ({required server, required password}) =>
            _ThrowingSubsonicClient(
              error: const SubsonicUnavailableFailure('Server unavailable.'),
            ),
        downloadDatabase: database,
        downloadStorage: storage,
      );

      await expectLater(
        () => resolver.resolve(_canonicalItem()),
        throwsA(
          isA<RemoteTrackResolveException>()
              .having((error) => error.retryable, 'retryable', isTrue)
              .having(
                (error) => error.message,
                'message',
                contains('Offline copy is unavailable.'),
              ),
        ),
      );
    },
  );

  test(
    'keeps canonical identity stable across repeated offline resolves',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'resolver-offline-repeat',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final storage = FileDownloadStorage(
        appSupportDirectory: () async => tempDir,
      );
      final database = DownloadDatabase.inMemory();
      addTearDown(database.close);
      final locations = await storage.resolvePaths(
        _identity(),
        fileExtension: 'mp3',
      );
      await locations.finalFile.parent.create(recursive: true);
      await locations.finalFile.writeAsBytes([1, 2, 3, 4]);
      await database.putDownload(
        _completedDownload(
          localRelativePath: locations.finalRelativePath,
          tempRelativePath: locations.tempRelativePath,
          sizeBytes: 4,
        ),
      );

      final item = _canonicalItem();
      final resolver = SubsonicStreamResolverRegistry(
        store: await _storeWithServer(),
        clientFactory: ({required server, required password}) {
          fail('offline replay should stay local while the download is valid');
        },
        downloadDatabase: database,
        downloadStorage: storage,
      );

      final first = await resolver.resolve(item);
      final second = await resolver.resolve(item);

      expect(first, locations.finalFile.uri);
      expect(second, locations.finalFile.uri);
      expect(
        item.id,
        'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
      );
      expect(item.extras?['canonicalUri'], item.id);
      expect(
        item.extras?['trackId'],
        'subsonic:https-music-example-com-alice:song-1',
      );
    },
  );

  test('preserves direct local media item URIs', () async {
    final resolver = SubsonicStreamResolverRegistry(
      store: SubsonicServerStore(
        metadataStore: _MemorySubsonicMetadataStore(),
        secretStore: InMemorySubsonicSecretStore(),
      ),
      clientFactory: ({required server, required password}) =>
          _FakeSubsonicClient(stream: Uri.parse('https://unused.example')),
    );

    final result = await resolver.resolve(
      const MediaItem(id: 'file:///music/local.mp3', title: 'Local Song'),
    );

    expect(result, Uri.parse('file:///music/local.mp3'));
  });

  test('fails closed for Subsonic provider without a Subsonic URI', () async {
    final resolver = _resolver();

    await _expectSubsonicResolveFailure(
      resolver,
      const MediaItem(
        id: 'https://stale.example.com/stream.view?id=song-1&t=old-token',
        title: 'Remote Song',
        extras: {
          'providerId': 'subsonic:https-music-example-com-alice',
          'canonicalUri': 'https://stale.example.com/song-1.mp3',
        },
      ),
      message: 'missing canonical Subsonic URI',
    );
  });

  test('resolves Subsonic item id when canonical URI is non-Subsonic', () async {
    final store = await _storeWithServer();
    final resolver = SubsonicStreamResolverRegistry(
      store: store,
      clientFactory: ({required server, required password}) => _FakeSubsonicClient(
        stream: Uri.parse(
          'https://music.example.com/rest/stream.view?id=song-1&u=alice&t=fresh-token',
        ),
      ),
    );

    final result = await resolver.resolve(
      const MediaItem(
        id: 'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
        title: 'Remote Song',
        extras: {
          'providerId': 'subsonic:https-music-example-com-alice',
          'canonicalUri': 'https://stale.example.com/song-1.mp3',
        },
      ),
    );

    expect(result.scheme, 'https');
    expect(result.path, '/rest/stream.view');
    expect(result.queryParameters['t'], 'fresh-token');
  });

  test(
    'fails closed for Subsonic item id when canonical URI is empty',
    () async {
      final resolver = _resolver();

      await _expectSubsonicResolveFailure(
        resolver,
        const MediaItem(
          id: 'subsonic://track?serverId=missing-server&id=song-1',
          title: 'Remote Song',
          extras: {'providerId': 'subsonic:missing-server', 'canonicalUri': ''},
        ),
        message: 'server not found',
      );
    },
  );

  test(
    'throws when a Subsonic canonical item references a missing server',
    () async {
      final resolver = _resolver();

      await _expectSubsonicResolveFailure(
        resolver,
        const MediaItem(
          id: 'subsonic://track?serverId=missing-server&id=song-1',
          title: 'Remote Song',
          extras: {
            'providerId': 'subsonic:missing-server',
            'canonicalUri':
                'subsonic://track?serverId=missing-server&id=song-1',
          },
        ),
        message: 'server not found',
      );
    },
  );

  test('throws when a Subsonic canonical item has no saved password', () async {
    final store = await _storeWithServer(savePassword: false);
    final resolver = _resolver(store: store);

    await _expectSubsonicResolveFailure(
      resolver,
      const MediaItem(
        id: 'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
        title: 'Remote Song',
        extras: {
          'providerId': 'subsonic:https-music-example-com-alice',
          'canonicalUri':
              'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
        },
      ),
      message: 'missing password',
    );
  });

  test(
    'throws when a Subsonic canonical item is missing the song id',
    () async {
      final store = await _storeWithServer();
      final resolver = _resolver(store: store);

      await _expectSubsonicResolveFailure(
        resolver,
        const MediaItem(
          id: 'subsonic://track?serverId=https-music-example-com-alice',
          title: 'Remote Song',
          extras: {
            'providerId': 'subsonic:https-music-example-com-alice',
            'canonicalUri':
                'subsonic://track?serverId=https-music-example-com-alice',
          },
        ),
        message: 'missing song id',
      );
    },
  );

  test(
    'throws when a Subsonic canonical item is missing the server id',
    () async {
      final resolver = _resolver();

      await _expectSubsonicResolveFailure(
        resolver,
        const MediaItem(
          id: 'subsonic://track?id=song-1',
          title: 'Remote Song',
          extras: {'canonicalUri': 'subsonic://track?id=song-1'},
        ),
        message: 'missing server id',
      );
    },
  );

  test(
    'throws when a Subsonic canonical item has an invalid server id',
    () async {
      final resolver = _resolver();

      await _expectSubsonicResolveFailure(
        resolver,
        const MediaItem(
          id: 'subsonic://track?serverId=not-saved&id=song-1',
          title: 'Remote Song',
          extras: {
            'canonicalUri': 'subsonic://track?serverId=not-saved&id=song-1',
          },
        ),
        message: 'server not found',
      );
    },
  );

  test(
    'maps retryable Subsonic failures into retryable track resolution errors',
    () async {
      final store = await _storeWithServer();
      final resolver = SubsonicStreamResolverRegistry(
        store: store,
        clientFactory: ({required server, required password}) =>
            _ThrowingSubsonicClient(
              error: const SubsonicTimeoutFailure(
                'Subsonic request timed out.',
              ),
            ),
      );

      await expectLater(
        () => resolver.resolve(
          const MediaItem(
            id: 'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
            title: 'Remote Song',
            extras: {
              'providerId': 'subsonic:https-music-example-com-alice',
              'canonicalUri':
                  'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
              'trackId': 'subsonic:https-music-example-com-alice:song-1',
            },
          ),
        ),
        throwsA(
          isA<RemoteTrackResolveException>()
              .having((error) => error.retryable, 'retryable', isTrue)
              .having(
                (error) => error.message,
                'message',
                contains('Retry this track.'),
              ),
        ),
      );
    },
  );
}

DownloadIdentity _identity() {
  return const DownloadIdentity(
    providerFamily: 'subsonic',
    providerId: 'subsonic:https-music-example-com-alice',
    serverId: 'https-music-example-com-alice',
    trackId: 'song-1',
    remoteItemId: 'subsonic:https-music-example-com-alice:song-1',
    canonicalUri:
        'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
  );
}

MediaItem _canonicalItem() {
  return const MediaItem(
    id: 'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
    title: 'Remote Song',
    extras: {
      'providerId': 'subsonic:https-music-example-com-alice',
      'canonicalUri':
          'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
      'trackId': 'subsonic:https-music-example-com-alice:song-1',
    },
  );
}

DownloadItem _completedDownload({
  required String localRelativePath,
  required String tempRelativePath,
  required int sizeBytes,
}) {
  final now = DateTime.utc(2026, 5, 31, 18);
  return DownloadItem(
    identity: _identity(),
    title: 'Remote Song',
    artist: 'Artist',
    album: 'Album',
    status: DownloadStatus.completed,
    progressBytes: sizeBytes,
    totalBytes: sizeBytes,
    sizeBytes: sizeBytes,
    localRelativePath: localRelativePath,
    tempRelativePath: tempRelativePath,
    createdAt: now,
    updatedAt: now,
    completedAt: now,
  );
}

Future<SubsonicServerStore> _storeWithServer({bool savePassword = true}) async {
  final store = SubsonicServerStore(
    metadataStore: _MemorySubsonicMetadataStore(),
    secretStore: InMemorySubsonicSecretStore(),
  );
  const server = SubsonicServerConfig(
    id: 'https-music-example-com-alice',
    name: 'Home',
    baseUrl: 'https://music.example.com',
    username: 'alice',
  );
  await store.saveServer(
    server,
    password: savePassword ? 'secret-password' : '',
  );
  return store;
}

SubsonicStreamResolverRegistry _resolver({SubsonicServerStore? store}) {
  return SubsonicStreamResolverRegistry(
    store:
        store ??
        SubsonicServerStore(
          metadataStore: _MemorySubsonicMetadataStore(),
          secretStore: InMemorySubsonicSecretStore(),
        ),
    clientFactory: ({required server, required password}) =>
        _FakeSubsonicClient(stream: Uri.parse('https://unused.example')),
  );
}

Future<void> _expectSubsonicResolveFailure(
  SubsonicStreamResolverRegistry resolver,
  MediaItem item, {
  required String message,
}) async {
  try {
    final uri = await resolver.resolve(item);
    fail('Expected Subsonic resolution to fail, got $uri');
  } on StateError catch (error) {
    expect(error.message, contains(message));
    expect(error.message, isNot(contains('subsonic://')));
    expect(error.message, isNot(contains('secret-password')));
  }
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

class _FakeSubsonicClient implements SubsonicApiClientContract {
  const _FakeSubsonicClient({required this.stream});

  final Uri stream;

  @override
  Future<void> ping() async {}

  @override
  Future<List<SubsonicArtist>> getArtists() async => const [];

  @override
  Future<List<SubsonicAlbum>> getAlbumList2({
    String type = 'alphabeticalByName',
    int? size,
    int? offset,
  }) async => const [];

  @override
  Future<SubsonicAlbumDetail> getAlbum(String id) async =>
      throw UnimplementedError();

  @override
  Future<SubsonicSong> getSong(String id) async => throw UnimplementedError();

  @override
  Future<List<SubsonicSong>> search3(String query) async => const [];

  @override
  Uri streamUri(String songId) => stream;

  @override
  Uri getCoverArtUri(String coverArtId) => throw UnimplementedError();
}

class _ThrowingSubsonicClient implements SubsonicApiClientContract {
  const _ThrowingSubsonicClient({required this.error});

  final SubsonicFailure error;

  @override
  Future<void> ping() async {}

  @override
  Future<List<SubsonicArtist>> getArtists() async => const [];

  @override
  Future<List<SubsonicAlbum>> getAlbumList2({
    String type = 'alphabeticalByName',
    int? size,
    int? offset,
  }) async => const [];

  @override
  Future<SubsonicAlbumDetail> getAlbum(String id) async =>
      throw UnimplementedError();

  @override
  Future<SubsonicSong> getSong(String id) async => throw UnimplementedError();

  @override
  Future<List<SubsonicSong>> search3(String query) async => const [];

  @override
  Uri streamUri(String songId) => throw error;

  @override
  Uri getCoverArtUri(String coverArtId) => throw UnimplementedError();
}
