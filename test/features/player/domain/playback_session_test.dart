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

  test(
    'persists canonical remote identity instead of auth-bearing stream URLs',
    () {
      const item = MediaItem(
        id: 'https://music.example/rest/stream.view?id=remote-1&t=secret-token&s=salt&u=user',
        title: 'Remote Song',
        artist: 'Remote Artist',
        album: 'Remote Album',
        extras: {
          'trackId': 'subsonic:server-a:remote-1',
          'providerId': 'subsonic:server-a',
          'canonicalUri': 'subsonic://track?serverId=server-a&id=remote-1',
          'resolvedStreamUrl':
              'https://music.example/rest/stream.view?id=remote-1&t=secret-token',
        },
      );
      final session = PlaybackSession(
        queue: const [item],
        currentIndex: 0,
        position: Duration.zero,
      );

      final json = session.toJson();
      final serialized = json.toString();
      final restored = PlaybackSession.fromJson(json);

      expect(serialized, isNot(contains('secret-token')));
      expect(serialized, isNot(contains('stream.view')));
      expect(restored, isNotNull);
      expect(
        restored!.queue.single.id,
        'subsonic://track?serverId=server-a&id=remote-1',
      );
      expect(
        restored.queue.single.extras,
        containsPair('providerId', 'subsonic:server-a'),
      );
      expect(
        restored.queue.single.extras,
        isNot(contains('resolvedStreamUrl')),
      );
    },
  );
}
