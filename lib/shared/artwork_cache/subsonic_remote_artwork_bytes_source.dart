import 'dart:typed_data';

import '../../features/providers/application/subsonic_providers.dart';
import '../../features/providers/infrastructure/subsonic_server_store.dart';
import 'artwork_cache_resolver.dart';

class SubsonicRemoteArtworkBytesSource implements RemoteArtworkBytesSource {
  SubsonicRemoteArtworkBytesSource({
    required this.storeLoader,
    required this.clientFactory,
    RemoteArtworkBytesSource? httpSource,
  }) : _httpSource = httpSource ?? HttpRemoteArtworkBytesSource();

  final Future<SubsonicServerStore> Function() storeLoader;
  final SubsonicApiClientFactory clientFactory;
  final RemoteArtworkBytesSource _httpSource;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    if (uri.isScheme('http') || uri.isScheme('https')) {
      return _httpSource.fetch(uri: uri, sizePx: sizePx);
    }
    if (!uri.isScheme('subsonic') || uri.host != 'cover-art') return null;

    final serverId = uri.queryParameters['serverId'];
    final coverArtId = uri.queryParameters['id'];
    if (serverId == null ||
        serverId.isEmpty ||
        coverArtId == null ||
        coverArtId.isEmpty) {
      return null;
    }

    final store = await storeLoader();
    final server = (await store.loadServers())
        .where((server) => server.id == serverId)
        .firstOrNull;
    if (server == null) return null;

    final password = await store.readPassword(server.id);
    if (password == null || password.isEmpty) return null;

    final coverUri = clientFactory(
      server: server,
      password: password,
    ).getCoverArtUri(coverArtId);
    return _httpSource.fetch(uri: coverUri, sizePx: sizePx);
  }
}
