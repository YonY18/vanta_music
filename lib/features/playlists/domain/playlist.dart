import '../../library/domain/track.dart';

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.tracks = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final List<Track> tracks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
