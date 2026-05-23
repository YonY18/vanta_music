import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/player/application/media_item_artwork_request.dart';

void main() {
  group('trackArtworkRequestFromMediaItem', () {
    test('builds request from extras', () {
      final item = MediaItem(
        id: 'file:///music/song.mp3',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(minutes: 3),
        extras: const {
          'providerId': 'local',
          'trackId': '42',
          'artworkId': 77,
        },
      );

      final result = trackArtworkRequestFromMediaItem(item: item, sizePx: 160);

      expect(result, isNotNull);
      expect(result!.sizePx, 160);
      expect(result.track.providerId, 'local');
      expect(result.track.id, '42');
      expect(result.track.artworkId, 77);
      expect(result.track.uri.toString(), 'file:///music/song.mp3');
      expect(result.track.title, 'Song');
      expect(result.track.artist, 'Artist');
      expect(result.track.album, 'Album');
      expect(result.track.duration, const Duration(minutes: 3));
    });

    test('falls back to media item id as track id', () {
      final item = MediaItem(
        id: 'content://audio/123',
        title: 'Song',
        extras: const {
          'providerId': 'local',
          'artworkId': 77,
        },
      );

      final result = trackArtworkRequestFromMediaItem(item: item, sizePx: 96);

      expect(result, isNotNull);
      expect(result!.track.id, 'content://audio/123');
    });

    test('parses string artwork id', () {
      final item = MediaItem(
        id: 'file:///music/song.mp3',
        title: 'Song',
        extras: const {
          'providerId': 'local',
          'trackId': '42',
          'artworkId': '99',
        },
      );

      final result = trackArtworkRequestFromMediaItem(item: item, sizePx: 96);

      expect(result, isNotNull);
      expect(result!.track.artworkId, 99);
    });

    test('allows null artworkId when required identity fields exist', () {
      final item = MediaItem(
        id: 'file:///music/song.mp3',
        title: 'Song',
        extras: const {
          'providerId': 'local',
          'trackId': '42',
        },
      );

      final result = trackArtworkRequestFromMediaItem(item: item, sizePx: 160);

      expect(result, isNotNull);
      expect(result!.track.artworkId, isNull);
      expect(result.track.uri.toString(), 'file:///music/song.mp3');
    });

    test('returns null when providerId is missing', () {
      final item = MediaItem(
        id: 'file:///music/song.mp3',
        title: 'Song',
      );

      final result = trackArtworkRequestFromMediaItem(item: item, sizePx: 160);

      expect(result, isNull);
    });
  });
}
