import '../../providers/domain/provider_identity.dart';

class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.trackCount,
    this.providerId = localProviderId,
    this.albumCount,
  });

  final String id;
  final String providerId;
  final String name;
  final int trackCount;
  final int? albumCount;
}
