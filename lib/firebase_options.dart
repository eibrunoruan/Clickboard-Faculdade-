import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase is configured only for web and iOS. Run with '
          '--dart-define=USE_FIREBASE=false or add platform Firebase options.',
        );
      default:
        throw UnsupportedError('Unsupported platform for Firebase.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCmsOI8o_uUFOBjw2znInUNJfIe6HvB9ak',
    authDomain: 'quiz-38ee4.firebaseapp.com',
    projectId: 'quiz-38ee4',
    storageBucket: 'quiz-38ee4.firebasestorage.app',
    messagingSenderId: '369101895648',
    appId: '1:369101895648:web:b569138f146ae5a5e59d85',
    measurementId: 'G-D8WNKM107Z',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCZVejkPBMjcwQ8zFvsuJeK0tIn4xsmTuA',
    appId: '1:369101895648:ios:d6c64d120f385db2e59d85',
    messagingSenderId: '369101895648',
    projectId: 'quiz-38ee4',
    storageBucket: 'quiz-38ee4.firebasestorage.app',
    iosBundleId: 'com.example.jgecNotice',
  );
}
