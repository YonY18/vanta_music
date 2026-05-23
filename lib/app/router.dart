import 'package:go_router/go_router.dart';

import '../features/library/presentation/library_screen.dart';
import '../features/player/presentation/now_playing_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/now-playing',
      name: 'now-playing',
      builder: (context, state) => const NowPlayingScreen(),
    ),
  ],
);
