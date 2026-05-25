import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_providers.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/library/presentation/library_screen.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_providers.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_snapshot.dart';
import 'package:vanta_music/features/playlists/application/playlists_controller.dart';
import 'package:vanta_music/features/playlists/domain/playlist.dart';
import 'package:vanta_music/features/playlists/infrastructure/local_playlist_store.dart';

void main() {
  testWidgets('renders bounded local stats cards on the home tab', (
    tester,
  ) async {
    await tester.pumpLibraryScreen(
      tracks: [
        _track('1', album: 'Night', artist: 'Vanta', durationSeconds: 180),
        _track('2', album: 'Night', artist: 'Vanta', durationSeconds: 240),
        _track('3', album: 'Dawn', artist: 'Echo', durationSeconds: 60),
      ],
      snapshot: LibrarySnapshot(
        schemaVersion: 1,
        tracks: {
          'local::1': _snapshot('local::1', playCount: 4),
          'local::2': _snapshot('local::2', playCount: 2),
          'local::3': _snapshot('local::3', playCount: 1),
        },
      ),
    );

    expect(find.text('Library stats'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('2 albums'), findsOneWidget);
    expect(find.text('2 artists'), findsOneWidget);
    expect(find.text('8 min'), findsOneWidget);
  });

  testWidgets('opens playlist detail from the playlists tab', (tester) async {
    final playlist = Playlist(
      id: 'p1',
      name: 'Night Drive',
      tracks: [_track('1', title: 'Midnight Road')],
    );

    await tester.pumpLibraryScreen(playlists: [playlist]);

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night Drive'));
    await tester.pumpAndSettle();

    expect(find.text('Night Drive'), findsWidgets);
    expect(find.text('1 song'), findsOneWidget);
    expect(find.text('Midnight Road'), findsOneWidget);
  });

  testWidgets('shows explicit smart-section and premium empty states', (
    tester,
  ) async {
    await tester.pumpLibraryScreen(tracks: [_track('1')]);

    expect(find.text('Smart library warming up'), findsOneWidget);
    expect(
      find.text(
        'Play local tracks to unlock recent, favorite, and most-played sections.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cloud sync coming soon'), findsOneWidget);
  });
}

extension on WidgetTester {
  Future<void> pumpLibraryScreen({
    List<Track> tracks = const [],
    LibrarySnapshot snapshot = const LibrarySnapshot.empty(),
    List<Playlist> playlists = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          tracksProvider.overrideWith((ref) async => tracks),
          libraryIntelligenceSnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
          localPlaylistStoreProvider.overrideWithValue(
            _MemoryPlaylistStore(playlists),
          ),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await pumpAndSettle();
  }
}

Track _track(
  String id, {
  String? title,
  String album = 'Album',
  String artist = 'Artist',
  int durationSeconds = 120,
}) {
  return Track(
    id: id,
    providerId: 'local',
    title: title ?? 'Song $id',
    artist: artist,
    album: album,
    uri: Uri.parse('content://song/$id'),
    duration: Duration(seconds: durationSeconds),
  );
}

LibraryTrackSnapshot _snapshot(String trackKey, {required int playCount}) {
  return LibraryTrackSnapshot(
    trackKey: trackKey,
    playCount: playCount,
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    resumePositionMs: 0,
    durationMs: 120000,
    isFavorite: false,
    favoritedAt: null,
    isCompleted: true,
  );
}

class _MemoryPlaylistStore extends LocalPlaylistStore {
  _MemoryPlaylistStore(this._playlists);

  List<Playlist> _playlists;

  @override
  Future<List<Playlist>> getPlaylists() async => _playlists;

  @override
  Future<void> savePlaylists(List<Playlist> playlists) async {
    _playlists = playlists;
  }
}
