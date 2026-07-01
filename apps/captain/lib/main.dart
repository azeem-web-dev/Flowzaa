import 'package:firebase_core/firebase_core.dart';
import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env is optional at runtime — don't crash if it's missing.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Ignore: MAPS_API_KEY is baked into the native manifests as a fallback.
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: FlowzaaCaptainApp()));
}

class FlowzaaCaptainApp extends StatelessWidget {
  const FlowzaaCaptainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowzaa Captain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
