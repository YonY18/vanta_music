import 'dart:convert';
import 'dart:io';

import '../../library/domain/album.dart';
import '../../library/domain/artist.dart';
import '../../library/domain/track.dart';
import '../domain/music_provider.dart';
import '../domain/provider_identity.dart';
import '../domain/stream_uri.dart';
import 'subsonic_api_client.dart';
import 'subsonic_server_store.dart';

class SubsonicMusicProvider implements MusicProvider {
  static const defaultRemoteAlbumHydrationLimit = 100;

  SubsonicMusicProvider({
    required this.server,
    required this.client,
    this.snapshotStore,
    this.remoteAlbumHydrationLimit = defaultRemoteAlbumHydrationLimit,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SubsonicServerConfig server;
  final SubsonicApiClientContract client;
  final RemoteLibrarySnapshotStore? snapshotStore;
  final int remoteAlbumHydrationLimit;
  final DateTime Function() _clock;

  @override
  String get id => subsonicProviderId(server.id);

  @override
  String get name => server.name;

  @override
  Future<List<Artist>> getArtists() async {
    final artists = await client.getArtists();
    return artists
        .map(
          (artist) => Artist(
            id: remoteItemId(serverId: server.id, itemId: artist.id),
            providerId: id,
            name: artist.name,
            trackCount: 0,
            albumCount: artist.albumCount,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Album>> getAlbums() async {
    final albums = await client.getAlbumList2();
    return albums.map(_mapAlbum).toList(growable: false);
  }

  @override
  Future<List<Track>> getTracks() async {
    return (await loadTrackSnapshot()).tracks;
  }

  Future<RemoteLibrarySnapshot> loadTrackSnapshot() async {
    try {
      final albums = await client.getAlbumList2(
        size: remoteAlbumHydrationLimit,
      );
      final tracks = <Track>[];
      for (final album in albums) {
        final detail = await client.getAlbum(album.id);
        tracks.addAll(detail.songs.map(_mapSong));
      }
      final snapshot = RemoteLibrarySnapshot(
        serverId: server.id,
        providerId: id,
        tracks: tracks,
        lastSyncAt: _clock().toUtc(),
        isStale: false,
        isPartial: albums.length >= remoteAlbumHydrationLimit,
      );
      await snapshotStore?.write(snapshot);
      return snapshot;
    } on SubsonicFailure catch (error) {
      final cached = await snapshotStore?.read(
        serverId: server.id,
        providerId: id,
      );
      if (cached != null) {
        return cached.copyWith(isStale: true, failure: error);
      }
      rethrow;
    }
  }

  @override
  Future<List<Track>> search(String query) async {
    final songs = await client.search3(query);
    return songs.map(_mapSong).toList(growable: false);
  }

  @override
  Future<StreamUri> resolveStream(Track track) async {
    if (track.providerId != id) {
      throw ArgumentError.value(
        track.providerId,
        'track.providerId',
        'does not belong to this Subsonic provider',
      );
    }
    final songId = _rawSongId(track);
    return StreamUri(client.streamUri(songId));
  }

  Uri coverArtUri(String coverArtId) => client.getCoverArtUri(coverArtId);

  Album _mapAlbum(SubsonicAlbum album) => Album(
    id: remoteItemId(serverId: server.id, itemId: album.id),
    providerId: id,
    title: album.title,
    artist: album.artist,
    trackCount: album.songCount ?? 0,
  );

  Track _mapSong(SubsonicSong song) => Track(
    id: remoteItemId(serverId: server.id, itemId: song.id),
    providerId: id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    uri: Uri(
      scheme: 'subsonic',
      host: 'track',
      queryParameters: <String, String>{
        'serverId': server.id,
        'id': song.id,
        if (song.coverArt != null && song.coverArt!.isNotEmpty)
          'coverArtId': song.coverArt!,
      },
    ),
    albumId: song.albumId == null
        ? null
        : remoteItemId(serverId: server.id, itemId: song.albumId!),
    artistId: song.artistId == null
        ? null
        : remoteItemId(serverId: server.id, itemId: song.artistId!),
    duration: song.durationSeconds == null
        ? null
        : Duration(seconds: song.durationSeconds!),
  );

  String _rawSongId(Track track) {
    final uriId = track.uri.queryParameters['id'];
    if (track.uri.scheme == 'subsonic' && uriId != null && uriId.isNotEmpty) {
      return uriId;
    }
    final prefix = '$subsonicProviderPrefix:${server.id}:';
    if (track.id.startsWith(prefix)) return track.id.substring(prefix.length);
    throw ArgumentError.value(
      track.id,
      'track.id',
      'is not a server-scoped Subsonic track id',
    );
  }
}

class RemoteLibrarySnapshot {
  const RemoteLibrarySnapshot({
    required this.serverId,
    required this.providerId,
    required this.tracks,
    required this.lastSyncAt,
    required this.isStale,
    this.isPartial = false,
    this.failure,
  });

  final String serverId;
  final String providerId;
  final List<Track> tracks;
  final DateTime lastSyncAt;
  final bool isStale;
  final bool isPartial;
  final SubsonicFailure? failure;

  RemoteLibrarySnapshot copyWith({
    List<Track>? tracks,
    DateTime? lastSyncAt,
    bool? isStale,
    bool? isPartial,
    SubsonicFailure? failure,
  }) {
    return RemoteLibrarySnapshot(
      serverId: serverId,
      providerId: providerId,
      tracks: tracks ?? this.tracks,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      isStale: isStale ?? this.isStale,
      isPartial: isPartial ?? this.isPartial,
      failure: failure ?? this.failure,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'serverId': serverId,
      'providerId': providerId,
      'lastSyncAt': lastSyncAt.toUtc().toIso8601String(),
      'isPartial': isPartial,
      'tracks': tracks.map(_trackToJson).toList(growable: false),
    };
  }

  factory RemoteLibrarySnapshot.fromJson(Map<String, Object?> json) {
    final rawTracks = json['tracks'];
    return RemoteLibrarySnapshot(
      serverId: json['serverId'] as String? ?? '',
      providerId: json['providerId'] as String? ?? '',
      tracks: rawTracks is List<Object?>
          ? rawTracks
                .whereType<Map<String, Object?>>()
                .map(_trackFromJson)
                .toList(growable: false)
          : const <Track>[],
      lastSyncAt: DateTime.parse(
        json['lastSyncAt'] as String? ??
            DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      ).toUtc(),
      isStale: false,
      isPartial: json['isPartial'] == true,
    );
  }
}

abstract class RemoteLibrarySnapshotStore {
  Future<RemoteLibrarySnapshot?> read({
    required String serverId,
    required String providerId,
  });

  Future<void> write(RemoteLibrarySnapshot snapshot);

  Future<void> deleteServer(String serverId);
}

class FileRemoteLibrarySnapshotStore implements RemoteLibrarySnapshotStore {
  const FileRemoteLibrarySnapshotStore(this.file);

  final File file;

  @override
  Future<RemoteLibrarySnapshot?> read({
    required String serverId,
    required String providerId,
  }) async {
    final snapshots = await _readAll();
    return snapshots[_snapshotKey(serverId, providerId)];
  }

  @override
  Future<void> write(RemoteLibrarySnapshot snapshot) async {
    final snapshots = await _readAll();
    snapshots[_snapshotKey(snapshot.serverId, snapshot.providerId)] = snapshot;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(snapshots.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  @override
  Future<void> deleteServer(String serverId) async {
    final normalizedServerId = _requireSnapshotStoreText(serverId, 'serverId');
    final snapshots = await _readAll();
    snapshots.removeWhere(
      (_, snapshot) => snapshot.serverId == normalizedServerId,
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(snapshots.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  Future<Map<String, RemoteLibrarySnapshot>> _readAll() async {
    if (!await file.exists()) return <String, RemoteLibrarySnapshot>{};
    final content = await file.readAsString();
    if (content.trim().isEmpty) return <String, RemoteLibrarySnapshot>{};
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, Object?>) {
      return <String, RemoteLibrarySnapshot>{};
    }

    final snapshots = <String, RemoteLibrarySnapshot>{};
    decoded.forEach((key, value) {
      if (value is Map<String, Object?>) {
        final snapshot = RemoteLibrarySnapshot.fromJson(value);
        if (snapshot.serverId.isNotEmpty && snapshot.providerId.isNotEmpty) {
          snapshots[key] = snapshot;
        }
      }
    });
    return snapshots;
  }
}

class InMemoryRemoteLibrarySnapshotStore implements RemoteLibrarySnapshotStore {
  InMemoryRemoteLibrarySnapshotStore({
    List<RemoteLibrarySnapshot> snapshots = const [],
  }) : _snapshots = {
         for (final snapshot in snapshots)
           _snapshotKey(snapshot.serverId, snapshot.providerId): snapshot,
       };

  final Map<String, RemoteLibrarySnapshot> _snapshots;

  @override
  Future<RemoteLibrarySnapshot?> read({
    required String serverId,
    required String providerId,
  }) async {
    return _snapshots[_snapshotKey(serverId, providerId)];
  }

  @override
  Future<void> write(RemoteLibrarySnapshot snapshot) async {
    _snapshots[_snapshotKey(snapshot.serverId, snapshot.providerId)] = snapshot;
  }

  @override
  Future<void> deleteServer(String serverId) async {
    final normalizedServerId = _requireSnapshotStoreText(serverId, 'serverId');
    _snapshots.removeWhere(
      (_, snapshot) => snapshot.serverId == normalizedServerId,
    );
  }
}

String _snapshotKey(String serverId, String providerId) =>
    '$serverId::$providerId';

String _requireSnapshotStoreText(String value, String fieldName) {
  final text = value.trim();
  if (text.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be empty');
  }
  return text;
}

Map<String, Object?> _trackToJson(Track track) {
  return <String, Object?>{
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
}

Track _trackFromJson(Map<String, Object?> json) {
  final durationMs = json['durationMs'];
  return Track(
    id: json['id'] as String? ?? '',
    providerId: json['providerId'] as String? ?? '',
    title: json['title'] as String? ?? 'Unknown Track',
    artist: json['artist'] as String? ?? 'Unknown Artist',
    album: json['album'] as String? ?? 'Unknown Album',
    uri: Uri.parse(json['uri'] as String? ?? 'subsonic://track'),
    albumId: json['albumId'] as String?,
    artistId: json['artistId'] as String?,
    duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
    artworkId: json['artworkId'] as int?,
  );
}
