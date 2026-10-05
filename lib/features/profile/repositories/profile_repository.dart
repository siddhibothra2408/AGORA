import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/firebase_providers.dart';
import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile?> getProfile(String uid);
  Stream<UserProfile?> watchProfile(String uid);
  Future<bool> isHandleAvailable(String handle);
  Future<UserProfile> createProfile({
    required String uid,
    required String handle,
    required String displayName,
    String? bio,
    String? photoUrl,
    DefaultAiConsent defaultAiConsent = DefaultAiConsent.optIn,
  });
  Future<void> updateProfile(UserProfile profile);
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({this.firestoreInstance});

  final FirebaseFirestore? firestoreInstance;

  FirebaseFirestore get firestore {
    final f = firestoreInstance;
    if (f == null) {
      throw const DataFailure(
        'Firestore is uninitialized. Configure Firebase or run the emulators.',
        'firestore-uninitialized',
      );
    }
    return f;
  }

  static final RegExp _handleRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  @override
  Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = await firestore.doc(FirestorePaths.profile(uid)).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!, uid);
    } catch (e) {
      throw DataFailure('Failed to fetch profile: $e');
    }
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    if (firestoreInstance == null) return Stream.value(null);
    return firestore
        .doc(FirestorePaths.profile(uid))
        .snapshots()
        .map(
          (doc) => doc.exists && doc.data() != null
              ? UserProfile.fromMap(doc.data()!, uid)
              : null,
        );
  }

  @override
  Future<bool> isHandleAvailable(String handle) async {
    final normalized = handle.toLowerCase().trim();
    if (!_handleRegex.hasMatch(normalized)) {
      return false;
    }
    try {
      final doc = await firestore.doc(FirestorePaths.handle(normalized)).get();
      return !doc.exists;
    } catch (e) {
      throw DataFailure('Failed to check handle availability: $e');
    }
  }

  @override
  Future<UserProfile> createProfile({
    required String uid,
    required String handle,
    required String displayName,
    String? bio,
    String? photoUrl,
    DefaultAiConsent defaultAiConsent = DefaultAiConsent.optIn,
  }) async {
    final normalizedHandle = handle.toLowerCase().trim();
    if (!_handleRegex.hasMatch(normalizedHandle)) {
      throw ProfileFailure.invalidHandle();
    }

    final handleRef = firestore.doc(FirestorePaths.handle(normalizedHandle));
    final profileRef = firestore.doc(FirestorePaths.profile(uid));
    final now = DateTime.now();

    final profile = UserProfile(
      uid: uid,
      handle: normalizedHandle,
      displayName: displayName.trim(),
      bio: bio?.trim(),
      photoUrl: photoUrl,
      defaultAiConsent: defaultAiConsent,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await firestore.runTransaction((transaction) async {
        final handleDoc = await transaction.get(handleRef);
        if (handleDoc.exists) {
          throw ProfileFailure.handleTaken(normalizedHandle);
        }

        // Atomically claim handle
        transaction.set(handleRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create profile
        transaction.set(profileRef, profile.toMap());
      });

      return profile;
    } on Failure {
      rethrow;
    } catch (e) {
      throw DataFailure('Transaction failed while creating profile: $e');
    }
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    try {
      await firestore
          .doc(FirestorePaths.profile(profile.uid))
          .update(profile.toMap());
    } catch (e) {
      throw DataFailure('Failed to update profile: $e');
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreProfileRepository(firestoreInstance: firestore);
});

/// Watches the current user's profile
final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchProfile(uid);
});
