import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta_music/features/providers/infrastructure/subsonic_api_client.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';

void main() {
  const server = SubsonicServerConfig(
    id: 'home',
    name: 'Home',
    baseUrl: 'https://music.example.test/',
    username: 'alice',
  );

  test(
    'forms authenticated JSON requests with token auth parameters',
    () async {
      late Uri requestedUri;
      final client = SubsonicApiClient(
        server: server,
        password: 'correct horse battery staple',
        saltGenerator: () => 'abc123',
        httpClient: _FakeHttpClient((request) async {
          requestedUri = request.url;
          return http.Response(_okJson(), 200);
        }),
      );

      await client.ping();

      expect(requestedUri.path, '/rest/ping.view');
      expect(requestedUri.queryParameters['u'], 'alice');
      expect(requestedUri.queryParameters['s'], 'abc123');
      expect(
        requestedUri.queryParameters['t'],
        'ef95be52681551df676e5c8d5e54aedf',
      );
      expect(requestedUri.queryParameters['v'], '1.16.1');
      expect(requestedUri.queryParameters['c'], 'vanta');
      expect(requestedUri.queryParameters['f'], 'json');
      expect(requestedUri.toString(), isNot(contains('correct horse')));
    },
  );

  test(
    'maps timeout, TLS, auth, and malformed responses to typed failures',
    () async {
      final timeoutClient = SubsonicApiClient(
        server: server,
        password: 'secret',
        timeout: const Duration(milliseconds: 1),
        httpClient: _FakeHttpClient(
          (_) => Future<http.Response>.delayed(
            const Duration(milliseconds: 20),
            () => http.Response(_okJson(), 200),
          ),
        ),
      );
      final tlsClient = SubsonicApiClient(
        server: server,
        password: 'secret',
        httpClient: _FakeHttpClient((_) async {
          throw const TlsException('certificate verify failed');
        }),
      );
      final authClient = SubsonicApiClient(
        server: server,
        password: 'secret',
        httpClient: _FakeHttpClient(
          (_) async => http.Response(
            _errorJson(code: 40, message: 'Wrong username or password'),
            200,
          ),
        ),
      );
      final malformedClient = SubsonicApiClient(
        server: server,
        password: 'secret',
        httpClient: _FakeHttpClient(
          (_) async => http.Response('not json', 200),
        ),
      );

      await expectLater(
        timeoutClient.ping(),
        throwsA(isA<SubsonicTimeoutFailure>()),
      );
      await expectLater(tlsClient.ping(), throwsA(isA<SubsonicTlsFailure>()));
      await expectLater(authClient.ping(), throwsA(isA<SubsonicAuthFailure>()));
      await expectLater(
        malformedClient.ping(),
        throwsA(isA<SubsonicMalformedResponseFailure>()),
      );
    },
  );

  test('classifies HTTP failures into explicit remote failure types', () async {
    final forbiddenClient = SubsonicApiClient(
      server: server,
      password: 'secret',
      httpClient: _FakeHttpClient((_) async => http.Response(_okJson(), 403)),
    );
    final missingClient = SubsonicApiClient(
      server: server,
      password: 'secret',
      httpClient: _FakeHttpClient((_) async => http.Response(_okJson(), 404)),
    );
    final unavailableClient = SubsonicApiClient(
      server: server,
      password: 'secret',
      httpClient: _FakeHttpClient((_) async => http.Response(_okJson(), 503)),
    );

    await expectLater(
      forbiddenClient.ping(),
      throwsA(isA<SubsonicForbiddenFailure>()),
    );
    await expectLater(
      missingClient.ping(),
      throwsA(isA<SubsonicNotFoundFailure>()),
    );
    await expectLater(
      unavailableClient.ping(),
      throwsA(isA<SubsonicUnavailableFailure>()),
    );
  });

  test('retries recoverable failures with a hard attempt cap', () async {
    var attempts = 0;
    final client = SubsonicApiClient(
      server: server,
      password: 'secret',
      timeout: const Duration(milliseconds: 1),
      maxRetryAttempts: 3,
      retryBackoffBase: Duration.zero,
      httpClient: _FakeHttpClient((_) async {
        attempts += 1;
        if (attempts < 3) {
          return Future<http.Response>.delayed(
            const Duration(milliseconds: 20),
            () => http.Response(_okJson(), 200),
          );
        }
        return http.Response(_okJson(), 200);
      }),
    );

    await client.ping();

    expect(attempts, 3);
  });

  test('stops retrying once the bounded cap is reached', () async {
    var attempts = 0;
    final client = SubsonicApiClient(
      server: server,
      password: 'secret',
      maxRetryAttempts: 2,
      retryBackoffBase: Duration.zero,
      httpClient: _FakeHttpClient((_) async {
        attempts += 1;
        throw const SocketException('host lookup failed');
      }),
    );

    await expectLater(
      client.ping(),
      throwsA(isA<SubsonicUnavailableFailure>()),
    );

    expect(attempts, 2);
  });

  test('redacts credentials and auth-bearing URLs from safe error strings', () {
    final url = Uri.parse(
      'https://music.example.test/rest/stream.view?u=alice&s=salt&t=token&c=vanta&f=json&id=song-1',
    );
    final failure = SubsonicServerFailure(
      'Server returned 500 for $url with password=secret',
      redactedUri: SubsonicApiClient.redactUri(url),
    );

    expect(failure.toString(), contains('stream.view'));
    expect(failure.toString(), contains('id=song-1'));
    expect(failure.toString(), isNot(contains('token')));
    expect(failure.toString(), isNot(contains('salt')));
    expect(failure.toString(), isNot(contains('secret')));
    expect(failure.toString(), isNot(contains('u=alice')));
  });

  test('builds stream and cover art URLs without performing downloads', () {
    final client = SubsonicApiClient(
      server: server,
      password: 'secret',
      saltGenerator: () => 'salt',
    );

    final streamUri = client.streamUri('song-42');
    final coverUri = client.getCoverArtUri('cover-7');

    expect(streamUri.path, '/rest/stream.view');
    expect(streamUri.queryParameters['id'], 'song-42');
    expect(coverUri.path, '/rest/getCoverArt.view');
    expect(coverUri.queryParameters['id'], 'cover-7');
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

String _okJson([String body = '']) {
  final extra = body.isEmpty ? '' : ',$body';
  return '{"subsonic-response":{"status":"ok","version":"1.16.1"$extra}}';
}

String _errorJson({required int code, required String message}) =>
    '{"subsonic-response":{"status":"failed","error":{"code":$code,"message":"$message"}}}';
