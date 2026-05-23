import '../domain/track.dart';

const int intelligenceSectionTopN = 6;

enum IntelligenceSectionType {
  continueListening,
  recents,
  mostPlayed,
  favorites,
}

class IntelligenceSection {
  const IntelligenceSection({
    required this.type,
    required this.title,
    required this.tracks,
  });

  final IntelligenceSectionType type;
  final String title;
  final List<Track> tracks;
}

List<IntelligenceSection> buildVisibleIntelligenceSections({
  required List<Track> continueListening,
  required List<Track> recents,
  required List<Track> mostPlayed,
  required List<Track> favorites,
  int topN = intelligenceSectionTopN,
}) {
  List<Track> bounded(List<Track> tracks) =>
      tracks.take(topN).toList(growable: false);

  final sections = <IntelligenceSection>[
    IntelligenceSection(
      type: IntelligenceSectionType.continueListening,
      title: 'Continuar escuchando',
      tracks: bounded(continueListening),
    ),
    IntelligenceSection(
      type: IntelligenceSectionType.recents,
      title: 'Recientes',
      tracks: bounded(recents),
    ),
    IntelligenceSection(
      type: IntelligenceSectionType.mostPlayed,
      title: 'Más escuchadas',
      tracks: bounded(mostPlayed),
    ),
    IntelligenceSection(
      type: IntelligenceSectionType.favorites,
      title: 'Favoritos',
      tracks: bounded(favorites),
    ),
  ];

  return sections.where((section) => section.tracks.isNotEmpty).toList(growable: false);
}
