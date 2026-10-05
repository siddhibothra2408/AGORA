import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase Configuration and Emulator Suite Manager
abstract final class AgoraFirebaseConfig {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Initialize Firebase with optional emulator support
  static Future<void> initialize({
    FirebaseOptions? options,
    bool useEmulator = const bool.fromEnvironment('USE_FIREBASE_EMULATOR'),
    String emulatorHost = '10.0.2.2', // Standard Android emulator loopback
  }) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        return;
      }

      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        // Attempt default platform initialization (reads google-services.json on Android)
        await Firebase.initializeApp();
      }

      _isInitialized = true;

      if (useEmulator) {
        await _connectToEmulators(emulatorHost);
      }
    } catch (e, st) {
      developer.log(
        'Firebase initialization note: $e\n'
        'To connect your production or staging Firebase project, run:\n'
        '  dart pub global activate flutterfire_cli\n'
        '  flutterfire configure\n'
        'or run the Firebase Emulator Suite.',
        name: 'AgoraFirebaseConfig',
        error: e,
        stackTrace: st,
      );
      // In offline / preview mode or widget test runner, allow graceful progression
      _isInitialized = false;
    }
  }

  static Future<void> _connectToEmulators(String host) async {
    developer.log('Connecting to Firebase Emulators at $host', name: 'Agora');
    try {
      // Auth emulator (port 9099)
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);

      // Firestore emulator (port 8080)
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to emulator: $e');
      }
    }
  }
}
