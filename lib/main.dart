import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const KycVerificationApp());
}

class KycVerificationApp extends StatelessWidget {
  const KycVerificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0F8B8D);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Livn',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7FB),
      ),
      home: const SplashPage(),
    );
  }
}
