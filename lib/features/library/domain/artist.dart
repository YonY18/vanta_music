class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.trackCount,
    this.albumCount,
  });

  final String id;
  final String name;
  final int trackCount;
  final int? albumCount;
}
