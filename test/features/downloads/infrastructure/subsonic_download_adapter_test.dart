import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta_music/features/downloads/application/download_manager.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/subsonic_download_adapter.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_api_client.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';

void main() {
  test('streams bytes from the canonical Subsonic track URL', () async {
    final adapter = SubsonicDownloadAdapter(
      store: await _storeWithServer(),
      clientFactory: ({required server, required password}) => _FakeSubsonicClient(
        stream: Uri.parse(
          'https://music.example.com/rest/stream.view?id=song-1&t=fresh-token',
        ),
      ),
      httpClient: _FakeHttpClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['id'], 'song-1');
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([
            utf8.encode('hello '),
            utf8.encode('world'),
          ]),
          200,
        );
      }),
    );

    final bytes = await adapter.open(_request()).expand((chunk) => chunk).toList();

    expect(adapter.canHandle('subsonic'), isTrue);
    expect(utf8.decode(bytes), 'hello world');
  });

  test('fails non-retryable when the Subsonic server is missing', () async {
    final adapter = SubsonicDownloadAdapter(
      store: SubsonicServerStore(
        metadataStore: _MemorySubsonicMetadataStore(),
        secretStore: InMemorySubsonicSecretStore(),
      ),
      clientFactory: ({required server, required password}) => _FakeSubsonicClient(
        stream: Uri.parse('https://unused.example'),
      ),
      httpClient: _FakeHttpClient.unused(),
    );

    await expectLater(
      () => adapter.open(_request()).drain<void>(),
      throwsA(
        isA<DownloadTransferException>()
            .having((error) => error.retryable, 'retryable', isFalse)
            .having((error) => error.code, 'code', 'server-not-found'),
      ),
    );
  });

  test('maps network fetch failures into retryable transfer errors', () async {
    final adapter = SubsonicDownloadAdapter(
      store: await _storeWithServer(),
      clientFactory: ({required server, required password}) => _FakeSubsonicClient(
        stream: Uri.parse(
          'https://music.example.com/rest/stream.view?id=song-1&t=fresh-token',
        ),
      ),
      httpClient: _FakeHttpClient((request) async {
        throw const SocketException('network down');
      }),
    );

    await expectLater(
      () => adapter.open(_request()).drain<void>(),
      throwsA(
        isA<DownloadTransferException>()
            .having((error) => error.retryable, 'retryable', isTrue)
            .having((error) => error.code, 'code', 'network-unavailable'),
      ),
    );
  });
}

DownloadRequest _request() {
  return DownloadRequest(
    identity: const DownloadIdentity(
      providerFamily: 'subsonic',
      providerId: 'subsonic:https-music-example-com-alice',
      serverId: 'https-music-example-com-alice',
      trackId: 'song-1',
      remoteItemId: 'subsonic:https-music-example-com-alice:song-1',
      canonicalUri:
          'subsonic://track?serverId=https-music-example-com-alice&id=song-1',
    ),
    title: 'Remote Song',
    artist: 'Artist',
    album: 'Album',
    fileExtension: 'mp3',
  );
}

Future<SubsonicServerStore> _storeWithServer() async {
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
  await store.saveServer(server, password: 'secret-password');
  return store;
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

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  _FakeHttpClient.unused() : _handler = _unused;

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  static Future<http.StreamedResponse> _unused(http.BaseRequest request) async {
    throw StateError('http client should not be used');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}
