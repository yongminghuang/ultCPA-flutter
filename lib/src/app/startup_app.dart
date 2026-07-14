import 'package:flutter/material.dart';

import '../startup/startup_splash_page.dart';

final class StartupApp extends StatelessWidget {
  const StartupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartupSplashPage(),
    );
  }
}
