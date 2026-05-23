import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library_intelligence/application/library_intelligence_reducer.dart';
import '../../library_intelligence/application/library_intelligence_sink.dart';
import '../../library_intelligence/infrastructure/file_library_intelligence_store.dart';
import '../infrastructure/file_playback_session_store.dart';
import '../infrastructure/vanta_audio_handler.dart';

final audioHandlerProvider = Provider<VantaAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler must be initialized in main().');
});

Future<VantaAudioHandler> initAudioHandler() async {
  final intelligenceStore = FileLibraryIntelligenceStore();
  final intelligenceSink = LibraryIntelligenceSink(
    store: intelligenceStore,
    reducer: const LibraryIntelligenceReducer(),
  );
  await intelligenceSink.initialize();

  final handler = await AudioService.init(
    builder: () => VantaAudioHandler(
      sessionStore: FilePlaybackSessionStore(),
      intelligenceSink: intelligenceSink,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'vanta_music_playback',
      androidNotificationChannelName: 'Vanta Music',
      androidNotificationIcon: 'drawable/ic_vanta_notification',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
    ),
  );
  await handler.restoreSessionIfAvailable();
  return handler;
}
