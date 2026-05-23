import 'dart:async';

import '../domain/library_event.dart';
import '../domain/library_snapshot.dart';
import 'library_intelligence_reducer.dart';
import 'library_intelligence_store.dart';

typedef ClockNow = DateTime Function();

class LibraryIntelligenceSink {
  LibraryIntelligenceSink({
    required LibraryIntelligenceStore store,
    required LibraryIntelligenceReducer reducer,
    Duration debounceDuration = const Duration(milliseconds: 400),
    ClockNow? now,
  }) : _store = store,
       _reducer = reducer,
       _debounceDuration = debounceDuration,
       _now = now ?? DateTime.now;

  final LibraryIntelligenceStore _store;
  final LibraryIntelligenceReducer _reducer;
  final Duration _debounceDuration;
  final ClockNow _now;

  LibrarySnapshot _snapshot = const LibrarySnapshot.empty();
  final List<LibraryEvent> _pendingEvents = <LibraryEvent>[];
  Future<void> _persistQueue = Future<void>.value();
  Timer? _debounce;
  bool _initialized = false;

  LibrarySnapshot get snapshot => _snapshot;

  Future<void> initialize() async {
    if (_initialized) return;
    _snapshot = await _store.load();
    _initialized = true;
  }

  void recordPlayStarted({required String trackKey}) {
    _record(LibraryEvent.playStarted(trackKey: trackKey, timestamp: _now()));
  }

  void recordProgress({
    required String trackKey,
    required int positionMs,
    required int durationMs,
  }) {
    _record(
      LibraryEvent.progressUpdated(
        trackKey: trackKey,
        positionMs: positionMs,
        durationMs: durationMs,
        timestamp: _now(),
      ),
    );
  }

  void recordPlaybackCompleted({required String trackKey}) {
    _record(LibraryEvent.playbackCompleted(trackKey: trackKey, timestamp: _now()));
  }

  Future<void> flush() async {
    await _flushPending();
    await _persistQueue;
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await flush();
  }

  void _record(LibraryEvent event) {
    _snapshot = _reducer.reduce(_snapshot, [event]);
    _pendingEvents.add(event);
    _schedulePersist();
  }

  void _schedulePersist() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      unawaited(_flushPending());
    });
  }

  Future<void> _flushPending() {
    _debounce?.cancel();
    if (_pendingEvents.isEmpty) return _persistQueue;
    _pendingEvents.clear();
    _persistQueue = _persistQueue.then((_) => _store.save(_snapshot));
    return _persistQueue;
  }
}
