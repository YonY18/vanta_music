import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../library/domain/track.dart';
import '../domain/playlist.dart';

class LocalPlaylistStore {
  static const _fileName = 'playlists.json';

  Future<List<Playlist>> getPlaylists() async {
    final file = await _file();
    if (!await file.exists()) return const [];

    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      return const [];
    }

    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_fromJson)
        .whereType<Playlist>()
        .toList(growable: false);
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final content = playlists.map(_toJson).toList(growable: false);
    await file.writeAsString(jsonEncode(content));
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Map<String, dynamic> _toJson(Playlist playlist) {
    return {
      'id': playlist.id,
      'name': playlist.name,
      'description': playlist.description,
      'createdAt': playlist.createdAt?.toIso8601String(),
      'updatedAt': playlist.updatedAt?.toIso8601String(),
      'tracks': playlist.tracks
          .map((track) {
            return {
              'id': track.id,
              'providerId': track.providerId,
              'title': track.title,
              'artist': track.artist,
              'album': track.album,
              'uri': track.uri.toString(),
              'albumId': track.albumId,
              'artistId': track.artistId,
              'durationMs': track.duration?.inMilliseconds,
              'artworkId': track.artworkId,
            };
          })
          .toList(growable: false),
    };
  }

  Playlist? _fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = json['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;

    final tracks =
        (json['tracks'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(_trackFromJson)
            .whereType<Track>()
            .toList(growable: false) ??
        const <Track>[];

    return Playlist(
      id: id,
      name: name,
      description: json['description']?.toString(),
      tracks: tracks,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
    );
  }

  Track? _trackFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final providerId = json['providerId']?.toString();
    final title = json['title']?.toString();
    final artist = json['artist']?.toString();
    final album = json['album']?.toString();
    final uri = json['uri']?.toString();
    if (id == null ||
        providerId == null ||
        title == null ||
        artist == null ||
        album == null ||
        uri == null) {
      return null;
    }

    final durationMs = json['durationMs'];
    return Track(
      id: id,
      providerId: providerId,
      title: title,
      artist: artist,
      album: album,
      uri: Uri.parse(uri),
      albumId: json['albumId']?.toString(),
      artistId: json['artistId']?.toString(),
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      artworkId: json['artworkId'] is int ? json['artworkId'] as int : null,
    );
  }
}
