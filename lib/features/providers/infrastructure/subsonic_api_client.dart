import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'subsonic_server_store.dart';

abstract class SubsonicApiClientContract {
  Future<void> ping();
  Future<List<SubsonicArtist>> getArtists();
  Future<List<SubsonicAlbum>> getAlbumList2({
    String type = 'alphabeticalByName',
  });
  Future<SubsonicAlbumDetail> getAlbum(String id);
  Future<SubsonicSong> getSong(String id);
  Future<List<SubsonicSong>> search3(String query);
  Uri streamUri(String songId);
  Uri getCoverArtUri(String coverArtId);
}

class SubsonicApiClient implements SubsonicApiClientContract {
  SubsonicApiClient({
    required SubsonicServerConfig server,
    required this.password,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    String Function()? saltGenerator,
  }) : _server = server.normalized(),
       _httpClient = httpClient ?? http.Client(),
       _saltGenerator = saltGenerator ?? _randomSalt;

  static const clientId = 'vanta';

  final String password;
  final Duration timeout;
  final SubsonicServerConfig _server;
  final http.Client _httpClient;
  final String Function() _saltGenerator;

  @override
  Future<void> ping() async {
    await _request('ping');
  }

  @override
  Future<List<SubsonicArtist>> getArtists() async {
    final response = await _request('getArtists');
    final indexes = _asList(_asMap(response['artists'])['index']);
    return indexes
        .expand((index) => _asList(_asMap(index)['artist']))
        .map((artist) => SubsonicArtist.fromJson(_asMap(artist)))
        .toList(growable: false);
  }

  @override
  Future<List<SubsonicAlbum>> getAlbumList2({
    String type = 'alphabeticalByName',
  }) async {
    final response = await _request('getAlbumList2', <String, String>{
      'type': type,
    });
    return _asList(_asMap(response['albumList2'])['album'])
        .map((album) => SubsonicAlbum.fromJson(_asMap(album)))
        .toList(growable: false);
  }

  @override
  Future<SubsonicAlbumDetail> getAlbum(String id) async {
    final response = await _request('getAlbum', <String, String>{'id': id});
    final album = _asMap(response['album']);
    return SubsonicAlbumDetail(
      album: SubsonicAlbum.fromJson(album),
      songs: _asList(album['song'])
          .map((song) => SubsonicSong.fromJson(_asMap(song)))
          .toList(growable: false),
    );
  }

  @override
  Future<SubsonicSong> getSong(String id) async {
    final response = await _request('getSong', <String, String>{'id': id});
    return SubsonicSong.fromJson(_asMap(response['song']));
  }

  @override
  Future<List<SubsonicSong>> search3(String query) async {
    final response = await _request('search3', <String, String>{
      'query': query,
    });
    return _asList(_asMap(response['searchResult3'])['song'])
        .map((song) => SubsonicSong.fromJson(_asMap(song)))
        .toList(growable: false);
  }

  @override
  Uri streamUri(String songId) =>
      _uri('stream', <String, String>{'id': songId});

  @override
  Uri getCoverArtUri(String coverArtId) =>
      _uri('getCoverArt', <String, String>{'id': coverArtId});

  static Uri redactUri(Uri uri) {
    final redacted = Map<String, String>.from(uri.queryParameters)
      ..remove('u')
      ..remove('s')
      ..remove('t')
      ..remove('password')
      ..remove('token');
    return uri.replace(queryParameters: redacted.isEmpty ? null : redacted);
  }

  Future<Map<String, Object?>> _request(
    String method, [
    Map<String, String> params = const {},
  ]) async {
    final uri = _uri(method, params);
    try {
      final response = await _httpClient.get(uri).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SubsonicServerFailure(
          'Server returned HTTP ${response.statusCode}',
          redactedUri: redactUri(uri),
        );
      }
      return _decodeResponse(response.body, uri);
    } on TimeoutException catch (_) {
      throw SubsonicTimeoutFailure(
        'Subsonic request timed out.',
        redactedUri: redactUri(uri),
      );
    } on HandshakeException catch (error) {
      throw SubsonicTlsFailure(
        'TLS validation failed: $error',
        redactedUri: redactUri(uri),
      );
    } on TlsException catch (error) {
      throw SubsonicTlsFailure(
        'TLS validation failed: $error',
        redactedUri: redactUri(uri),
      );
    } on SocketException catch (error) {
      throw SubsonicServerFailure(
        'Network error: $error',
        redactedUri: redactUri(uri),
      );
    } on FormatException catch (error) {
      throw SubsonicMalformedResponseFailure(
        'Malformed Subsonic response: $error',
        redactedUri: redactUri(uri),
      );
    }
  }

  Map<String, Object?> _decodeResponse(String body, Uri uri) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Root response is not an object.');
    }
    final subsonicResponse = decoded['subsonic-response'];
    if (subsonicResponse is! Map<String, Object?>) {
      throw const FormatException('Missing subsonic-response object.');
    }
    if (subsonicResponse['status'] == 'failed') {
      final error = _asMap(subsonicResponse['error']);
      final code = error['code'];
      final message =
          error['message'] as String? ?? 'Subsonic authentication failed.';
      if (code == 40 || code == 41) {
        throw SubsonicAuthFailure(message, redactedUri: redactUri(uri));
      }
      throw SubsonicServerFailure(message, redactedUri: redactUri(uri));
    }
    if (subsonicResponse['status'] != 'ok') {
      throw const FormatException('Unknown Subsonic response status.');
    }
    return subsonicResponse;
  }

  Uri _uri(String method, Map<String, String> params) {
    final salt = _saltGenerator();
    final token = md5.convert(utf8.encode('$password$salt')).toString();
    final base = Uri.parse(_server.baseUrl);
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/rest/$method.view',
      queryParameters: <String, String>{
        ...params,
        'u': _server.username,
        's': salt,
        't': token,
        'v': _server.apiVersion,
        'c': clientId,
        'f': 'json',
      },
    );
  }

  static String _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(
      12,
      (_) => random.nextInt(16),
    ).map((value) => value.toRadixString(16)).join();
  }
}

