import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/failures.dart';
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
    String? editedDetail,
    ItemType? editedType,
    DateTime? editedDueDate,
    String? assignedTo,
  });
  Future<void> dismissProposal({required String proposalId});
}

class FirestoreHandoffRepository implements HandoffRepository {
  FirestoreHandoffRepository({this.firestoreInstance, this.functionsInstance});

  final FirebaseFirestore? firestoreInstance;
  final FirebaseFunctions? functionsInstance;

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
    String? editedDetail,
    ItemType? editedType,
    DateTime? editedDueDate,
    String? assignedTo,
  }) async {
    // 1. Primary path: Server-side callable function (transactional ratification)
    final functions = functionsInstance;
    if (functions != null) {
      try {
        final edits = <String, dynamic>{};
        if (editedTitle != null && editedTitle.trim().isNotEmpty) {
          edits['title'] = editedTitle.trim();
        }
        if (editedDetail != null) {
          edits['detail'] = editedDetail.trim();
        }
        if (editedType != null) {
          edits['type'] = editedType.value;
        }
        if (editedDueDate != null) {
          edits['dueDate'] = editedDueDate.toUtc().toIso8601String();
        }
        if (assignedTo != null) {
          edits['ownerUid'] = assignedTo;
        }

        await functions.httpsCallable('acceptProposal').call({
          'proposalId': proposal.id,
          if (edits.isNotEmpty) 'edits': edits,
        });
        return;
      } on FirebaseFunctionsException catch (fe) {
        if (fe.message != null && fe.message!.contains('sources-unavailable')) {
          throw const DataFailure(
            'Cannot ratify: All source messages for this proposal were deleted.',
            'sources-unavailable',
          );
        }
        if (fe.code == 'permission-denied') {
          throw const DataFailure(
            'You must be a current space member and the handoff requester to accept proposals.',
            'permission-denied',
          );
        }
        if (fe.code == 'failed-precondition') {
          throw DataFailure(
            fe.message ?? 'This proposal has expired or already been ratified.',
            'failed-precondition',
          );
        }
        throw DataFailure(
          'Failed to ratify proposal: ${fe.message ?? fe.code}',
          fe.code,
        );
      } catch (e) {
        throw DataFailure('Failed to ratify proposal: $e');
      }
    }

    // 2. Offline simulation fallback for testing
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

    final newStatus = (editedTitle != null && editedTitle != proposal.title)
        ? ProposalStatus.edited
        : ProposalStatus.approved;

    batch.update(proposalRef, {
      'status': newStatus.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final itemData = <String, dynamic>{
      'id': itemRef.id,
      'spaceId': spaceId,
      'type': (editedType ?? proposal.type).value,
      'title': title,
      'description':
          editedDetail ?? proposal.payload['description'] as String? ?? '',
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
    final functions = functionsInstance;
    if (functions != null) {
      try {
        await functions.httpsCallable('dismissProposal').call({
          'proposalId': proposalId,
        });
        return;
      } catch (e) {
        throw DataFailure('Failed to dismiss proposal: $e');
      }
    }

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
  final functions = ref.watch(firebaseFunctionsProvider);
  return FirestoreHandoffRepository(
    firestoreInstance: firestore,
    functionsInstance: functions,
  );
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
