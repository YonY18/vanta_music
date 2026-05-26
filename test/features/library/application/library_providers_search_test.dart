import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_providers.dart';
import 'package:vanta_music/features/library/domain/track.dart';

void main() {
  test(
    'filteredTracksProvider recomputes by query over prepared tracks',
    () async {
      final tracks = [
        Track(
          id: '1',
          providerId: 'local',
          title: 'Night Train',
          artist: 'Vanta',
          album: 'Noir',
          uri: Uri.parse('file:///music/1.mp3'),
        ),
        Track(
          id: '2',
          providerId: 'local',
          title: 'Morning Sun',
          artist: 'Aurora',
          album: 'Dawn',
          uri: Uri.parse('file:///music/2.mp3'),
        ),
      ];

      final container = ProviderContainer(
        overrides: [tracksProvider.overrideWith((ref) async => tracks)],
      );
      addTearDown(container.dispose);

      await container.read(tracksProvider.future);

      final all = container.read(filteredTracksProvider(''));
      final filtered = container.read(filteredTracksProvider('vanta'));

      expect(all.length, 2);
      expect(filtered.length, 1);
      expect(filtered.single.id, '1');
    },
  );

  test('file validation cache invalidates entries explicitly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cache = container.read(fileValidationCacheProvider);

    final uri = Uri.parse('file:///music/cache.mp3');
    await cache.validate(uri);
    expect(cache.read(uri), isNotNull);

    cache.invalidateAll();
    expect(cache.read(uri), isNull);
  });
}
