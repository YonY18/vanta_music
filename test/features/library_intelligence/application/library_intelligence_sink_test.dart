import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_reducer.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_sink.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_store.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_snapshot.dart';

void main() {
  group('LibraryIntelligenceSink', () {
    test(
      'coalesces burst events into debounced save and updates snapshot',
      () async {
        final store = _FakeStore();
        final sink = LibraryIntelligenceSink(
          store: store,
          reducer: const LibraryIntelligenceReducer(),
          debounceDuration: const Duration(milliseconds: 20),
          now: () => DateTime.parse('2026-05-22T15:00:00.000Z'),
        );

        await sink.initialize();

        sink.recordPlayStarted(trackKey: 'local::a');
        sink.recordProgress(
          trackKey: 'local::a',
          positionMs: 22000,
          durationMs: 180000,
        );
        sink.recordPlaybackCompleted(trackKey: 'local::a');

        await Future<void>.delayed(const Duration(milliseconds: 35));

        expect(store.saveCalls, 1);
        final tracked = sink.snapshot.tracks['local::a'];
        expect(tracked, isNotNull);
        expect(tracked!.playCount, 1);
        expect(tracked.isCompleted, true);
        expect(tracked.resumePositionMs, 0);
      },
    );

    test('flush persists latest snapshot immediately', () async {
      final store = _FakeStore();
      final sink = LibraryIntelligenceSink(
        store: store,
        reducer: const LibraryIntelligenceReducer(),
        debounceDuration: const Duration(seconds: 2),
        now: () => DateTime.parse('2026-05-22T16:00:00.000Z'),
      );

      await sink.initialize();
      sink.recordPlayStarted(trackKey: 'local::b');

      await sink.flush();

      expect(store.saveCalls, 1);
      expect(store.lastSaved?.tracks.containsKey('local::b'), true);
    });

    test('notifies after persisted playback intelligence changes', () async {
      final store = _FakeStore();
      var changeCount = 0;
      final sink = LibraryIntelligenceSink(
        store: store,
        reducer: const LibraryIntelligenceReducer(),
        onChanged: () => changeCount += 1,
      );

      await sink.initialize();

      sink.recordPlayStarted(trackKey: 'local::c');
      sink.recordProgress(
        trackKey: 'local::c',
        positionMs: 22000,
        durationMs: 180000,
      );

      expect(changeCount, 0);

      await sink.flush();

      expect(changeCount, 1);
      expect(store.lastSaved?.tracks.containsKey('local::c'), true);
    });
  });
}

class _FakeStore implements LibraryIntelligenceStore {
  @override
  Future<void> clear() async {}

  LibrarySnapshot loaded = const LibrarySnapshot.empty();
  LibrarySnapshot? lastSaved;
  int saveCalls = 0;

  @override
  Future<LibrarySnapshot> load() async => loaded;

  @override
  Future<void> save(LibrarySnapshot snapshot) async {
    saveCalls += 1;
    lastSaved = snapshot;
  }
}
