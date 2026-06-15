import 'package:go_router/go_router.dart';

import '../features/downloads/presentation/downloads_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/player/presentation/audio_settings_screen.dart';
import '../features/player/presentation/now_playing_screen.dart';

GoRouter buildAppRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/now-playing',
        name: 'now-playing',
        builder: (context, state) => const NowPlayingScreen(),
      ),
      GoRoute(
        path: '/audio-settings',
        name: 'audio-settings',
        builder: (context, state) => const AudioSettingsScreen(),
      ),
    ],
  );
}

final appRouter = buildAppRouter();
