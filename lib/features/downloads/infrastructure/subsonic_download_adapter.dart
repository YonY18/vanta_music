import 'dart:io';

import 'package:http/http.dart' as http;

import '../../providers/application/subsonic_providers.dart';
import '../../providers/infrastructure/subsonic_api_client.dart';
import '../../providers/infrastructure/subsonic_server_store.dart';
import '../application/download_manager.dart';

class SubsonicDownloadAdapter implements DownloadSourceAdapter {
  SubsonicDownloadAdapter({
    required this.store,
    required this.clientFactory,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final SubsonicServerStore store;
  final SubsonicApiClientFactory clientFactory;
  final http.Client _httpClient;

  @override
  bool canHandle(String providerFamily) => providerFamily == 'subsonic';

  @override
  Stream<List<int>> open(DownloadRequest request) async* {
    final server = await store.loadServer(request.identity.serverId);
    if (server == null) {
      throw const DownloadTransferException(
        code: 'server-not-found',
        message: 'Subsonic server not found for download.',
        retryable: false,
      );
    }

    final password = await store.readPassword(server.id);
    if (password == null || password.isEmpty) {
      throw const DownloadTransferException(
        code: 'missing-password',
        message: 'Subsonic server password is missing for download.',
        retryable: false,
      );
    }

    final streamUri = _streamUri(request, server: server, password: password);
    final response = await _send(streamUri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DownloadTransferException(
        code: _statusCode(response.statusCode),
        message: 'Subsonic download failed with HTTP ${response.statusCode}.',
        retryable: response.statusCode >= 500,
      );
    }

    yield* response.stream;
  }

  Uri _streamUri(
    DownloadRequest request, {
    required SubsonicServerConfig server,
    required String password,
  }) {
    try {
      return clientFactory(server: server, password: password).streamUri(
        request.identity.trackId,
      );
    } on SubsonicFailure catch (error) {
      throw DownloadTransferException(
        code: _subsonicCode(error),
        message: 'Could not prepare Subsonic download stream.',
        retryable:
            error is SubsonicTimeoutFailure ||
            error is SubsonicUnavailableFailure,
      );
    }
  }

  Future<http.StreamedResponse> _send(Uri uri) async {
    try {
      return await _httpClient.send(http.Request('GET', uri));
    } on SocketException {
      throw const DownloadTransferException(
        code: 'network-unavailable',
        message: 'Network unavailable while downloading Subsonic track.',
        retryable: true,
      );
    } on HttpException {
      throw const DownloadTransferException(
        code: 'network-http',
        message: 'HTTP error while downloading Subsonic track.',
        retryable: true,
      );
    }
  }

  String _statusCode(int statusCode) {
    if (statusCode == 401 || statusCode == 403) return 'auth-failed';
    if (statusCode == 404) return 'track-not-found';
    if (statusCode >= 500) return 'server-unavailable';
    return 'http-$statusCode';
  }

  String _subsonicCode(SubsonicFailure error) {
    if (error is SubsonicAuthFailure) return 'auth-failed';
    if (error is SubsonicForbiddenFailure) return 'forbidden';
    if (error is SubsonicNotFoundFailure) return 'track-not-found';
    if (error is SubsonicTimeoutFailure) return 'timeout';
    if (error is SubsonicUnavailableFailure) return 'server-unavailable';
    return 'stream-uri-failed';
  }
}
