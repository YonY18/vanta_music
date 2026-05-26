const localProviderId = 'local';
const subsonicProviderPrefix = 'subsonic';

String subsonicProviderId(String serverId) {
  final normalized = serverId.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(serverId, 'serverId', 'must not be empty');
  }
  return '$subsonicProviderPrefix:$normalized';
}

String remoteItemId({required String serverId, required String itemId}) {
  final normalizedServerId = serverId.trim();
  final normalizedItemId = itemId.trim();
  if (normalizedServerId.isEmpty) {
    throw ArgumentError.value(serverId, 'serverId', 'must not be empty');
  }
  if (normalizedItemId.isEmpty) {
    throw ArgumentError.value(itemId, 'itemId', 'must not be empty');
  }
  return '$subsonicProviderPrefix:$normalizedServerId:$normalizedItemId';
}
