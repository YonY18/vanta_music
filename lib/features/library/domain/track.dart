class Track {
  const Track({
    required this.id,
    required this.providerId,
    required this.title,
    required this.artist,
    required this.album,
    required this.uri,
    this.albumId,
    this.artistId,
    this.duration,
    this.artworkId,
  });

  final String id;
  final String providerId;
  final String title;
  final String artist;
  final String album;
  final Uri uri;
  final String? albumId;
  final String? artistId;
  final Duration? duration;
  final int? artworkId;
}
