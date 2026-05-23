class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.trackCount,
    this.artworkId,
  });

  final String id;
  final String title;
  final String artist;
  final int trackCount;
  final int? artworkId;
}
