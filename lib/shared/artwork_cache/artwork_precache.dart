import '../../features/library/domain/track.dart';
import 'artwork_cache_resolver.dart';

const int defaultArtworkPrecacheLimit = 40;
const int defaultArtworkPrecacheSizePx = 160;
const int defaultArtworkPrecacheMaxConcurrency = 2;

List<Track> selectTracksForArtworkPrecache(
  List<Track> tracks, {
  int maxCount = defaultArtworkPrecacheLimit,
}) {
  if (maxCount <= 0 || tracks.isEmpty) return const <Track>[];

  final selected = <Track>[];
  for (final track in tracks) {
    final canResolveFromArtworkId = track.artworkId != null;
    final canResolveFromEmbedded = track.uri.isScheme('file');
    final canResolveFromRemote = hasRemoteArtwork(track);
    if (!canResolveFromArtworkId &&
        !canResolveFromEmbedded &&
        !canResolveFromRemote) {
      continue;
    }

    selected.add(track);
    if (selected.length >= maxCount) break;
  }

  return List<Track>.unmodifiable(selected);
}

List<Track> selectQueueTracksForArtworkPrecache({
  Track? nowPlaying,
  required List<Track> queue,
  int maxCount = defaultArtworkPrecacheLimit,
}) {
  if (maxCount <= 0) return const <Track>[];

  final ordered = <Track>[
    ...(nowPlaying == null ? const <Track>[] : <Track>[nowPlaying]),
    ...queue,
  ];
  final seen = <String>{};
  final deduped = <Track>[];
  for (final track in ordered) {
    final key = '${track.providerId}|${track.id}|${track.uri}';
    if (!seen.add(key)) continue;
    deduped.add(track);
  }
  return selectTracksForArtworkPrecache(deduped, maxCount: maxCount);
}

class ArtworkCacheWarmupService {
  const ArtworkCacheWarmupService({required this.resolver});

  final ArtworkCacheResolver resolver;

  Future<void> warmup(
    List<Track> tracks, {
    int maxCount = defaultArtworkPrecacheLimit,
    int sizePx = defaultArtworkPrecacheSizePx,
    int maxConcurrency = defaultArtworkPrecacheMaxConcurrency,
  }) async {
    final queue = selectTracksForArtworkPrecache(tracks, maxCount: maxCount);
    if (queue.isEmpty) return;

    final concurrency = maxConcurrency < 1 ? 1 : maxConcurrency;
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= queue.length) return;
        final current = queue[nextIndex];
        nextIndex += 1;

        try {
          await resolver.resolvePath(track: current, sizePx: sizePx);
        } catch (_) {
          // Warmup is best-effort and must never bubble to UI.
        }
      }
    }

    final workers = List<Future<void>>.generate(
      concurrency > queue.length ? queue.length : concurrency,
      (_) => worker(),
      growable: false,
    );

    await Future.wait(workers);
  }
}
