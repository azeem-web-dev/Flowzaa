// PLACEHOLDER — regenerate with: flutterfire configure --project=flowzaa-7c9d8
//
// These are placeholder Firebase options so the app compiles and `flutter
// pub get` / `flutter analyze` succeed without a real Firebase project. Replace
// this whole file by running the flutterfire CLI before shipping.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return android; // no web build configured; fall back to android options
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'flowzaa-7c9d8',
    storageBucket: 'flowzaa-7c9d8.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'flowzaa-7c9d8',
    storageBucket: 'flowzaa-7c9d8.appspot.com',
    iosBundleId: 'com.flowzaa.customer',
  );
}
