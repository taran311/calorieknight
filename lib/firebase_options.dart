// Firebase settings: The Calorie Card's project (auth-af04a), so CalorieKnight shares its sign-in
// and the food proxy accepts it. The web app works now. For Android and iOS, register
// CalorieKnight's own apps in the same project by running, in this folder:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=auth-af04a --platforms=android,ios,web
// which rewrites this file (and adds google-services.json / GoogleService-Info.plist).
// Until then the phone builds fall back to the device-only test sign-in.

// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// Null on platforms not configured yet.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return windows;
      default:
        return null;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDsINOWDiuf_A7srryvuNajYQwxae3Dqy0',
    appId: '1:795453323864:web:20c99e15c9d0a610d1a82d',
    messagingSenderId: '795453323864',
    projectId: 'auth-af04a',
    authDomain: 'auth-af04a.firebaseapp.com',
    storageBucket: 'auth-af04a.appspot.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDsINOWDiuf_A7srryvuNajYQwxae3Dqy0',
    appId: '1:795453323864:web:a202d40054c00ac5d1a82d',
    messagingSenderId: '795453323864',
    projectId: 'auth-af04a',
    authDomain: 'auth-af04a.firebaseapp.com',
    storageBucket: 'auth-af04a.appspot.com',
  );
}
