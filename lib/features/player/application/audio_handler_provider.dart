import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../downloads/infrastructure/download_database.dart';
import '../../downloads/infrastructure/file_download_storage.dart';
import '../../library_intelligence/application/library_intelligence_reducer.dart';
import '../../library_intelligence/application/library_intelligence_refresh.dart';
import '../../library_intelligence/application/library_intelligence_sink.dart';
import '../../library_intelligence/infrastructure/file_library_intelligence_store.dart';
import '../../providers/infrastructure/subsonic_api_client.dart';
import '../../providers/infrastructure/subsonic_server_store.dart';
import '../infrastructure/file_audio_settings_store.dart';
import '../infrastructure/file_playback_session_store.dart';
import '../infrastructure/native_vanta_engine_adapter.dart';
import '../infrastructure/vanta_audio_handler.dart';
import 'subsonic_stream_resolver_registry.dart';

final audioHandlerProvider = Provider<VantaAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler must be initialized in main().');
});

Future<VantaAudioHandler> initAudioHandler() async {
  final audioSettingsStore = FileAudioSettingsStore();
  final audioSettings = await audioSettingsStore.load();
  final intelligenceStore = FileLibraryIntelligenceStore();
  final intelligenceSink = LibraryIntelligenceSink(
    store: intelligenceStore,
    reducer: const LibraryIntelligenceReducer(),
    onChanged: libraryIntelligenceRefresh.markChanged,
  );
  await intelligenceSink.initialize();
  final directory = await getApplicationSupportDirectory();
  final subsonicStore = SubsonicServerStore(
    metadataStore: FileSubsonicServerMetadataStore(
      File('${directory.path}/subsonic_servers.json'),
    ),
    secretStore: const FlutterSecureSubsonicSecretStore(),
  );
  final downloadDatabase = DownloadDatabase.sharedFile(
    File('${directory.path}/downloads.sqlite'),
  );
  final downloadStorage = FileDownloadStorage(
    appSupportDirectory: () async => directory,
  );

  final handler = await AudioService.init(
    builder: () => VantaAudioHandler(
      sessionStore: FilePlaybackSessionStore(),
      intelligenceSink: intelligenceSink,
      nativeEngine: NativeVantaEngineAdapter(),
      streamResolverRegistry: SubsonicStreamResolverRegistry(
        store: subsonicStore,
        clientFactory: ({required server, required password}) =>
            SubsonicApiClient(server: server, password: password),
        downloadDatabase: downloadDatabase,
        downloadStorage: downloadStorage,
      ),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'vanta_music_playback',
      androidNotificationChannelName: 'Vanta Music',
      androidNotificationIcon: 'drawable/ic_vanta_notification',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
    ),
  );
  await handler.applyAudioSettings(audioSettings);
  await handler.restoreSessionIfAvailable();
  return handler;
}
