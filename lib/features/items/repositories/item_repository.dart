import 'package:cloud_firestore/cloud_firestore.dart';
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
}

class FirestoreItemRepository implements ItemRepository {
  FirestoreItemRepository({this.firestoreInstance});

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
    try {
      await firestore.doc(FirestorePaths.spaceItem(spaceId, itemId)).update({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DataFailure('Failed to update item status: $e');
    }
  }
}

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreItemRepository(firestoreInstance: firestore);
});

final spaceItemsProvider =
    StreamProvider.family<List<Item>, ({String spaceId, ItemType? type})>((
      ref,
      arg,
    ) {
      final repo = ref.watch(itemRepositoryProvider);
      return repo.watchItems(arg.spaceId, type: arg.type);
    });
