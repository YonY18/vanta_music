import '../../library/domain/track.dart';

class QueueItem {
  const QueueItem({required this.id, required this.track, required this.index});

  final String id;
  final Track track;
  final int index;
}
