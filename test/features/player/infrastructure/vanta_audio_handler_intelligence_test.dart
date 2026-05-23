import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/player/infrastructure/vanta_audio_handler.dart';

void main() {
  group('VantaAudioHandler intelligence key normalization', () {
    test('prefers providerId::trackId from extras', () {
      final item = MediaItem(
        id: 'file:///track.mp3',
        title: 'Track',
        extras: const {'trackId': '123', 'providerId': 'local'},
      );

      expect(VantaAudioHandler.normalizeTrackKey(item), 'local::123');
    });

    test('falls back to media item id when extras are missing', () {
      final item = const MediaItem(id: 'file:///fallback.mp3', title: 'Track');

      expect(VantaAudioHandler.normalizeTrackKey(item), 'file:///fallback.mp3');
    });
  });
}
