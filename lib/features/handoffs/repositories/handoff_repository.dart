import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firebase_providers.dart';
import '../../items/models/item.dart';
import '../models/handoff.dart';
import '../models/proposal.dart';

abstract class HandoffRepository {
  Stream<List<Handoff>> watchHandoffs(String spaceId);
  Stream<List<Proposal>> watchPendingProposals(String spaceId);
  Future<void> approveProposal({
    required String spaceId,
    required Proposal proposal,
    required String approvedByUid,
    String? editedTitle,
    DateTime? editedDueDate,
    String? assignedTo,
  });
  Future<void> dismissProposal({required String proposalId});
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

  @override
  Future<void> approveProposal({
    required String spaceId,
    required Proposal proposal,
    required String approvedByUid,
    String? editedTitle,
    DateTime? editedDueDate,
    String? assignedTo,
  }) async {
    final firestore = firestoreInstance;
    if (firestore == null) return;

    final batch = firestore.batch();
    final proposalRef = firestore.doc(FirestorePaths.proposal(proposal.id));
    final itemRef = firestore
        .collection(FirestorePaths.spaceItems(spaceId))
        .doc();

    final title = (editedTitle != null && editedTitle.trim().isNotEmpty)
        ? editedTitle.trim()
        : proposal.title;

    final dueDate =
        editedDueDate ??
        (proposal.payload['dueDate'] != null
            ? DateTime.tryParse(proposal.payload['dueDate'].toString())
            : null);

    final effectiveAssignee =
        assignedTo ?? proposal.payload['suggestedAssigneeUid'] as String?;

    // Mark proposal approved (or edited)
    final newStatus = (editedTitle != null && editedTitle != proposal.title)
        ? ProposalStatus.edited
        : ProposalStatus.approved;
    batch.update(proposalRef, {
      'status': newStatus.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create item
    final itemData = <String, dynamic>{
      'id': itemRef.id,
      'spaceId': spaceId,
      'type': proposal.type.value,
      'title': title,
      'description': proposal.payload['description'] as String? ?? '',
      'status': ItemStatus.open.value,
      'sourceHandoffId': proposal.handoffId,
      'sourceMessageIds': proposal.sourceMessageIds,
      'approvedByUid': approvedByUid,
      'ownerUid': effectiveAssignee,
      'assigneeUid': effectiveAssignee,
      'assignmentStatus':
          (effectiveAssignee != null && effectiveAssignee != approvedByUid)
          ? AssignmentStatus.proposed.value
          : AssignmentStatus.accepted.value,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (dueDate != null) {
      itemData['dueDate'] = dueDate.toUtc().toIso8601String();
    }

    batch.set(itemRef, itemData);
    await batch.commit();
  }

  @override
  Future<void> dismissProposal({required String proposalId}) async {
    final firestore = firestoreInstance;
    if (firestore == null) return;
    await firestore.doc(FirestorePaths.proposal(proposalId)).update({
      'status': ProposalStatus.dismissed.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

final pendingProposalsProvider = StreamProvider.family<List<Proposal>, String>((
  ref,
  spaceId,
) {
  final repo = ref.watch(handoffRepositoryProvider);
  return repo.watchPendingProposals(spaceId);
});
