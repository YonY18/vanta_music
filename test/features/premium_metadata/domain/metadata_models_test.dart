import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/premium_metadata/domain/metadata_models.dart';

void main() {
  group('ResolvedTrackMetadata', () {
    test('uses source metadata when no local override exists', () {
      final track = _track(
        id: '42',
        providerId: 'local',
        title: 'Source Title',
        artist: 'Source Artist',
        album: 'Source Album',
      );

      final resolved = ResolvedTrackMetadata.fromTrack(track);

      expect(resolved.trackKey, 'local::42');
      expect(resolved.title, 'Source Title');
      expect(resolved.artist, 'Source Artist');
      expect(resolved.album, 'Source Album');
      expect(resolved.canonicalTrackId, '42');
      expect(resolved.canonicalProviderId, 'local');
      expect(resolved.hasOverride, isFalse);
    });

    test(
      'merges non-empty override fields without changing canonical identity',
      () {
        final track = _track(
          id: '7',
          providerId: 'folder',
          title: 'Source Title',
          artist: 'Source Artist',
          album: 'Source Album',
        );
        const override = MetadataOverride(
          title: 'Local Title',
          artist: 'Local Artist',
        );

        final resolved = ResolvedTrackMetadata.fromTrack(
          track,
          override: override,
        );

        expect(resolved.trackKey, 'folder::7');
        expect(resolved.title, 'Local Title');
        expect(resolved.artist, 'Local Artist');
        expect(resolved.album, 'Source Album');
        expect(resolved.canonicalTrackId, '7');
        expect(resolved.canonicalProviderId, 'folder');
        expect(resolved.hasOverride, isTrue);
      },
    );

    test('reverting an override returns source metadata', () {
      final track = _track(
        id: '99',
        providerId: 'local',
        title: 'Original Title',
        artist: 'Original Artist',
        album: 'Original Album',
      );
      const override = MetadataOverride(title: 'Temporary Title');

      final overridden = ResolvedTrackMetadata.fromTrack(
        track,
        override: override,
      );
      final reverted = overridden.revertToSource(track);

      expect(overridden.title, 'Temporary Title');
      expect(reverted.title, 'Original Title');
      expect(reverted.artist, 'Original Artist');
      expect(reverted.album, 'Original Album');
      expect(reverted.trackKey, overridden.trackKey);
      expect(reverted.hasOverride, isFalse);
    });
  });

  test('metadata override serializes only meaningful fields', () {
    const override = MetadataOverride(
      title: 'Song',
      artist: '',
      album: 'Album',
    );

    final json = override.toJson();
    final restored = MetadataOverride.fromJson(json);

    expect(json, {'title': 'Song', 'album': 'Album'});
    expect(restored.title, 'Song');
    expect(restored.artist, isNull);
    expect(restored.album, 'Album');
  });

  test(
    'artist enrichment exposes empty local contract without provider data',
    () {
      const enrichment = ArtistEnrichment.empty('artist::vanta');

      expect(enrichment.artistKey, 'artist::vanta');
      expect(enrichment.biography, isNull);
      expect(enrichment.artworkPath, isNull);
      expect(enrichment.isEmpty, isTrue);
    },
  );
}

Track _track({
  required String id,
  required String providerId,
  required String title,
  required String artist,
  required String album,
}) {
  return Track(
    id: id,
    providerId: providerId,
    title: title,
    artist: artist,
    album: album,
    uri: Uri.file('/music/$id.mp3'),
  );
}
