import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_providers.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_music_provider.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_key.dart';
import 'package:vanta_music/shared/artwork_cache/file_artwork_cache_store.dart';

void main() {
  test(
    'buildSubsonicServerStore deletes snapshot and artwork for one server',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'subsonic-providers-test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final store = await buildSubsonicServerStore(
        directory: directory,
        secretStore: InMemorySubsonicSecretStore(),
      );
      final snapshotStore = FileRemoteLibrarySnapshotStore(
        File('${directory.path}/subsonic_remote_library_cache.json'),
      );
      final artworkStore = FileArtworkCacheStore(
        appSupportDirectory: () async => directory,
      );

      await store.saveServer(
        const SubsonicServerConfig(
          id: 'home',
          name: 'Home',
          baseUrl: 'https://music.example.com',
          username: 'alice',
        ),
        password: 'home-secret',
      );
      await store.saveServer(
        const SubsonicServerConfig(
          id: 'work',
          name: 'Work',
          baseUrl: 'https://work.example.com',
          username: 'bob',
        ),
        password: 'work-secret',
      );
      await snapshotStore.write(
        RemoteLibrarySnapshot(
          serverId: 'home',
          providerId: 'subsonic:home',
          tracks: const [],
          lastSyncAt: DateTime.utc(2026, 5, 31),
          isStale: false,
        ),
      );
      await snapshotStore.write(
        RemoteLibrarySnapshot(
          serverId: 'work',
          providerId: 'subsonic:work',
          tracks: const [],
          lastSyncAt: DateTime.utc(2026, 5, 31),
          isStale: false,
        ),
      );
      final homeArtworkKey = buildArtworkCacheKey(
        providerId: 'subsonic:home',
        trackId: 'song-1',
        artworkId: null,
        sizePx: 160,
        serverId: 'home',
        coverArtId: 'cover-1',
      );
      final workArtworkKey = buildArtworkCacheKey(
        providerId: 'subsonic:work',
        trackId: 'song-2',
        artworkId: null,
        sizePx: 160,
        serverId: 'work',
        coverArtId: 'cover-2',
      );
      await artworkStore.writeBytes(
        homeArtworkKey,
        Uint8List.fromList([1, 2, 3]),
      );
      await artworkStore.writeBytes(
        workArtworkKey,
        Uint8List.fromList([4, 5, 6]),
      );

      await store.deleteServer('home');

      expect(
        await snapshotStore.read(serverId: 'home', providerId: 'subsonic:home'),
        isNull,
      );
      expect(
        await snapshotStore.read(serverId: 'work', providerId: 'subsonic:work'),
        isNotNull,
      );
      expect(await artworkStore.readPath(homeArtworkKey), isNull);
      expect(await artworkStore.readPath(workArtworkKey), isNotNull);
    },
  );

  test(
    'savedSubsonicMusicProvider follows the selected active server',
    () async {
      final metadataStore = _MemorySubsonicMetadataStore();
      final secretStore = InMemorySubsonicSecretStore();
      final store = SubsonicServerStore(
        metadataStore: metadataStore,
        secretStore: secretStore,
      );
      await store.saveServer(
        const SubsonicServerConfig(
          id: 'home',
          name: 'Home',
          baseUrl: 'https://music.example.com',
          username: 'alice',
        ),
        password: 'home-secret',
      );
      await store.saveServer(
        const SubsonicServerConfig(
          id: 'work',
          name: 'Work',
          baseUrl: 'https://work.example.com',
          username: 'bob',
        ),
        password: 'work-secret',
      );
      await store.selectActiveServer('home');

      final container = ProviderContainer(
        overrides: [
          subsonicServerStoreProvider.overrideWith((ref) async => store),
          subsonicRemoteLibrarySnapshotStoreProvider.overrideWith(
            (ref) async => InMemoryRemoteLibrarySnapshotStore(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final homeProvider =
          await container.read(savedSubsonicMusicProvider.future)
              as SubsonicMusicProvider;
      expect(homeProvider.server.id, 'home');

      await store.selectActiveServer('work');
      container.invalidate(savedSubsonicMusicProvider);

      final workProvider =
          await container.read(savedSubsonicMusicProvider.future)
              as SubsonicMusicProvider;
      expect(workProvider.server.id, 'work');
    },
  );
}

class _MemorySubsonicMetadataStore implements SubsonicServerMetadataStore {
  SubsonicServerState _state = const SubsonicServerState();

  @override
  Future<SubsonicServerState> read() async => _state;

  @override
  Future<void> write(SubsonicServerState state) async {
    _state = state;
  }
}
