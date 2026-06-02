import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:vanta_music/app/router.dart';
import 'package:vanta_music/features/library/application/library_providers.dart';
import 'package:vanta_music/features/downloads/application/download_providers.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/library/domain/album.dart';
import 'package:vanta_music/features/library/domain/artist.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/library/presentation/library_screen.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_providers.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_refresh.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_snapshot.dart';
import 'package:vanta_music/features/premium_metadata/application/premium_metadata_providers.dart';
import 'package:vanta_music/features/premium_metadata/domain/metadata_models.dart';
import 'package:vanta_music/features/playlists/application/playlists_controller.dart';
import 'package:vanta_music/features/playlists/domain/playlist.dart';
import 'package:vanta_music/features/playlists/infrastructure/local_playlist_store.dart';
import 'package:vanta_music/features/providers/domain/music_provider.dart';
import 'package:vanta_music/features/providers/domain/stream_uri.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_api_client.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_music_provider.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_key.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_providers.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_resolver.dart';
import 'package:vanta_music/shared/artwork_cache/file_artwork_cache_store.dart';

void main() {
  testWidgets('renders bounded local stats cards on the home tab', (
    tester,
  ) async {
    await tester.pumpLibraryScreen(
      tracks: [
        _track('1', album: 'Night', artist: 'Vanta', durationSeconds: 180),
        _track('2', album: 'Night', artist: 'Vanta', durationSeconds: 240),
        _track('3', album: 'Dawn', artist: 'Echo', durationSeconds: 60),
      ],
      snapshot: LibrarySnapshot(
        schemaVersion: 1,
        tracks: {
          'local::1': _snapshot('local::1', playCount: 4),
          'local::2': _snapshot('local::2', playCount: 2),
          'local::3': _snapshot('local::3', playCount: 1),
        },
      ),
    );

    expect(find.text('Library stats'), findsOneWidget);
    expect(find.text('3 songs'), findsOneWidget);
    expect(find.text('2 albums'), findsOneWidget);
    expect(find.text('2 artists'), findsOneWidget);
    expect(find.text('8 min'), findsOneWidget);
  });

  testWidgets('opens playlist detail from the playlists tab', (tester) async {
    final playlist = Playlist(
      id: 'p1',
      name: 'Night Drive',
      tracks: [_track('1', title: 'Midnight Road')],
    );

    await tester.pumpLibraryScreen(playlists: [playlist]);

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night Drive'));
    await tester.pumpAndSettle();

    expect(find.text('Night Drive'), findsWidgets);
    expect(find.text('1 song'), findsOneWidget);
    expect(find.text('Midnight Road'), findsOneWidget);
  });

  testWidgets('shows explicit smart-section and premium empty states', (
    tester,
  ) async {
    await tester.pumpLibraryScreen(tracks: [_track('1')]);

    expect(find.text('Smart library warming up'), findsOneWidget);
    expect(
      find.text(
        'Play local tracks to unlock recent, favorite, and most-played sections.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cloud sync coming soon'), findsOneWidget);
  });

  testWidgets('renders source metadata first, then local display override', (
    tester,
  ) async {
    final track = _track('1', title: 'Source Title', artist: 'Source Artist');
    final store = _ControlledMetadataOverrideStore();

    await tester.pumpLibraryScreen(
      tracks: [track],
      overrideStore: store,
      settle: false,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Library'));
    await tester.pumpAndSettle();

    expect(find.text('Source Title'), findsOneWidget);
    expect(find.text('Source Artist • Album'), findsOneWidget);

    store.complete(
      const MetadataOverride(title: 'Display Title', artist: 'Display Artist'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Display Title'), findsOneWidget);
    expect(find.text('Display Artist • Album'), findsOneWidget);
  });

  testWidgets('keeps artwork placeholder while cache path is still loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tracksProvider.overrideWith(
            (ref) async => [_track('1', artworkId: 7)],
          ),
          artworkCacheResolverProvider.overrideWithValue(
            _PendingArtworkResolver(),
          ),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Library'));
    await tester.pump();

    expect(find.byType(QueryArtworkWidget), findsNothing);
  });

  testWidgets('keeps stats based on canonical metadata under local override', (
    tester,
  ) async {
    final track = _track(
      '1',
      artist: 'Canonical Artist',
      album: 'Canonical Album',
    );

    await tester.pumpLibraryScreen(
      tracks: [track],
      snapshot: LibrarySnapshot(
        schemaVersion: 1,
        tracks: {'local::1': _snapshot('local::1', playCount: 3)},
      ),
      overrideStore: _MemoryMetadataOverrideStore(
        overrides: {
          buildTrackKey(track): const MetadataOverride(
            artist: 'Display Artist',
            album: 'Display Album',
          ),
        },
      ),
    );

    expect(find.text('1 song'), findsOneWidget);
    expect(find.text('1 album'), findsOneWidget);
    expect(find.text('1 artist'), findsOneWidget);
  });

  testWidgets(
    'renders remote library in a separate surface from local home sections',
    (tester) async {
      final localTrack = _track('1', title: 'Local Only');
      final remoteTrack = _track(
        'remote-1',
        title: 'Remote Only',
        providerId: 'subsonic:server-a',
        uri: Uri.parse('subsonic://track?serverId=server-a&id=remote-1'),
      );

      await tester.pumpLibraryScreen(
        tracks: [localTrack],
        remoteTracks: [remoteTrack],
        snapshot: LibrarySnapshot(
          schemaVersion: 1,
          tracks: {'local::1': _snapshot('local::1', playCount: 4)},
        ),
      );

      expect(find.text('Remote Only'), findsNothing);
      expect(find.text('Local Only'), findsWidgets);

      await tester.tap(find.widgetWithText(Tab, 'Remote'));
      await tester.pumpAndSettle();

      expect(find.text('Remote library'), findsOneWidget);
      expect(find.text('Navidrome'), findsOneWidget);
      expect(find.text('Remote Only'), findsOneWidget);
    },
  );

  testWidgets('opens the downloads screen from the library app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tracksProvider.overrideWith((ref) async => const <Track>[]),
          libraryIntelligenceRefreshProvider.overrideWith(
            (ref) => LibraryIntelligenceRefresh(),
          ),
          groupedDownloadsProvider.overrideWith(
            (ref) => const AsyncData(
              GroupedDownloads(
                active: <DownloadItem>[],
                completed: <DownloadItem>[],
                failed: <DownloadItem>[],
              ),
            ),
          ),
          downloadsSummaryProvider.overrideWith(
            (ref) => const AsyncData(
              DownloadsSummary(
                totalCount: 0,
                activeCount: 0,
                completedCount: 0,
                failedCount: 0,
              ),
            ),
          ),
          downloadStorageSummaryProvider.overrideWith(
            (ref) => Stream.value(
              const DownloadStorageSummary(completedCount: 0, totalBytes: 0),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('No downloads yet'), findsOneWidget);
  });

  testWidgets(
    'keeps album and playlist bulk download affordances out of scope',
    (tester) async {
      final playlist = Playlist(
        id: 'p1',
        name: 'Remote mix',
        tracks: [_track('1', title: 'Playlist song')],
      );

      await tester.pumpLibraryScreen(
        tracks: [_track('1', title: 'Album song')],
        remoteTracks: [
          _track(
            'subsonic:server-a:remote-1',
            title: 'Remote track',
            providerId: 'subsonic:server-a',
            uri: Uri.parse('subsonic://track?serverId=server-a&id=remote-1'),
          ),
        ],
        playlists: [playlist],
      );

      await tester.tap(find.widgetWithText(Tab, 'Remote'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Download actions'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Albums'));
      await tester.pumpAndSettle();

      expect(find.text('Download album'), findsNothing);
      expect(find.byTooltip('Download album'), findsNothing);

      await tester.tap(find.widgetWithText(Tab, 'Playlists'));
      await tester.pumpAndSettle();

      expect(find.text('Remote mix'), findsOneWidget);
      expect(find.text('Download playlist'), findsNothing);
      expect(find.byTooltip('Download playlist'), findsNothing);
    },
  );

  testWidgets(
    'connects and saves a Subsonic server from the remote empty state',
    (tester) async {
      final metadataStore = _MemorySubsonicMetadataStore();
      final secretStore = InMemorySubsonicSecretStore();
      final serverStore = SubsonicServerStore(
        metadataStore: metadataStore,
        secretStore: secretStore,
      );
      final client = _ControlledSubsonicApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksProvider.overrideWith((ref) async => const <Track>[]),
            subsonicServerStoreProvider.overrideWith(
              (ref) async => serverStore,
            ),
            subsonicRemoteLibrarySnapshotStoreProvider.overrideWith(
              (ref) async => InMemoryRemoteLibrarySnapshotStore(),
            ),
            subsonicApiClientFactoryProvider.overrideWithValue(({
              required server,
              required password,
            }) {
              client.server = server;
              client.password = password;
              return client;
            }),
            libraryIntelligenceSnapshotProvider.overrideWith(
              (ref) async => const LibrarySnapshot.empty(),
            ),
            localPlaylistStoreProvider.overrideWithValue(
              _MemoryPlaylistStore(),
            ),
          ],
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Remote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect to Subsonic'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Home Navidrome');
      await tester.enterText(fields.at(1), 'https://music.example.com/');
      await tester.enterText(fields.at(2), 'alice');
      await tester.enterText(fields.at(3), 'secret-password');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Connect to Subsonic').last,
      );
      await tester.pump();

      expect(find.text('Testing Subsonic connection...'), findsOneWidget);
      expect(client.pingCalled, isTrue);

      client.completePing();
      await tester.pumpAndSettle();

      final state = await metadataStore.read();
      expect(state.activeServerId, 'https-music-example-com-alice');
      expect(state.servers.single.name, 'Home Navidrome');
      expect(state.servers.single.baseUrl, 'https://music.example.com');
      expect(
        await secretStore.readPassword('https-music-example-com-alice'),
        'secret-password',
      );
      expect(find.text('Subsonic server connected.'), findsOneWidget);
    },
  );

  testWidgets('uses scheme, port, path, and username in Subsonic ids', (
    tester,
  ) async {
    final metadataStore = _MemorySubsonicMetadataStore();
    final secretStore = InMemorySubsonicSecretStore();
    final serverStore = SubsonicServerStore(
      metadataStore: metadataStore,
      secretStore: secretStore,
    );
    final client = _ControlledSubsonicApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tracksProvider.overrideWith((ref) async => const <Track>[]),
          subsonicServerStoreProvider.overrideWith((ref) async => serverStore),
          subsonicRemoteLibrarySnapshotStoreProvider.overrideWith(
            (ref) async => InMemoryRemoteLibrarySnapshotStore(),
          ),
          subsonicApiClientFactoryProvider.overrideWithValue(({
            required server,
            required password,
          }) {
            client.server = server;
            client.password = password;
            return client;
          }),
          libraryIntelligenceSnapshotProvider.overrideWith(
            (ref) async => const LibrarySnapshot.empty(),
          ),
          localPlaylistStoreProvider.overrideWithValue(_MemoryPlaylistStore()),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Remote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect to Subsonic'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Office Navidrome');
    await tester.enterText(
      fields.at(1),
      'http://music.example.com:4533/navidrome/',
    );
    await tester.enterText(fields.at(2), 'Alice');
    await tester.enterText(fields.at(3), 'secret-password');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Connect to Subsonic').last,
    );
    await tester.pump();

    client.completePing();
    await tester.pumpAndSettle();

    final state = await metadataStore.read();
    expect(state.activeServerId, 'http-music-example-com-4533-navidrome-alice');
    expect(
      state.servers.single.baseUrl,
      'http://music.example.com:4533/navidrome',
    );
  });

  testWidgets('shows unavailable cached remote state with stale timestamp', (
    tester,
  ) async {
    final server = const SubsonicServerConfig(
      id: 'server-a',
      name: 'Navidrome',
      baseUrl: 'https://music.example.test',
      username: 'alice',
    );
    final provider = SubsonicMusicProvider(
      server: server,
      client: _ControlledSubsonicApiClient(
        initialError: const SubsonicUnavailableFailure('Server unavailable.'),
      ),
      snapshotStore: InMemoryRemoteLibrarySnapshotStore(
        snapshots: [
          RemoteLibrarySnapshot(
            serverId: 'server-a',
            providerId: 'subsonic:server-a',
            tracks: [
              _track(
                'remote-1',
                title: 'Cached Remote',
                providerId: 'subsonic:server-a',
                uri: Uri.parse(
                  'subsonic://track?serverId=server-a&id=remote-1',
                ),
              ),
            ],
            lastSyncAt: DateTime.utc(2026, 5, 29, 18, 30),
            isStale: false,
          ),
        ],
      ),
    );

    await tester.pumpLibraryScreen(remoteProvider: provider);

    await tester.tap(find.widgetWithText(Tab, 'Remote'));
    await tester.pumpAndSettle();

    expect(find.text('Cached Remote'), findsOneWidget);
    expect(
      find.text('Server unavailable. Showing cached music.'),
      findsOneWidget,
    );
    expect(find.text('Last sync: 2026-05-29 18:30 UTC'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('shows bounded remote preview messaging for large servers', (
    tester,
  ) async {
    final provider = SubsonicMusicProvider(
      server: const SubsonicServerConfig(
        id: 'server-a',
        name: 'Navidrome',
        baseUrl: 'https://music.example.test',
        username: 'alice',
      ),
      client: _ControlledSubsonicApiClient(
        albums: const [
          SubsonicAlbum(id: 'album-1', title: 'One', artist: 'A'),
          SubsonicAlbum(id: 'album-2', title: 'Two', artist: 'A'),
        ],
        songsByAlbum: const {
          'album-1': [
            SubsonicSong(id: 'song-1', title: 'One', artist: 'A', album: 'One'),
          ],
          'album-2': [
            SubsonicSong(id: 'song-2', title: 'Two', artist: 'A', album: 'Two'),
          ],
        },
      ),
      remoteAlbumHydrationLimit: 2,
    );

    await tester.pumpLibraryScreen(remoteProvider: provider);

    await tester.tap(find.widgetWithText(Tab, 'Remote'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Showing a fast remote preview'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Use search for the full server catalog.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'failed connection test does not save or switch the active server',
    (tester) async {
      final metadataStore = _MemorySubsonicMetadataStore();
      final secretStore = InMemorySubsonicSecretStore();
      final serverStore = SubsonicServerStore(
        metadataStore: metadataStore,
        secretStore: secretStore,
      );
      final client = _ControlledSubsonicApiClient(
        initialError: const SubsonicUnavailableFailure('Server unavailable.'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksProvider.overrideWith((ref) async => const <Track>[]),
            subsonicServerStoreProvider.overrideWith(
              (ref) async => serverStore,
            ),
            subsonicRemoteLibrarySnapshotStoreProvider.overrideWith(
              (ref) async => InMemoryRemoteLibrarySnapshotStore(),
            ),
            subsonicApiClientFactoryProvider.overrideWithValue(({
              required server,
              required password,
            }) {
              client.server = server;
              client.password = password;
              return client;
            }),
            libraryIntelligenceSnapshotProvider.overrideWith(
              (ref) async => const LibrarySnapshot.empty(),
            ),
            localPlaylistStoreProvider.overrideWithValue(
              _MemoryPlaylistStore(),
            ),
          ],
          child: const MaterialApp(home: LibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Remote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect to Subsonic'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Office');
      await tester.enterText(fields.at(1), 'https://office.example.com');
      await tester.enterText(fields.at(2), 'bob');
      await tester.enterText(fields.at(3), 'bad-secret');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Connect to Subsonic').last,
      );
      await tester.pumpAndSettle();

      final state = await metadataStore.read();
      expect(state.activeServerId, isNull);
      expect(state.servers, isEmpty);
      expect(find.textContaining('Connection failed:'), findsOneWidget);
    },
  );

  testWidgets(
    'manual retry reloads remote library after an unavailable error',
    (tester) async {
      final provider = _FlakyRemoteMusicProvider(
        firstError: const SubsonicUnavailableFailure('Server unavailable.'),
        recoveredTracks: [
          _track(
            'remote-1',
            title: 'Recovered Remote',
            providerId: 'subsonic:server-a',
            uri: Uri.parse('subsonic://track?serverId=server-a&id=remote-1'),
          ),
        ],
      );

      await tester.pumpLibraryScreen(remoteProvider: provider);

      await tester.tap(find.widgetWithText(Tab, 'Remote'));
      await tester.pumpAndSettle();

      expect(find.text('Server unavailable.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Recovered Remote'), findsOneWidget);
      expect(provider.attempts, 2);
    },
  );

  testWidgets('global refresh also reloads the active remote library', (
    tester,
  ) async {
    final provider = _FlakyRemoteMusicProvider(
      firstError: StateError('unused'),
      failFirstAttempt: false,
      recoveredTracks: [
        _track(
          'remote-1',
          title: 'Recovered Remote',
          providerId: 'subsonic:server-a',
          uri: Uri.parse('subsonic://track?serverId=server-a&id=remote-1'),
        ),
      ],
    );

    await tester.pumpLibraryScreen(remoteProvider: provider);
    await tester.tap(find.widgetWithText(Tab, 'Remote'));
    await tester.pumpAndSettle();

    expect(find.text('Recovered Remote'), findsOneWidget);
    expect(provider.attempts, 1);

    await tester.tap(find.byTooltip('Re-escanear biblioteca'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Actualizando biblioteca...'), findsOneWidget);
    expect(provider.attempts, 2);
  });

  testWidgets('search shows debounced remote loading and source labels', (
    tester,
  ) async {
    final remoteSearch = _ControlledRemoteSearch();

    await tester.pumpLibraryScreen(
      tracks: [_track('1', title: 'Local Hit')],
      remoteSearch: remoteSearch,
      remoteSearchDebounce: const Duration(milliseconds: 20),
    );

    await tester.tap(find.widgetWithText(Tab, 'Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search artists, albums, tracks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hit');
    await tester.pump();
    await tester.pump();

    expect(find.text('Local library'), findsOneWidget);
    expect(find.text('Remote library'), findsOneWidget);
    expect(find.text('Searching Navidrome...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 25));
    remoteSearch.complete('hit', [
      _track(
        'remote-1',
        title: 'Remote Hit',
        providerId: 'subsonic:server-a',
        uri: Uri.parse('subsonic://track?serverId=server-a&id=remote-1'),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Local Hit'), findsOneWidget);
    expect(find.text('Remote Hit'), findsOneWidget);
    expect(find.text('Source: Local library'), findsOneWidget);
    expect(find.text('Source: Navidrome'), findsOneWidget);
  });

  testWidgets('search shows explicit remote empty and error states', (
    tester,
  ) async {
    final remoteSearch = _ControlledRemoteSearch();

    await tester.pumpLibraryScreen(
      tracks: [_track('1', title: 'Local Hit')],
      remoteSearch: remoteSearch,
      remoteSearchDebounce: Duration.zero,
    );

    await tester.tap(find.widgetWithText(Tab, 'Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search artists, albums, tracks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    await tester.pump();
    remoteSearch.complete('missing', const []);
    await tester.pumpAndSettle();

    expect(find.text('No remote matches in Navidrome.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'broken');
    await tester.pump();
    await tester.pump();
    remoteSearch.fail(
      'broken',
      const SubsonicUnavailableFailure('Server unavailable.'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Remote search is unavailable right now.'),
      findsOneWidget,
    );
  });
}

extension on WidgetTester {
  Future<void> pumpLibraryScreen({
    List<Track> tracks = const [],
    List<Track> remoteTracks = const [],
    MusicProvider? remoteProvider,
    LibrarySnapshot snapshot = const LibrarySnapshot.empty(),
    List<Playlist> playlists = const [],
    MetadataOverrideStore? overrideStore,
    _ControlledRemoteSearch? remoteSearch,
    Duration? remoteSearchDebounce,
    bool settle = true,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          tracksProvider.overrideWith((ref) async => tracks),
          if (remoteProvider == null)
            remoteLibraryTracksProvider.overrideWith(
              (ref) async => remoteTracks,
            ),
          remoteLibrarySourceLabelProvider.overrideWithValue('Navidrome'),
          if (remoteProvider != null)
            activeRemoteMusicProvider.overrideWithValue(remoteProvider),
          if (remoteProvider == null && remoteTracks.isNotEmpty)
            activeRemoteMusicProvider.overrideWithValue(
              _FlakyRemoteMusicProvider(
                firstError: StateError('unused'),
                recoveredTracks: remoteTracks,
                failFirstAttempt: false,
              ),
            ),
          libraryIntelligenceSnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
          localPlaylistStoreProvider.overrideWithValue(
            _MemoryPlaylistStore(playlists),
          ),
          if (overrideStore != null)
            metadataOverrideStoreProvider.overrideWithValue(overrideStore),
          if (remoteSearch != null)
            remoteTrackSearchProvider.overrideWithValue(remoteSearch.search),
          if (remoteSearchDebounce != null)
            remoteSearchDebounceDurationProvider.overrideWithValue(
              remoteSearchDebounce,
            ),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    if (settle) {
      await pumpAndSettle();
    } else {
      await pump();
    }
  }
}

class _ControlledRemoteSearch {
  final Map<String, Completer<List<Track>>> _queries =
      <String, Completer<List<Track>>>{};

  Future<List<Track>> search(String query) {
    return _ensureCompleter(query).future;
  }

  void complete(String query, List<Track> tracks) {
    _ensureCompleter(query).complete(tracks);
  }

  void fail(String query, Object error) {
    _ensureCompleter(query).completeError(error);
  }

  Completer<List<Track>> _ensureCompleter(String query) {
    return _queries.putIfAbsent(query, () {
      final completer = Completer<List<Track>>();
      completer.future.catchError((_) => const <Track>[]);
      return completer;
    });
  }
}

class _FlakyRemoteMusicProvider implements MusicProvider {
  _FlakyRemoteMusicProvider({
    required this.firstError,
    required this.recoveredTracks,
    this.failFirstAttempt = true,
  });

  final Object firstError;
  final List<Track> recoveredTracks;
  final bool failFirstAttempt;
  int attempts = 0;

  @override
  String get id => 'subsonic:server-a';

  @override
  String get name => 'Navidrome';

  @override
  Future<List<Album>> getAlbums() async => const [];

  @override
  Future<List<Artist>> getArtists() async => const [];

  @override
  Future<StreamUri> resolveStream(Track track) async => StreamUri(track.uri);

  @override
  Future<List<Track>> search(String query) async => recoveredTracks;

  @override
  Future<List<Track>> getTracks() async {
    attempts += 1;
    if (failFirstAttempt && attempts == 1) throw firstError;
    return recoveredTracks;
  }
}

Track _track(
  String id, {
  String? title,
  String album = 'Album',
  String artist = 'Artist',
  int durationSeconds = 120,
  String providerId = 'local',
  Uri? uri,
  int? artworkId,
}) {
  return Track(
    id: id,
    providerId: providerId,
    title: title ?? 'Song $id',
    artist: artist,
    album: album,
    uri: uri ?? Uri.parse('content://song/$id'),
    artworkId: artworkId,
    duration: Duration(seconds: durationSeconds),
  );
}

class _PendingArtworkResolver extends ArtworkCacheResolver {
  _PendingArtworkResolver()
    : super(
        store: _NoopArtworkCacheStore(),
        source: _NoopArtworkBytesSource(),
        embeddedSource: _NoopEmbeddedArtworkBytesSource(),
      );

  @override
  Future<String?> resolvePath({required Track track, required int sizePx}) {
    return Completer<String?>().future;
  }
}

class _NoopArtworkCacheStore implements ArtworkCacheStore {
  @override
  int get maxCacheSizeBytes => 1024;

  @override
  Future<void> deleteServer(String serverId) async {}

  @override
  Future<String?> readPath(ArtworkCacheKey key) async => null;

  @override
  Future<void> writeBytes(ArtworkCacheKey key, Uint8List bytes) async {}
}

class _NoopArtworkBytesSource implements ArtworkBytesSource {
  @override
  Future<Uint8List?> fetch({
    required int artworkId,
    required int sizePx,
  }) async {
    return null;
  }
}

class _NoopEmbeddedArtworkBytesSource implements EmbeddedArtworkBytesSource {
  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    return null;
  }
}

LibraryTrackSnapshot _snapshot(String trackKey, {required int playCount}) {
  return LibraryTrackSnapshot(
    trackKey: trackKey,
    playCount: playCount,
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    resumePositionMs: 0,
    durationMs: 120000,
    isFavorite: false,
    favoritedAt: null,
    isCompleted: true,
  );
}

class _MemoryPlaylistStore extends LocalPlaylistStore {
  _MemoryPlaylistStore([this._playlists = const []]);

  List<Playlist> _playlists;

  @override
  Future<List<Playlist>> getPlaylists() async => _playlists;

  @override
  Future<void> savePlaylists(List<Playlist> playlists) async {
    _playlists = playlists;
  }
}

class _MemoryMetadataOverrideStore implements MetadataOverrideStore {
  const _MemoryMetadataOverrideStore({this.overrides = const {}});

  final Map<String, MetadataOverride> overrides;

  @override
  Future<MetadataOverride?> loadOverride(String trackKey) async =>
      overrides[trackKey];

  @override
  Future<void> saveOverride(String trackKey, MetadataOverride override) async {}

  @override
  Future<void> clearOverride(String trackKey) async {}
}

class _ControlledMetadataOverrideStore implements MetadataOverrideStore {
  final Completer<MetadataOverride?> _completer =
      Completer<MetadataOverride?>();

  void complete(MetadataOverride? override) {
    _completer.complete(override);
  }

  @override
  Future<MetadataOverride?> loadOverride(String trackKey) => _completer.future;

  @override
  Future<void> saveOverride(String trackKey, MetadataOverride override) async {}

  @override
  Future<void> clearOverride(String trackKey) async {}
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

class _ControlledSubsonicApiClient implements SubsonicApiClientContract {
  _ControlledSubsonicApiClient({
    this.initialError,
    this.albums = const [],
    this.songsByAlbum = const {},
  });

  final Completer<void> _pingCompleter = Completer<void>();
  final Object? initialError;
  final List<SubsonicAlbum> albums;
  final Map<String, List<SubsonicSong>> songsByAlbum;

  SubsonicServerConfig? server;
  String? password;
  bool pingCalled = false;

  void completePing() => _pingCompleter.complete();

  @override
  Future<void> ping() {
    pingCalled = true;
    if (initialError != null) return Future<void>.error(initialError!);
    return _pingCompleter.future;
  }

  @override
  Future<List<SubsonicArtist>> getArtists() async => const [];

  @override
  Future<List<SubsonicAlbum>> getAlbumList2({
    String type = 'alphabeticalByName',
    int? size,
    int? offset,
  }) async {
    if (initialError != null) throw initialError!;
    final start = offset ?? 0;
    final bounded = albums.skip(start);
    if (size == null) return bounded.toList(growable: false);
    return bounded.take(size).toList(growable: false);
  }

  @override
  Future<SubsonicAlbumDetail> getAlbum(String id) async => SubsonicAlbumDetail(
    album: albums.firstWhere((album) => album.id == id),
    songs: songsByAlbum[id] ?? const <SubsonicSong>[],
  );

  @override
  Future<SubsonicSong> getSong(String id) async => throw UnimplementedError();

  @override
  Future<List<SubsonicSong>> search3(String query) async => const [];

  @override
  Uri streamUri(String songId) => Uri.parse('https://music.example.com/stream');

  @override
  Uri getCoverArtUri(String coverArtId) =>
      Uri.parse('https://music.example.com/cover');
}
