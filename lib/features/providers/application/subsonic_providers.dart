import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../downloads/infrastructure/download_database.dart';
import '../../downloads/infrastructure/file_download_storage.dart';
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
  DownloadDatabase? downloadDatabase,
  FileDownloadStorage? downloadStorage,
}) async {
  final snapshotStore = FileRemoteLibrarySnapshotStore(
    File('${directory.path}/subsonic_remote_library_cache.json'),
  );
  final artworkStore = FileArtworkCacheStore(
    appSupportDirectory: () async => directory,
  );
  final offlineDownloadDatabase =
      downloadDatabase ??
      DownloadDatabase.sharedFile(File('${directory.path}/downloads.sqlite'));
  final offlineDownloadStorage =
      downloadStorage ??
      FileDownloadStorage(appSupportDirectory: () async => directory);
  return SubsonicServerStore(
    metadataStore: FileSubsonicServerMetadataStore(
      File('${directory.path}/subsonic_servers.json'),
    ),
    secretStore: secretStore,
    cleanupHooks: [
      RemoteLibrarySnapshotServerCleanup(snapshotStore),
      RemoteArtworkCacheServerCleanup(artworkStore),
      OfflineDownloadServerCleanup(
        downloadDatabase: offlineDownloadDatabase,
        downloadStorage: offlineDownloadStorage,
      ),
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

class OfflineDownloadServerCleanup implements SubsonicServerCleanup {
  const OfflineDownloadServerCleanup({
    required this.downloadDatabase,
    required this.downloadStorage,
  });

  final DownloadDatabase downloadDatabase;
  final FileDownloadStorage downloadStorage;

  @override
  Future<void> deleteServerData(String serverId) async {
    final downloads = await downloadDatabase.findByServer(
      serverId,
      providerFamily: 'subsonic',
    );
    for (final item in downloads) {
      await downloadStorage.deleteArtifacts(
        finalRelativePath: item.localRelativePath,
        tempRelativePath: item.tempRelativePath,
      );
      await downloadDatabase.deleteDownload(item.downloadKey);
    }
  }
}
