import '../../library/domain/track.dart';

String buildTrackKey(Track track) => '${track.providerId}::${track.id}';

class MetadataOverride {
  const MetadataOverride({this.title, this.artist, this.album});

  final String? title;
  final String? artist;
  final String? album;

  bool get isEmpty =>
      _normalized(title) == null &&
      _normalized(artist) == null &&
      _normalized(album) == null;

  Map<String, dynamic> toJson() {
    final normalizedTitle = _normalized(title);
    final normalizedArtist = _normalized(artist);
    final normalizedAlbum = _normalized(album);
    final json = <String, dynamic>{};
    if (normalizedTitle != null) json['title'] = normalizedTitle;
    if (normalizedArtist != null) json['artist'] = normalizedArtist;
    if (normalizedAlbum != null) json['album'] = normalizedAlbum;
    return json;
  }

  factory MetadataOverride.fromJson(Map<String, dynamic> json) {
    return MetadataOverride(
      title: _jsonString(json['title']),
      artist: _jsonString(json['artist']),
      album: _jsonString(json['album']),
    );
  }
}

class ResolvedTrackMetadata {
  const ResolvedTrackMetadata({
    required this.trackKey,
    required this.canonicalTrackId,
    required this.canonicalProviderId,
    required this.title,
    required this.artist,
    required this.album,
    required this.hasOverride,
  });

  final String trackKey;
  final String canonicalTrackId;
  final String canonicalProviderId;
  final String title;
  final String artist;
  final String album;
  final bool hasOverride;

  factory ResolvedTrackMetadata.fromTrack(
    Track track, {
    MetadataOverride? override,
  }) {
    return ResolvedTrackMetadata(
      trackKey: buildTrackKey(track),
      canonicalTrackId: track.id,
      canonicalProviderId: track.providerId,
      title: _normalized(override?.title) ?? track.title,
      artist: _normalized(override?.artist) ?? track.artist,
      album: _normalized(override?.album) ?? track.album,
      hasOverride: override != null && !override.isEmpty,
    );
  }

  ResolvedTrackMetadata revertToSource(Track track) {
    return ResolvedTrackMetadata.fromTrack(track);
  }
}

class ArtworkResolution {
  const ArtworkResolution({
    required this.key,
    this.path,
    this.isFallback = false,
    this.resolvedAt,
  });

  final String key;
  final String? path;
  final bool isFallback;
  final DateTime? resolvedAt;

  bool get hasArtwork => _normalized(path) != null;

  Map<String, dynamic> toJson() {
    final normalizedPath = _normalized(path);
    final resolvedAtValue = resolvedAt?.toIso8601String();
    final json = <String, dynamic>{'key': key, 'isFallback': isFallback};
    if (normalizedPath != null) json['path'] = normalizedPath;
    if (resolvedAtValue != null) json['resolvedAt'] = resolvedAtValue;
    return json;
  }

  factory ArtworkResolution.fromJson(Map<String, dynamic> json) {
    return ArtworkResolution(
      key: _jsonString(json['key']) ?? '',
      path: _jsonString(json['path']),
      isFallback: json['isFallback'] == true,
      resolvedAt: DateTime.tryParse(_jsonString(json['resolvedAt']) ?? ''),
    );
  }
}

class ArtworkPalette {
  const ArtworkPalette({required this.dominantColor, this.accentColor});

  final int dominantColor;
  final int? accentColor;

  Map<String, dynamic> toJson() {
    return {
      'dominantColor': dominantColor,
      if (accentColor != null) 'accentColor': accentColor,
    };
  }

  factory ArtworkPalette.fromJson(Map<String, dynamic> json) {
    return ArtworkPalette(
      dominantColor: _jsonInt(json['dominantColor']) ?? 0,
      accentColor: _jsonInt(json['accentColor']),
    );
  }
}

class ArtistEnrichment {
  const ArtistEnrichment({
    required this.artistKey,
    this.biography,
    this.artworkPath,
  });

  const ArtistEnrichment.empty(String artistKey) : this(artistKey: artistKey);

  final String artistKey;
  final String? biography;
  final String? artworkPath;

  bool get isEmpty =>
      _normalized(biography) == null && _normalized(artworkPath) == null;
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? _jsonString(Object? value) {
  if (value is! String) return null;
  return _normalized(value);
}

int? _jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
