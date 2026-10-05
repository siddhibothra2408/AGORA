import 'package:flutter/foundation.dart';

import '../../../core/utils/date_parser.dart';

/// Agora Message Model (stored at `spaces/{spaceId}/messages/{messageId}`)
///
/// Implements consent-first invariant:
/// Message authors have absolute veto to mark their message as [aiWithheld].
/// If [aiWithheld] is true, the message CANNOT be packaged or handed to AI.
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
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String id, String spaceId) {
    return Message(
      id: id,
      spaceId: spaceId,
      senderId: map['senderId'] as String? ?? '',
      senderHandle: map['senderHandle'] as String? ?? 'user',
      senderDisplayName: map['senderDisplayName'] as String? ?? 'User',
      senderPhotoUrl: map['senderPhotoUrl'] as String?,
      text: map['text'] as String? ?? '',
      createdAt: DateParser.parse(map['createdAt']),
      aiWithheld: map['aiWithheld'] as bool? ?? false,
      handoffHistory: List<String>.from(
        map['handoffHistory'] as List? ?? const [],
      ),
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
          aiWithheld == other.aiWithheld;

  @override
  int get hashCode =>
      id.hashCode ^
      spaceId.hashCode ^
      senderId.hashCode ^
      text.hashCode ^
      aiWithheld.hashCode;
}
