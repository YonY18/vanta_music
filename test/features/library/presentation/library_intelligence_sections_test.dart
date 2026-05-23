import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/library/presentation/library_intelligence_sections.dart';

void main() {
  group('buildVisibleIntelligenceSections', () {
    test('preserves section order when all primary groups are present', () {
      final sections = buildVisibleIntelligenceSections(
        continueListening: [_track('1')],
        recents: [_track('2')],
        mostPlayed: [_track('3')],
        favorites: const [],
      );

      expect(
        sections.map((section) => section.title),
        ['Continuar escuchando', 'Recientes', 'Más escuchadas'],
      );
    });

    test('keeps fixed order and hides empty sections', () {
      final sections = buildVisibleIntelligenceSections(
        continueListening: [_track('1')],
        recents: const [],
        mostPlayed: [_track('2')],
        favorites: const [],
      );

      expect(
        sections.map((section) => section.type),
        [
          IntelligenceSectionType.continueListening,
          IntelligenceSectionType.mostPlayed,
        ],
      );
      expect(
        sections.map((section) => section.title),
        ['Continuar escuchando', 'Más escuchadas'],
      );
    });

    test('bounds every section to top N', () {
      final manyTracks = List.generate(10, (index) => _track('$index'));

      final sections = buildVisibleIntelligenceSections(
        continueListening: manyTracks,
        recents: manyTracks,
        mostPlayed: manyTracks,
        favorites: manyTracks,
        topN: 3,
      );

      expect(sections, hasLength(4));
      expect(sections.every((section) => section.tracks.length == 3), isTrue);
      expect(sections.first.tracks.map((track) => track.id), ['0', '1', '2']);
    });
  });
}

Track _track(String id) {
  return Track(
    id: id,
    providerId: 'local',
    title: 'Track $id',
    artist: 'Artist',
    album: 'Album',
    uri: Uri.parse('content://song/$id'),
  );
}
