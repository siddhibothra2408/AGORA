import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/agora_firebase_config.dart';

/// Provider for FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  if (!AgoraFirebaseConfig.isInitialized) return null;
  try {
    return FirebaseAuth.instance;
  } catch (_) {
    return null;
  }
});

/// Provider for FirebaseFirestore instance
final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  if (!AgoraFirebaseConfig.isInitialized) return null;
  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
});

/// Provider for FirebaseFunctions instance
final firebaseFunctionsProvider = Provider<FirebaseFunctions?>((ref) {
  if (!AgoraFirebaseConfig.isInitialized) return null;
  try {
    return FirebaseFunctions.instance;
  } catch (_) {
    return null;
  }
});

/// Stream of auth state changes (User? or null)
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) {
    return Stream.value(null);
  }
  return auth.authStateChanges();
});

/// Provider for the current authenticated user UID
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.value?.uid;
});
