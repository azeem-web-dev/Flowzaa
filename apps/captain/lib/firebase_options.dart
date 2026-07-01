// PLACEHOLDER — regenerate with: flutterfire configure --project=flowzaa-7c9d8
//
// These are non-functional placeholder values so the app compiles and
// `Firebase.initializeApp` has a valid shape. Replace by running the
// FlutterFire CLI against the real Firebase project before shipping.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web — '
        'reconfigure with the FlutterFire CLI.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
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
    iosBundleId: 'com.flowzaa.captain',
  );
}
