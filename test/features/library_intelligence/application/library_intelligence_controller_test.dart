import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_controller.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_reducer.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_store.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_snapshot.dart';

void main() {
  group('LibraryIntelligenceController', () {
    test('toggles favorite on when track starts as non-favorite', () async {
      final store = _FakeStore(
        loaded: LibrarySnapshot(
          schemaVersion: 1,
          tracks: {
            'local::a': LibraryTrackSnapshot(
              trackKey: 'local::a',
              playCount: 1,
              lastPlayedAt: DateTime.utc(2026, 1, 1, 10),
              resumePositionMs: 0,
              durationMs: 180000,
              isFavorite: false,
              favoritedAt: null,
              isCompleted: false,
            ),
          },
        ),
      );
      final now = DateTime.utc(2026, 5, 22, 16, 0, 0);
      final controller = LibraryIntelligenceController(
        store: store,
        reducer: const LibraryIntelligenceReducer(),
        now: () => now,
      );

      final isFavorite = await controller.toggleFavorite(trackKey: 'local::a');

      expect(isFavorite, true);
      expect(store.saveCalls, 1);
      expect(store.lastSaved!.tracks['local::a']!.isFavorite, true);
      expect(store.lastSaved!.tracks['local::a']!.favoritedAt, now);
    });

    test('toggles favorite off when track starts as favorite', () async {
      final store = _FakeStore(
        loaded: LibrarySnapshot(
          schemaVersion: 1,
          tracks: {
            'local::a': LibraryTrackSnapshot(
              trackKey: 'local::a',
              playCount: 4,
              lastPlayedAt: DateTime.utc(2026, 1, 1, 10),
              resumePositionMs: 0,
              durationMs: 180000,
              isFavorite: true,
              favoritedAt: DateTime.utc(2026, 1, 1, 9),
              isCompleted: false,
            ),
          },
        ),
      );
      final controller = LibraryIntelligenceController(
        store: store,
        reducer: const LibraryIntelligenceReducer(),
        now: () => DateTime.utc(2026, 5, 22, 16, 30, 0),
      );

      final isFavorite = await controller.toggleFavorite(trackKey: 'local::a');

      expect(isFavorite, false);
      expect(store.saveCalls, 1);
      expect(store.lastSaved!.tracks['local::a']!.isFavorite, false);
      expect(store.lastSaved!.tracks['local::a']!.favoritedAt, isNull);
    });
  });
}

class _FakeStore implements LibraryIntelligenceStore {
  _FakeStore({required this.loaded});

  @override
  Future<void> clear() async {}

  LibrarySnapshot loaded;
  LibrarySnapshot? lastSaved;
  int saveCalls = 0;

  @override
  Future<LibrarySnapshot> load() async => loaded;

  @override
  Future<void> save(LibrarySnapshot snapshot) async {
    saveCalls += 1;
    lastSaved = snapshot;
    loaded = snapshot;
  }
}
