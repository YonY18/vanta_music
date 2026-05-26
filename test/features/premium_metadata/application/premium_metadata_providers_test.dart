import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_providers.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/premium_metadata/application/premium_metadata_providers.dart';
import 'package:vanta_music/features/premium_metadata/domain/metadata_models.dart';

void main() {
  test(
    'exposes source metadata placeholder before async override resolves',
    () async {
      final track = _track(id: '42', title: 'Source Title');
      final store = _FakeOverrideStore(
        delay: const Duration(milliseconds: 10),
        overrides: {
          buildTrackKey(track): const MetadataOverride(title: 'Local Title'),
        },
      );
      final container = ProviderContainer(
        overrides: [metadataOverrideStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final placeholder = container.read(
        trackMetadataPlaceholderProvider(track),
      );
      final loading = container.read(resolvedTrackMetadataProvider(track));
      final resolved = await container.read(
        resolvedTrackMetadataProvider(track).future,
      );

      expect(placeholder.title, 'Source Title');
      expect(placeholder.canonicalTrackId, '42');
      expect(loading.isLoading, isTrue);
      expect(resolved.title, 'Local Title');
      expect(resolved.canonicalTrackId, '42');
      expect(resolved.canonicalProviderId, 'local');
    },
  );

  test(
    'library display metadata wiring keeps tracksProvider identity unchanged',
    () async {
      final track = _track(id: '7', title: 'Source Title');
      final container = ProviderContainer(
        overrides: [
          tracksProvider.overrideWith((ref) async => [track]),
          metadataOverrideStoreProvider.overrideWithValue(
            _FakeOverrideStore(
              overrides: {
                buildTrackKey(track): const MetadataOverride(
                  title: 'Display Title',
                ),
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final tracks = await container.read(tracksProvider.future);
      final display = await container.read(
        libraryTrackDisplayMetadataProvider(track).future,
      );

      expect(identical(tracks.single, track), isTrue);
      expect(tracks.single.title, 'Source Title');
      expect(display.title, 'Display Title');
      expect(display.canonicalTrackId, track.id);
    },
  );

  test(
    'artist enrichment returns empty local contract without network provider',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final enrichment = await container.read(
        artistEnrichmentProvider('artist::vanta').future,
      );

      expect(enrichment.artistKey, 'artist::vanta');
      expect(enrichment.isEmpty, isTrue);
      expect(enrichment.biography, isNull);
      expect(enrichment.artworkPath, isNull);
    },
  );
}

Track _track({required String id, required String title}) {
  return Track(
    id: id,
    providerId: 'local',
    title: title,
    artist: 'Source Artist',
    album: 'Source Album',
    uri: Uri.file('/music/$id.mp3'),
  );
}

class _FakeOverrideStore implements MetadataOverrideStore {
  _FakeOverrideStore({this.overrides = const {}, this.delay = Duration.zero});

  final Map<String, MetadataOverride> overrides;
  final Duration delay;

  @override
  Future<MetadataOverride?> loadOverride(String trackKey) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return overrides[trackKey];
  }

  @override
  Future<void> saveOverride(String trackKey, MetadataOverride override) async {}

  @override
  Future<void> clearOverride(String trackKey) async {}
}
