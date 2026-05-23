import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/player/domain/playback_session.dart';

void main() {
  test('serializes and deserializes playback session', () {
    const item = MediaItem(
      id: 'file:///music/song.mp3',
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      duration: Duration(seconds: 10),
      extras: {'trackId': '1'},
    );
    final session = PlaybackSession(
      queue: const [item],
      currentIndex: 0,
      position: const Duration(seconds: 5),
    );

    final restored = PlaybackSession.fromJson(session.toJson());

    expect(restored, isNotNull);
    expect(restored!.queue.single.id, item.id);
    expect(restored.currentIndex, 0);
    expect(restored.position, const Duration(seconds: 5));
  });

  test('returns null for invalid queue index', () {
    final restored = PlaybackSession.fromJson({
      'queue': [
        {'id': 'file:///music/song.mp3', 'title': 'Song'},
      ],
      'currentIndex': 2,
      'positionMs': 1,
    });

    expect(restored, isNull);
  });
}
