import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/domain/track.dart';
import 'artwork_cache_resolver.dart';
import 'artwork_precache.dart';
import 'embedded_artwork_bytes_source_selector.dart';
import 'file_artwork_cache_store.dart';
import 'flac_embedded_artwork_extractor.dart';
import 'folder_artwork_bytes_source.dart';
import 'mp3_embedded_artwork_extractor.dart';

final artworkCacheStoreProvider = Provider<ArtworkCacheStore>(
  (ref) => FileArtworkCacheStore(),
);

final artworkBytesSourceProvider = Provider<ArtworkBytesSource>(
  (ref) => OnAudioQueryArtworkBytesSource(),
);

final remoteArtworkBytesSourceProvider = Provider<RemoteArtworkBytesSource>(
  (ref) => HttpRemoteArtworkBytesSource(),
);

final artworkCacheResolverProvider = Provider<ArtworkCacheResolver>((ref) {
  return ArtworkCacheResolver(
    store: ref.watch(artworkCacheStoreProvider),
    source: ref.watch(artworkBytesSourceProvider),
    embeddedSource: ref.watch(embeddedArtworkBytesSourceProvider),
    remoteSource: ref.watch(remoteArtworkBytesSourceProvider),
  );
});

final embeddedArtworkBytesSourceProvider = Provider<EmbeddedArtworkBytesSource>(
  (ref) => const EmbeddedArtworkBytesSourceSelector(
    mp3Source: Mp3EmbeddedArtworkExtractor(),
    flacSource: FlacEmbeddedArtworkExtractor(),
    folderSource: FolderArtworkBytesSource(),
  ),
);

class TrackArtworkRequest {
  const TrackArtworkRequest({required this.track, required this.sizePx});

  final Track track;
  final int sizePx;

  @override
  bool operator ==(Object other) {
    return other is TrackArtworkRequest &&
        other.sizePx == sizePx &&
        other.track.providerId == track.providerId &&
        other.track.id == track.id &&
        other.track.artworkId == track.artworkId &&
        other.track.uri == track.uri;
  }

  @override
  int get hashCode => Object.hash(
    track.providerId,
    track.id,
    track.artworkId,
    track.uri,
    sizePx,
  );
}

final trackArtworkPathProvider = FutureProvider.autoDispose
    .family<String?, TrackArtworkRequest>((ref, request) {
      return ref
          .watch(artworkCacheResolverProvider)
          .resolvePath(track: request.track, sizePx: request.sizePx);
    });

final artworkCacheWarmupServiceProvider = Provider<ArtworkCacheWarmupService>((
  ref,
) {
  return ArtworkCacheWarmupService(
    resolver: ref.watch(artworkCacheResolverProvider),
  );
});
