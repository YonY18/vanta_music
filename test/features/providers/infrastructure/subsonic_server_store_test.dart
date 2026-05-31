import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';

void main() {
  test('saves multiple servers and secrets by stable server id only', () async {
    final metadataFile = File(
      '${Directory.systemTemp.createTempSync().path}/servers.json',
    );
    final secrets = InMemorySubsonicSecretStore();
    final store = SubsonicServerStore(
      metadataStore: FileSubsonicServerMetadataStore(metadataFile),
      secretStore: secrets,
    );

    await store.saveServer(
      const SubsonicServerConfig(
        id: 'home',
        name: 'Home Navidrome',
        baseUrl: 'https://music.example.test/',
        username: 'alice',
      ),
      password: 'home-secret',
    );
    await store.saveServer(
      const SubsonicServerConfig(
        id: 'studio',
        name: 'Studio',
        baseUrl: 'https://studio.example.test',
        username: 'bob',
      ),
      password: 'studio-secret',
    );

    final servers = await store.loadServers();

    expect(servers.map((server) => server.id), ['home', 'studio']);
    expect(await store.readPassword('home'), 'home-secret');
    expect(await store.readPassword('studio'), 'studio-secret');
    expect(await store.readPassword('missing'), isNull);

    final persisted = await metadataFile.readAsString();
    expect(persisted, contains('Home Navidrome'));
    expect(persisted, contains('alice'));
    expect(persisted, isNot(contains('home-secret')));
    expect(persisted, isNot(contains('studio-secret')));
  });

  test(
    'edits metadata without changing id and deletes active server secrets',
    () async {
      final metadataFile = File(
        '${Directory.systemTemp.createTempSync().path}/servers.json',
      );
      final store = SubsonicServerStore(
        metadataStore: FileSubsonicServerMetadataStore(metadataFile),
        secretStore: InMemorySubsonicSecretStore(),
      );

      await store.saveServer(
        const SubsonicServerConfig(
          id: 'home',
          name: 'Home',
          baseUrl: 'https://music.example.test',
          username: 'alice',
        ),
        password: 'first-secret',
      );
      await store.selectActiveServer('home');
      await store.saveServer(
        const SubsonicServerConfig(
          id: 'home',
          name: 'Home Renamed',
          baseUrl: 'https://music-renamed.example.test',
          username: 'alice',
        ),
      );

      expect((await store.loadServers()).single.name, 'Home Renamed');
      expect((await store.loadServers()).single.id, 'home');
      expect(await store.readPassword('home'), 'first-secret');
      expect(await store.readActiveServer(), 'home');

      await store.deleteServer('home');

      expect(await store.loadServers(), isEmpty);
      expect(await store.readPassword('home'), isNull);
      expect(await store.readActiveServer(), isNull);
    },
  );

  test('switches active server and loads the active config', () async {
    final metadataFile = File(
      '${Directory.systemTemp.createTempSync().path}/servers.json',
    );
    final store = SubsonicServerStore(
      metadataStore: FileSubsonicServerMetadataStore(metadataFile),
      secretStore: InMemorySubsonicSecretStore(),
    );

    await store.saveServer(
      const SubsonicServerConfig(
        id: 'home',
        name: 'Home',
        baseUrl: 'https://music.example.test',
        username: 'alice',
      ),
      password: 'home-secret',
    );
    await store.saveServer(
      const SubsonicServerConfig(
        id: 'studio',
        name: 'Studio',
        baseUrl: 'https://studio.example.test',
        username: 'bob',
      ),
      password: 'studio-secret',
    );

    await store.selectActiveServer('home');
    expect((await store.loadActiveServer())?.id, 'home');

    await store.selectActiveServer('studio');

    final active = await store.loadActiveServer();
    expect(active?.id, 'studio');
    expect(active?.name, 'Studio');
    expect(await store.readPassword('home'), 'home-secret');
    expect(await store.readPassword('studio'), 'studio-secret');
  });

  test('deletes one server and only cleans up that server data', () async {
    final metadataFile = File(
      '${Directory.systemTemp.createTempSync().path}/servers.json',
    );
    final secrets = InMemorySubsonicSecretStore();
    final cleanup = _RecordingServerCleanup();
    final store = SubsonicServerStore(
      metadataStore: FileSubsonicServerMetadataStore(metadataFile),
      secretStore: secrets,
      cleanupHooks: [cleanup],
    );

    await store.saveServer(
      const SubsonicServerConfig(
        id: 'home',
        name: 'Home',
        baseUrl: 'https://music.example.test',
        username: 'alice',
      ),
      password: 'home-secret',
    );
    await store.saveServer(
      const SubsonicServerConfig(
        id: 'studio',
        name: 'Studio',
        baseUrl: 'https://studio.example.test',
        username: 'bob',
      ),
      password: 'studio-secret',
    );
    await store.selectActiveServer('studio');

    await store.deleteServer('home');

    final servers = await store.loadServers();
    expect(servers.map((server) => server.id), ['studio']);
    expect(await store.readActiveServer(), 'studio');
    expect(await store.readPassword('home'), isNull);
    expect(await store.readPassword('studio'), 'studio-secret');
    expect(cleanup.deletedServerIds, ['home']);
  });

  test(
    'persists metadata as JSON with normalized base URLs and no secret fields',
    () async {
      final metadataFile = File(
        '${Directory.systemTemp.createTempSync().path}/servers.json',
      );
      final store = SubsonicServerStore(
        metadataStore: FileSubsonicServerMetadataStore(metadataFile),
        secretStore: InMemorySubsonicSecretStore(),
      );

      await store.saveServer(
        const SubsonicServerConfig(
          id: 'remote',
          name: 'Remote',
          baseUrl: 'https://remote.example.test///',
          username: 'carol',
          apiVersion: '1.16.1',
        ),
        password: 'remote-secret',
      );

      final decoded =
          jsonDecode(await metadataFile.readAsString()) as Map<String, Object?>;
      final servers = decoded['servers'] as List<Object?>;
      final server = servers.single as Map<String, Object?>;

      expect(server, {
        'id': 'remote',
        'name': 'Remote',
        'baseUrl': 'https://remote.example.test',
        'username': 'carol',
        'apiVersion': '1.16.1',
      });
      expect(decoded['activeServerId'], isNull);
      expect(server.containsKey('password'), isFalse);
      expect(server.containsKey('token'), isFalse);
      expect(server.containsKey('salt'), isFalse);
    },
  );
}

class _RecordingServerCleanup implements SubsonicServerCleanup {
  final List<String> deletedServerIds = <String>[];

  @override
  Future<void> deleteServerData(String serverId) async {
    deletedServerIds.add(serverId);
  }
}
