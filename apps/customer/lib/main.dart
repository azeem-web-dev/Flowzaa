import 'package:firebase_core/firebase_core.dart';
import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env asset for the Maps API key. Guarded so a missing/absent file
  // doesn't crash startup.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env bundled — providers fall back to a placeholder key.
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: FlowzaaCustomerApp()));
}

class FlowzaaCustomerApp extends StatelessWidget {
  const FlowzaaCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowzaa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
