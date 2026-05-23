import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase options are not configured for web.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase options are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmfKoQEkiZjn-bG_DhKKI9V04LkhlbLzk',
    appId: '1:288733119172:android:6f9a3e4f28840cfb2cbf91',
    messagingSenderId: '288733119172',
    projectId: 'megapromo-18c9b',
    storageBucket: 'megapromo-18c9b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgG-XE3wPVGOllttVPFdNPMna00Dz-7ZI',
    appId: '1:288733119172:ios:0c2d91c2a15456792cbf91',
    messagingSenderId: '288733119172',
    projectId: 'megapromo-18c9b',
    storageBucket: 'megapromo-18c9b.firebasestorage.app',
    iosBundleId: 'com.moyoo.megapromoios',
  );
}
