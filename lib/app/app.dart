import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class VantaMusicApp extends StatelessWidget {
  const VantaMusicApp({super.key});

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
