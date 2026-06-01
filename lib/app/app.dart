import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/downloads/application/download_providers.dart';

import 'router.dart';
import 'theme.dart';

class VantaMusicApp extends ConsumerStatefulWidget {
  const VantaMusicApp({super.key});

  @override
  ConsumerState<VantaMusicApp> createState() => _VantaMusicAppState();
}

class _VantaMusicAppState extends ConsumerState<VantaMusicApp> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(downloadBootstrapProvider.future));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vanta Music',
      debugShowCheckedModeBanner: false,
      theme: buildVantaDarkTheme(),
      routerConfig: appRouter,
    );
  }
}
