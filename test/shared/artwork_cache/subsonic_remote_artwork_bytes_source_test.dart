import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_api_client.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_resolver.dart';
import 'package:vanta_music/shared/artwork_cache/subsonic_remote_artwork_bytes_source.dart';

void main() {
  test('resolves Subsonic cover-art URIs through saved credentials', () async {
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
    final httpSource = _FakeRemoteArtworkSource(
      result: Uint8List.fromList([1, 2, 3]),
    );
    late String factoryPassword;

    final source = SubsonicRemoteArtworkBytesSource(
      storeLoader: () async => store,
      httpSource: httpSource,
      clientFactory: ({required server, required password}) {
        factoryPassword = password;
        return _FakeSubsonicClient(
          coverArt: Uri.parse(
            'https://music.example.com/rest/getCoverArt.view?id=cover-1&u=alice&t=fresh-token',
          ),
        );
      },
    );

    final bytes = await source.fetch(
      uri: Uri.parse(
        'subsonic://cover-art?serverId=https-music-example-com-alice&id=cover-1',
      ),
      sizePx: 160,
    );

    expect(bytes, [1, 2, 3]);
    expect(factoryPassword, 'secret-password');
    expect(httpSource.requestedUris.single.scheme, 'https');
    expect(httpSource.requestedUris.single.queryParameters['t'], 'fresh-token');
  });

  test('keeps existing http artwork passthrough behavior', () async {
    final httpSource = _FakeRemoteArtworkSource(
      result: Uint8List.fromList([7, 8]),
    );
    final source = SubsonicRemoteArtworkBytesSource(
      storeLoader: () async => throw StateError('store should not be used'),
      httpSource: httpSource,
      clientFactory: ({required server, required password}) =>
          throw StateError('client should not be used'),
    );

    final bytes = await source.fetch(
      uri: Uri.parse('https://cdn.example.com/cover.jpg'),
      sizePx: 160,
    );

    expect(bytes, [7, 8]);
    expect(httpSource.requestedUris.single.host, 'cdn.example.com');
  });
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

class _FakeRemoteArtworkSource implements RemoteArtworkBytesSource {
  _FakeRemoteArtworkSource({required this.result});

  final Uint8List? result;
  final List<Uri> requestedUris = <Uri>[];

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    requestedUris.add(uri);
    return result;
  }
}

class _FakeSubsonicClient implements SubsonicApiClientContract {
  const _FakeSubsonicClient({required this.coverArt});

  final Uri coverArt;

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
  Uri streamUri(String songId) => throw UnimplementedError();

  @override
  Uri getCoverArtUri(String coverArtId) => coverArt;
}
