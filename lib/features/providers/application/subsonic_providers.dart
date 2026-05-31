import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../infrastructure/subsonic_api_client.dart';
import '../infrastructure/subsonic_music_provider.dart';
import '../infrastructure/subsonic_server_store.dart';
import '../../../shared/artwork_cache/file_artwork_cache_store.dart';

typedef SubsonicApiClientFactory =
    SubsonicApiClientContract Function({
      required SubsonicServerConfig server,
      required String password,
    });

final subsonicApiClientFactoryProvider = Provider<SubsonicApiClientFactory>(
  (ref) =>
      ({required server, required password}) =>
          SubsonicApiClient(server: server, password: password),
);

final subsonicServerStoreProvider = FutureProvider<SubsonicServerStore>((
  ref,
) async {
  final directory = await getApplicationSupportDirectory();
  return buildSubsonicServerStore(directory: directory);
});

final subsonicRemoteLibrarySnapshotStoreProvider =
    FutureProvider<RemoteLibrarySnapshotStore>((ref) async {
      final directory = await getApplicationSupportDirectory();
      return FileRemoteLibrarySnapshotStore(
        File('${directory.path}/subsonic_remote_library_cache.json'),
      );
    });

Future<SubsonicServerStore> buildSubsonicServerStore({
  required Directory directory,
  SubsonicSecretStore secretStore = const FlutterSecureSubsonicSecretStore(),
}) async {
  final snapshotStore = FileRemoteLibrarySnapshotStore(
    File('${directory.path}/subsonic_remote_library_cache.json'),
  );
  final artworkStore = FileArtworkCacheStore(
    appSupportDirectory: () async => directory,
  );
  return SubsonicServerStore(
    metadataStore: FileSubsonicServerMetadataStore(
      File('${directory.path}/subsonic_servers.json'),
    ),
    secretStore: secretStore,
    cleanupHooks: [
      RemoteLibrarySnapshotServerCleanup(snapshotStore),
      RemoteArtworkCacheServerCleanup(artworkStore),
    ],
  );
}

class RemoteLibrarySnapshotServerCleanup implements SubsonicServerCleanup {
  const RemoteLibrarySnapshotServerCleanup(this.snapshotStore);

  final RemoteLibrarySnapshotStore snapshotStore;

  @override
  Future<void> deleteServerData(String serverId) {
    return snapshotStore.deleteServer(serverId);
  }
}

class RemoteArtworkCacheServerCleanup implements SubsonicServerCleanup {
  const RemoteArtworkCacheServerCleanup(this.artworkStore);

  final ArtworkCacheStore artworkStore;

  @override
  Future<void> deleteServerData(String serverId) {
    return artworkStore.deleteServer(serverId);
  }
}
