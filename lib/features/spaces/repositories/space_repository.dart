import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/firebase_providers.dart';
import '../../profile/models/user_profile.dart';
import '../models/ai_consent_state.dart';
import '../models/ai_policy.dart';
import '../models/space.dart';
import '../models/space_member.dart';

abstract class SpaceRepository {
  Stream<List<Space>> watchUserSpaces(String uid);
  Stream<Space?> watchSpace(String spaceId);
  Stream<List<SpaceMember>> watchMembers(String spaceId);
  Stream<SpaceMember?> watchMember(String spaceId, String uid);
  Future<Space> createSpace({
    required String name,
    required String description,
    required String charter,
    required UserProfile creator,
    AiPolicy aiPolicy = const AiPolicy(),
  });
  Future<void> updateMemberConsent({
    required String spaceId,
    required String uid,
    required MemberConsentState consentState,
  });
}

class FirestoreSpaceRepository implements SpaceRepository {
  FirestoreSpaceRepository({this.firestoreInstance});

  final FirebaseFirestore? firestoreInstance;
  static const _uuid = Uuid();

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

  @override
  Stream<List<Space>> watchUserSpaces(String uid) {
    if (firestoreInstance == null) return Stream.value([]);
    // Listen to spaces collection where user is a member
    return firestore
        .collection(FirestorePaths.spaces)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Space.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  @override
  Stream<Space?> watchSpace(String spaceId) {
    if (firestoreInstance == null) return Stream.value(null);
    return firestore
        .doc(FirestorePaths.space(spaceId))
        .snapshots()
        .map(
          (doc) => doc.exists && doc.data() != null
              ? Space.fromMap(doc.data()!, doc.id)
              : null,
        );
  }

  @override
  Stream<List<SpaceMember>> watchMembers(String spaceId) {
    if (firestoreInstance == null) return Stream.value([]);
    return firestore
        .collection(FirestorePaths.spaceMembers(spaceId))
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SpaceMember.fromMap(doc.data(), doc.id, spaceId))
              .toList(),
        );
  }

  @override
  Stream<SpaceMember?> watchMember(String spaceId, String uid) {
    if (firestoreInstance == null) return Stream.value(null);
    return firestore
        .doc(FirestorePaths.spaceMember(spaceId, uid))
        .snapshots()
        .map(
          (doc) => doc.exists && doc.data() != null
              ? SpaceMember.fromMap(doc.data()!, uid, spaceId)
              : null,
        );
  }

  @override
  Future<Space> createSpace({
    required String name,
    required String description,
    required String charter,
    required UserProfile creator,
    AiPolicy aiPolicy = const AiPolicy(),
  }) async {
    final spaceId = _uuid.v4();
    final now = DateTime.now();

    final space = Space(
      id: spaceId,
      name: name.trim(),
      description: description.trim(),
      charter: charter.trim(),
      createdBy: creator.uid,
      createdAt: now,
      memberCount: 1,
      aiPolicy: aiPolicy,
    );

    final member = SpaceMember(
      uid: creator.uid,
      spaceId: spaceId,
      displayName: creator.displayName,
      handle: creator.handle,
      photoUrl: creator.photoUrl,
      role: SpaceMemberRole.owner,
      consentState: creator.defaultAiConsent == DefaultAiConsent.withheld
          ? MemberConsentState.withheld
          : MemberConsentState.consented,
      joinedAt: now,
    );

    try {
      final batch = firestore.batch();
      batch.set(firestore.doc(FirestorePaths.space(spaceId)), space.toMap());
      batch.set(
        firestore.doc(FirestorePaths.spaceMember(spaceId, creator.uid)),
        member.toMap(),
      );
      await batch.commit();
      return space;
    } catch (e) {
      throw DataFailure('Failed to create space: $e');
    }
  }

  @override
  Future<void> updateMemberConsent({
    required String spaceId,
    required String uid,
    required MemberConsentState consentState,
  }) async {
    try {
      await firestore.doc(FirestorePaths.spaceMember(spaceId, uid)).update({
        'consentState': consentState.value,
      });
    } catch (e) {
      throw DataFailure('Failed to update consent state: $e');
    }
  }
}

final spaceRepositoryProvider = Provider<SpaceRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreSpaceRepository(firestoreInstance: firestore);
});

final userSpacesProvider = StreamProvider<List<Space>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.watchUserSpaces(uid);
});

final currentSpaceProvider = StreamProvider.family<Space?, String>((
  ref,
  spaceId,
) {
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.watchSpace(spaceId);
});

final spaceMembersProvider = StreamProvider.family<List<SpaceMember>, String>((
  ref,
  spaceId,
) {
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.watchMembers(spaceId);
});
