import '../domain/playback_session.dart';

abstract class PlaybackSessionStore {
  Future<void> save(PlaybackSession session);
  Future<PlaybackSession?> load();
  Future<void> clear();
}
