import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/track.dart';
import '../domain/metadata_models.dart';
import '../infrastructure/file_metadata_override_store.dart';

abstract class MetadataOverrideStore {
  Future<MetadataOverride?> loadOverride(String trackKey);
  Future<void> saveOverride(String trackKey, MetadataOverride override);
  Future<void> clearOverride(String trackKey);
}

final metadataOverrideStoreProvider = Provider<MetadataOverrideStore>((ref) {
  return _FileMetadataOverrideStoreAdapter(FileMetadataOverrideStore());
});

final trackMetadataPlaceholderProvider =
    Provider.family<ResolvedTrackMetadata, Track>((ref, track) {
      return ResolvedTrackMetadata.fromTrack(track);
    });

final resolvedTrackMetadataProvider =
    FutureProvider.family<ResolvedTrackMetadata, Track>((ref, track) async {
      final store = ref.watch(metadataOverrideStoreProvider);
      final override = await store.loadOverride(buildTrackKey(track));
      return ResolvedTrackMetadata.fromTrack(track, override: override);
    });

final resolvedTrackMetadataRequestProvider =
    FutureProvider.family<ResolvedTrackMetadata, TrackMetadataRequest>((
      ref,
      request,
    ) async {
      final store = ref.watch(metadataOverrideStoreProvider);
      final override = await store.loadOverride(request.trackKey);
      return request.resolve(override: override);
    });

final artistEnrichmentProvider =
    FutureProvider.family<ArtistEnrichment, String>(
      (ref, artistKey) async => ArtistEnrichment.empty(artistKey),
    );

class _FileMetadataOverrideStoreAdapter implements MetadataOverrideStore {
  const _FileMetadataOverrideStoreAdapter(this._store);

  final FileMetadataOverrideStore _store;

  @override
  Future<MetadataOverride?> loadOverride(String trackKey) {
    return _store.loadOverride(trackKey);
  }

  @override
  Future<void> saveOverride(String trackKey, MetadataOverride override) {
    return _store.saveOverride(trackKey, override);
  }

  @override
  Future<void> clearOverride(String trackKey) {
    return _store.clearOverride(trackKey);
  }
}

class TrackMetadataRequest {
  const TrackMetadataRequest({
    required this.trackKey,
    required this.canonicalTrackId,
    required this.canonicalProviderId,
    required this.title,
    required this.artist,
    required this.album,
  });

  factory TrackMetadataRequest.fromTrack(Track track) {
    return TrackMetadataRequest(
      trackKey: buildTrackKey(track),
      canonicalTrackId: track.id,
      canonicalProviderId: track.providerId,
      title: track.title,
      artist: track.artist,
      album: track.album,
    );
  }

  final String trackKey;
  final String canonicalTrackId;
  final String canonicalProviderId;
  final String title;
  final String artist;
  final String album;

  ResolvedTrackMetadata resolve({MetadataOverride? override}) {
    return ResolvedTrackMetadata(
      trackKey: trackKey,
      canonicalTrackId: canonicalTrackId,
      canonicalProviderId: canonicalProviderId,
      title: _overrideValue(override?.title) ?? title,
      artist: _overrideValue(override?.artist) ?? artist,
      album: _overrideValue(override?.album) ?? album,
      hasOverride: override != null && !override.isEmpty,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TrackMetadataRequest &&
        other.trackKey == trackKey &&
        other.canonicalTrackId == canonicalTrackId &&
        other.canonicalProviderId == canonicalProviderId &&
        other.title == title &&
        other.artist == artist &&
        other.album == album;
  }

  @override
  int get hashCode => Object.hash(
    trackKey,
    canonicalTrackId,
    canonicalProviderId,
    title,
    artist,
    album,
  );
}

String? _overrideValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
