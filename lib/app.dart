import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'pages/splash_page.dart';

class AniScrollApp extends StatelessWidget {
  const AniScrollApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AniScroll',
    debugShowCheckedModeBanner: false,
    theme: buildAniTheme(),
    home: const SplashPage(),
  );
}
