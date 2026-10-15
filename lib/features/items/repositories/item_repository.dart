import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/firebase_providers.dart';
import '../models/item.dart';

abstract class ItemRepository {
  Stream<List<Item>> watchItems(String spaceId, {ItemType? type});
  Future<Item> createItem(Item item);
  Future<void> updateItemStatus(
    String spaceId,
    String itemId,
    ItemStatus status,
  );
  Future<void> updateAssignmentStatus(
    String spaceId,
    String itemId,
    AssignmentStatus status,
  );
}

class FirestoreItemRepository implements ItemRepository {
  FirestoreItemRepository({this.firestoreInstance, this.functionsInstance});

  final FirebaseFirestore? firestoreInstance;
  final FirebaseFunctions? functionsInstance;
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
  Stream<List<Item>> watchItems(String spaceId, {ItemType? type}) {
    if (firestoreInstance == null) return Stream.value([]);
    Query<Map<String, dynamic>> query = firestore
        .collection(FirestorePaths.spaceItems(spaceId))
        .orderBy('createdAt', descending: true);

    if (type != null) {
      query = query.where('type', isEqualTo: type.value);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Item.fromMap(doc.data(), doc.id, spaceId))
          .toList(),
    );
  }

  @override
  Future<Item> createItem(Item item) async {
    final functions = functionsInstance;
    if (functions != null) {
      try {
        final result = await functions.httpsCallable('createManualItem').call({
          'spaceId': item.spaceId,
          'type': item.type.value,
          'title': item.title,
          if (item.description.isNotEmpty) 'detail': item.description,
          if (item.effectiveOwnerUid != null)
            'ownerUid': item.effectiveOwnerUid,
          if (item.dueDate != null)
            'dueDate': item.dueDate!.toUtc().toIso8601String(),
          if (item.sourceMessageIds.isNotEmpty)
            'sourceMessageIds': item.sourceMessageIds,
        });

        final itemId = (result.data as Map?)?['itemId'] as String? ?? item.id;
        return item.copyWith(id: itemId);
      } catch (e) {
        throw DataFailure('Failed to create item via server: $e');
      }
    }

    final itemId = item.id.isEmpty ? _uuid.v4() : item.id;
    final itemToSave = item.copyWith(id: itemId);

    try {
      await firestore
          .doc(FirestorePaths.spaceItem(item.spaceId, itemId))
          .set(itemToSave.toMap());
      return itemToSave;
    } catch (e) {
      throw DataFailure('Failed to save item: $e');
    }
  }

  @override
  Future<void> updateItemStatus(
    String spaceId,
    String itemId,
    ItemStatus status,
  ) async {
    final functions = functionsInstance;
    if (functions != null) {
      String action = 'complete';
      if (status == ItemStatus.open) action = 'reopen';
      if (status == ItemStatus.completed) action = 'complete';
      if (status == ItemStatus.dismissed) action = 'drop';

      try {
        await functions.httpsCallable('updateItem').call({
          'spaceId': spaceId,
          'itemId': itemId,
          'action': action,
        });
        return;
      } catch (e) {
        throw DataFailure('Failed to update item via server: $e');
      }
    }

    try {
      await firestore.doc(FirestorePaths.spaceItem(spaceId, itemId)).update({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DataFailure('Failed to update item status: $e');
    }
  }

  @override
  Future<void> updateAssignmentStatus(
    String spaceId,
    String itemId,
    AssignmentStatus status,
  ) async {
    final functions = functionsInstance;
    if (functions != null) {
      try {
        await functions.httpsCallable('respondToAssignment').call({
          'spaceId': spaceId,
          'itemId': itemId,
          'accept': status == AssignmentStatus.accepted,
        });
        return;
      } catch (e) {
        throw DataFailure('Failed to update assignment via server: $e');
      }
    }

    try {
      await firestore.doc(FirestorePaths.spaceItem(spaceId, itemId)).update({
        'assignmentStatus': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DataFailure('Failed to update assignment status: $e');
    }
  }
}

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final functions = ref.watch(firebaseFunctionsProvider);
  return FirestoreItemRepository(
    firestoreInstance: firestore,
    functionsInstance: functions,
  );
});

final spaceItemsProvider =
    StreamProvider.family<List<Item>, ({String spaceId, ItemType? type})>((
      ref,
      arg,
    ) {
      final repo = ref.watch(itemRepositoryProvider);
      return repo.watchItems(arg.spaceId, type: arg.type);
    });
