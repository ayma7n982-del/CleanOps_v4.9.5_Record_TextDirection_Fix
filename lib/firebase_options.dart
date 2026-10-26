// File generated automatically for Solid Waste Operations.
// DO NOT MODIFY BY HAND.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAa8b1275kDi-xxkiDbKVSOD8U0FvmTJBc',
    appId: '1:170721836545:web:d4fe5333a3cf0b24af4a00',
    messagingSenderId: '170721836545',
    projectId: 'nrc-aid',
    authDomain: 'nrc-aid.firebaseapp.com',
    storageBucket: 'nrc-aid.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAa8b1275kDi-xxkiDbKVSOD8U0FvmTJBc',
    appId: '1:170721836545:android:d4fe5333a3cf0b24af4a00',
    messagingSenderId: '170721836545',
    projectId: 'nrc-aid',
    storageBucket: 'nrc-aid.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAa8b1275kDi-xxkiDbKVSOD8U0FvmTJBc',
    appId: '1:170721836545:ios:d4fe5333a3cf0b24af4a00',
    messagingSenderId: '170721836545',
    projectId: 'nrc-aid',
    storageBucket: 'nrc-aid.firebasestorage.app',
    iosBundleId: 'com.solidwaste.solid_waste_operations',
  );
}
