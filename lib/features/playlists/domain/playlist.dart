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

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    List<Track>? tracks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Playlist &&
            other.id == id &&
            other.name == name &&
            other.description == description &&
            _sameTrackIds(other.tracks, tracks) &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    Object.hashAll(tracks.map((track) => track.id)),
    createdAt,
    updatedAt,
  );
}

bool _sameTrackIds(List<Track> left, List<Track> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].id != right[index].id) return false;
  }
  return true;
}
