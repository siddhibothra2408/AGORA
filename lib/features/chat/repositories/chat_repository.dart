import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/firebase_providers.dart';
import '../../profile/models/user_profile.dart';
import '../models/message.dart';

abstract class ChatRepository {
  Stream<List<Message>> watchMessages(String spaceId);
  Future<Message> sendMessage({
    required String spaceId,
    required String text,
    required UserProfile sender,
    bool aiWithheld = false,
  });
  Future<void> setMessageWithhold({
    required String spaceId,
    required String messageId,
    required String userId,
    required bool aiWithheld,
  });
}

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({this.firestoreInstance});

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
  Stream<List<Message>> watchMessages(String spaceId) {
    if (firestoreInstance == null) return Stream.value([]);
    return firestore
        .collection(FirestorePaths.spaceMessages(spaceId))
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id, spaceId))
              .toList(),
        );
  }

  @override
  Future<Message> sendMessage({
    required String spaceId,
    required String text,
    required UserProfile sender,
    bool aiWithheld = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const DataFailure('Message cannot be empty.');
    }

    final messageId = _uuid.v4();
    final now = DateTime.now();

    final message = Message(
      id: messageId,
      spaceId: spaceId,
      senderId: sender.uid,
      senderHandle: sender.handle,
      senderDisplayName: sender.displayName,
      senderPhotoUrl: sender.photoUrl,
      text: trimmed,
      createdAt: now,
      aiWithheld: aiWithheld,
      handoffHistory: const [],
    );

    try {
      await firestore
          .doc(FirestorePaths.spaceMessage(spaceId, messageId))
          .set(message.toMap());
      return message;
    } catch (e) {
      throw DataFailure('Failed to send message: $e');
    }
  }

  @override
  Future<void> setMessageWithhold({
    required String spaceId,
    required String messageId,
    required String userId,
    required bool aiWithheld,
  }) async {
    try {
      final docRef = firestore.doc(
        FirestorePaths.spaceMessage(spaceId, messageId),
      );
      final doc = await docRef.get();
      if (!doc.exists) {
        throw const DataFailure('Message not found.');
      }
      final data = doc.data();
      if (data?['senderId'] != userId) {
        throw const DataFailure(
          'Security violation: You can only alter consent for your own messages.',
          'forbidden',
        );
      }

      await docRef.update({'aiWithheld': aiWithheld});
    } catch (e) {
      throw DataFailure('Failed to update consent status: $e');
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreChatRepository(firestoreInstance: firestore);
});

final spaceMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  spaceId,
) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchMessages(spaceId);
});
