import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firebase_providers.dart';
import '../models/handoff.dart';
import '../models/proposal.dart';

abstract class HandoffRepository {
  Stream<List<Handoff>> watchHandoffs(String spaceId);
  Stream<List<Proposal>> watchPendingProposals(String spaceId);
}

class FirestoreHandoffRepository implements HandoffRepository {
  FirestoreHandoffRepository({this.firestoreInstance});

  final FirebaseFirestore? firestoreInstance;

  @override
  Stream<List<Handoff>> watchHandoffs(String spaceId) {
    final firestore = firestoreInstance;
    if (firestore == null) return Stream.value([]);
    return firestore
        .collection(FirestorePaths.spaceHandoffs(spaceId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Handoff.fromMap(doc.data(), doc.id, spaceId))
              .toList(),
        );
  }

  @override
  Stream<List<Proposal>> watchPendingProposals(String spaceId) {
    final firestore = firestoreInstance;
    if (firestore == null) return Stream.value([]);
    return firestore
        .collection(FirestorePaths.proposals)
        .where('spaceId', isEqualTo: spaceId)
        .where('status', isEqualTo: ProposalStatus.pending.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Proposal.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}

final handoffRepositoryProvider = Provider<HandoffRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreHandoffRepository(firestoreInstance: firestore);
});

final spaceHandoffsProvider = StreamProvider.family<List<Handoff>, String>((
  ref,
  spaceId,
) {
  final repo = ref.watch(handoffRepositoryProvider);
  return repo.watchHandoffs(spaceId);
});
