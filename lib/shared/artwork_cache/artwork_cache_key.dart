class ArtworkCacheKey {
  const ArtworkCacheKey(this.raw);

  final String raw;
}

ArtworkCacheKey buildArtworkCacheKey({
  required String providerId,
  required String trackId,
  required int? artworkId,
  required int sizePx,
  String? sourceUri,
  String? serverId,
  String? coverArtId,
}) {
  if (serverId != null &&
      serverId.isNotEmpty &&
      coverArtId != null &&
      coverArtId.isNotEmpty) {
    return ArtworkCacheKey('subsonic|$serverId|$coverArtId|$sizePx');
  }
  final sourceKey = artworkId != null
      ? artworkId.toString()
      : 'src:${sourceUri ?? ''}';
  return ArtworkCacheKey('$providerId|$trackId|$sourceKey|$sizePx');
}

String artworkCacheFileName(ArtworkCacheKey key) {
  return 'artwork_${_fnv1a64Hex(key.raw)}.jpg';
}

String _fnv1a64Hex(String value) {
  const offsetBasis = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  const mask = 0xFFFFFFFFFFFFFFFF;

  var hash = offsetBasis;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * prime) & mask;
  }

  return hash.toRadixString(16).padLeft(16, '0');
}