class SubsonicArtist {
  const SubsonicArtist({required this.id, required this.name, this.albumCount});

  final String id;
  final String name;
  final int? albumCount;

  factory SubsonicArtist.fromJson(Map<String, Object?> json) => SubsonicArtist(
    id: _requiredString(json, 'id'),
    name: _requiredString(json, 'name'),
    albumCount: _optionalInt(json['albumCount']),
  );
}

class SubsonicAlbum {
  const SubsonicAlbum({
    required this.id,
    required this.title,
    required this.artist,
    this.songCount,
    this.coverArt,
  });

  final String id;
  final String title;
  final String artist;
  final int? songCount;
  final String? coverArt;

  factory SubsonicAlbum.fromJson(Map<String, Object?> json) => SubsonicAlbum(
    id: _requiredString(json, 'id'),
    title:
        (json['title'] as String?) ??
        (json['name'] as String?) ??
        'Unknown Album',
    artist: (json['artist'] as String?) ?? 'Unknown Artist',
    songCount: _optionalInt(json['songCount']),
    coverArt: json['coverArt'] as String?,
  );
}

class SubsonicAlbumDetail {
  const SubsonicAlbumDetail({required this.album, required this.songs});

  final SubsonicAlbum album;
  final List<SubsonicSong> songs;
}

class SubsonicSong {
  const SubsonicSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumId,
    this.artistId,
    this.durationSeconds,
    this.coverArt,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumId;
  final String? artistId;
  final int? durationSeconds;
  final String? coverArt;

  factory SubsonicSong.fromJson(Map<String, Object?> json) => SubsonicSong(
    id: _requiredString(json, 'id'),
    title: (json['title'] as String?) ?? 'Unknown Track',
    artist: (json['artist'] as String?) ?? 'Unknown Artist',
    album: (json['album'] as String?) ?? 'Unknown Album',
    albumId: json['albumId'] as String?,
    artistId: json['artistId'] as String?,
    durationSeconds: _optionalInt(json['duration']),
    coverArt: json['coverArt'] as String?,
  );
}

abstract class SubsonicFailure implements Exception {
  const SubsonicFailure(this.message, {this.redactedUri});

  final String message;
  final Uri? redactedUri;

  @override
  String toString() {
    final safeMessage = message
        .replaceAll(
          RegExp(r'password=[^\s&]+', caseSensitive: false),
          'password=<redacted>',
        )
        .replaceAll(
          RegExp(r'token=[^\s&]+', caseSensitive: false),
          'token=<redacted>',
        )
        .replaceAll(RegExp(r'\bt=[^\s&]+'), 't=<redacted>')
        .replaceAll(RegExp(r'\bs=[^\s&]+'), 's=<redacted>')
        .replaceAll(RegExp(r'\bu=[^\s&]+'), 'u=<redacted>')
        .replaceAll('secret', '<redacted>')
        .replaceAll('token', '<redacted>')
        .replaceAll('salt', '<redacted>');
    final uri = redactedUri == null ? '' : ' (${redactedUri!})';
    return '$runtimeType: $safeMessage$uri';
  }
}

class SubsonicAuthFailure extends SubsonicFailure {
  const SubsonicAuthFailure(super.message, {super.redactedUri});
}

class SubsonicTimeoutFailure extends SubsonicFailure {
  const SubsonicTimeoutFailure(super.message, {super.redactedUri});
}

class SubsonicTlsFailure extends SubsonicFailure {
  const SubsonicTlsFailure(super.message, {super.redactedUri});
}

class SubsonicServerFailure extends SubsonicFailure {
  const SubsonicServerFailure(super.message, {super.redactedUri});
}

class SubsonicMalformedResponseFailure extends SubsonicFailure {
  const SubsonicMalformedResponseFailure(super.message, {super.redactedUri});
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  throw const FormatException('Expected object.');
}

List<Object?> _asList(Object? value) {
  if (value == null) return const [];
  if (value is List<Object?>) return value;
  throw const FormatException('Expected list.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing required string: $key');
}

int? _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
