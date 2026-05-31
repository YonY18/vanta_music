import 'package:audio_service/audio_service.dart';

import '../../providers/application/subsonic_providers.dart';
import '../../providers/domain/provider_identity.dart';
import '../../providers/infrastructure/subsonic_api_client.dart';
import '../../providers/infrastructure/subsonic_server_store.dart';
import '../infrastructure/vanta_audio_handler.dart';

class SubsonicStreamResolverRegistry implements StreamResolverRegistry {
  const SubsonicStreamResolverRegistry({
    required this.store,
    required this.clientFactory,
  });

  final SubsonicServerStore store;
  final SubsonicApiClientFactory clientFactory;

  @override
  Future<Uri> resolve(MediaItem item) async {
    final canonical = _tryParseNonEmpty(item.extras?['canonicalUri']);
    final itemUri = Uri.tryParse(item.id);
    final subsonicUri = canonical?.isScheme('subsonic') == true
        ? canonical
        : itemUri?.isScheme('subsonic') == true
        ? itemUri
        : null;

    if (subsonicUri == null) {
      if (_isSubsonicProvider(item)) {
        throw StateError(
          'Cannot resolve Subsonic stream: missing canonical Subsonic URI.',
        );
      }
      return Uri.parse(item.id);
    }

    final serverId = _serverId(item, subsonicUri);
    final songId = subsonicUri.queryParameters['id'];
    if (serverId == null) {
      throw StateError('Cannot resolve Subsonic stream: missing server id.');
    }
    if (songId == null || songId.isEmpty) {
      throw StateError('Cannot resolve Subsonic stream: missing song id.');
    }

    final server = (await store.loadServers())
        .where((server) => server.id == serverId)
        .firstOrNull;
    if (server == null) {
      throw StateError('Cannot resolve Subsonic stream: server not found.');
    }

    final password = await store.readPassword(server.id);
    if (password == null || password.isEmpty) {
      throw StateError('Cannot resolve Subsonic stream: missing password.');
    }

    try {
      return clientFactory(
        server: server,
        password: password,
      ).streamUri(songId);
    } on SubsonicFailure catch (error) {
      throw RemoteTrackResolveException.fromSubsonicFailure(
        item: item,
        error: error,
      );
    }
  }
}

bool _isSubsonicProvider(MediaItem item) {
  final providerId = item.extras?['providerId']?.toString();
  return providerId?.startsWith('$subsonicProviderPrefix:') ?? false;
}

Uri? _tryParseNonEmpty(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return Uri.tryParse(text);
}

String? _serverId(MediaItem item, Uri canonical) {
  final uriServerId = canonical.queryParameters['serverId'];
  if (uriServerId != null && uriServerId.isNotEmpty) return uriServerId;

  final providerId = item.extras?['providerId']?.toString();
  if (providerId == null ||
      !providerId.startsWith('$subsonicProviderPrefix:')) {
    return null;
  }
  return providerId.substring('$subsonicProviderPrefix:'.length);
}
