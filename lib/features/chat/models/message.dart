import 'package:flutter/foundation.dart';

import '../../../core/utils/date_parser.dart';

/// Agora Message Model (stored at `spaces/{spaceId}/messages/{messageId}`)
///
/// Implements consent-first invariant:
/// Message authors control whether their messages may be handed to AI.
/// Author consent is evaluated per member in backend consent module.
/// Messages support 15-minute edit windows, tombstones, item cards, and gold footprint markers.
@immutable
class Message {
  const Message({
    required this.id,
    required this.spaceId,
    required this.senderId,
    required this.senderHandle,
    required this.senderDisplayName,
    this.senderPhotoUrl,
    required this.text,
    required this.createdAt,
    this.aiWithheld = false,
    this.handoffHistory = const [],
    this.kind = 'text',
    this.replyToId,
    this.editedAt,
    this.deletedAt,
    this.aiSeenCount = 0,
    this.itemRef,
  });

  final String id;
  final String spaceId;
  final String senderId;
  final String senderHandle;
  final String senderDisplayName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime createdAt;
  final bool aiWithheld;
  final List<String> handoffHistory;
  final String kind; // 'text' | 'itemCard'
  final String? replyToId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final int aiSeenCount;
  final Map<String, dynamic>? itemRef;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;
  bool get isItemCard => kind == 'itemCard';

  Message copyWith({
    String? id,
    String? spaceId,
    String? senderId,
    String? senderHandle,
    String? senderDisplayName,
    String? senderPhotoUrl,
    String? text,
    DateTime? createdAt,
    bool? aiWithheld,
    List<String>? handoffHistory,
    String? kind,
    String? replyToId,
    DateTime? editedAt,
    DateTime? deletedAt,
    int? aiSeenCount,
    Map<String, dynamic>? itemRef,
  }) {
    return Message(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      senderId: senderId ?? this.senderId,
      senderHandle: senderHandle ?? this.senderHandle,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      aiWithheld: aiWithheld ?? this.aiWithheld,
      handoffHistory: handoffHistory ?? this.handoffHistory,
      kind: kind ?? this.kind,
      replyToId: replyToId ?? this.replyToId,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      aiSeenCount: aiSeenCount ?? this.aiSeenCount,
      itemRef: itemRef ?? this.itemRef,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spaceId': spaceId,
      'senderId': senderId,
      'senderHandle': senderHandle,
      'senderDisplayName': senderDisplayName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'createdAt': DateParser.toFirestore(createdAt),
      'aiWithheld': aiWithheld,
      'handoffHistory': handoffHistory,
      'kind': kind,
      if (replyToId != null) 'replyToId': replyToId,
      if (editedAt != null) 'editedAt': DateParser.toFirestore(editedAt!),
      if (deletedAt != null) 'deletedAt': DateParser.toFirestore(deletedAt!),
      'aiSeenCount': aiSeenCount,
      if (itemRef != null) 'itemRef': itemRef,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String id, String spaceId) {
    return Message(
      id: id,
      spaceId: spaceId,
      senderId: map['senderId'] as String? ?? '',
      senderHandle:
          map['senderHandle'] as String? ??
          (map['senderId'] as String? ?? 'user'),
      senderDisplayName:
          map['senderDisplayName'] as String? ??
          (map['senderId'] as String? ?? 'User'),
      senderPhotoUrl: map['senderPhotoUrl'] as String?,
      text: map['text'] as String? ?? '',
      createdAt: DateParser.parse(map['createdAt']),
      aiWithheld: map['aiWithheld'] as bool? ?? false,
      handoffHistory: List<String>.from(
        map['handoffHistory'] as List? ?? const [],
      ),
      kind: map['kind'] as String? ?? 'text',
      replyToId: map['replyToId'] as String?,
      editedAt: map['editedAt'] != null
          ? DateParser.parse(map['editedAt'])
          : null,
      deletedAt: map['deletedAt'] != null
          ? DateParser.parse(map['deletedAt'])
          : null,
      aiSeenCount: (map['aiSeenCount'] as num?)?.toInt() ?? 0,
      itemRef: map['itemRef'] != null
          ? Map<String, dynamic>.from(map['itemRef'] as Map)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          spaceId == other.spaceId &&
          senderId == other.senderId &&
          text == other.text &&
          aiWithheld == other.aiWithheld &&
          kind == other.kind &&
          aiSeenCount == other.aiSeenCount &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      spaceId.hashCode ^
      senderId.hashCode ^
      text.hashCode ^
      aiWithheld.hashCode ^
      kind.hashCode ^
      aiSeenCount.hashCode;
}
