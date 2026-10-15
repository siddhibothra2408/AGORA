import 'package:flutter/foundation.dart';

import '../../../core/utils/date_parser.dart';

/// Explicit AI Handoff Record (stored at `spaces/{spaceId}/handoffs/{handoffId}`)
///
/// Implements auditability invariant:
/// Records exactly which messages were handed to the AI, by whom, and when.
@immutable
class Handoff {
  const Handoff({
    required this.id,
    required this.spaceId,
    required this.handedByUid,
    required this.handedByName,
    required this.messageIds,
    this.promptContext,
    required this.createdAt,
    this.auditLog = const {},
  });

  final String id;
  final String spaceId;
  final String handedByUid;
  final String handedByName;
  final List<String> messageIds;
  final String? promptContext;
  final DateTime createdAt;
  final Map<String, dynamic> auditLog;

  int get messageCount => messageIds.length;
  int get proposalCount => auditLog['proposalCount'] as int? ?? 0;
  int get acceptedCount => auditLog['acceptedCount'] as int? ?? 0;
  int get dismissedCount => auditLog['dismissedCount'] as int? ?? 0;
  int get withheldCount => auditLog['withheldCount'] as int? ?? 0;
  int get deletedCount => auditLog['deletedCount'] as int? ?? 0;
  String get provider => auditLog['provider'] as String? ?? 'gemini-1.5';
  String get status =>
      auditLog['status'] as String? ??
      (auditLog['dispatched'] == true ? 'dispatched' : 'completed');

  Handoff copyWith({
    String? id,
    String? spaceId,
    String? handedByUid,
    String? handedByName,
    List<String>? messageIds,
    String? promptContext,
    DateTime? createdAt,
    Map<String, dynamic>? auditLog,
  }) {
    return Handoff(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      handedByUid: handedByUid ?? this.handedByUid,
      handedByName: handedByName ?? this.handedByName,
      messageIds: messageIds ?? this.messageIds,
      promptContext: promptContext ?? this.promptContext,
      createdAt: createdAt ?? this.createdAt,
      auditLog: auditLog ?? this.auditLog,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spaceId': spaceId,
      'handedByUid': handedByUid,
      'handedByName': handedByName,
      'messageIds': messageIds,
      'promptContext': promptContext,
      'createdAt': DateParser.toFirestore(createdAt),
      'auditLog': auditLog,
    };
  }

  factory Handoff.fromMap(Map<String, dynamic> map, String id, String spaceId) {
    return Handoff(
      id: id,
      spaceId: spaceId,
      handedByUid: map['handedByUid'] as String? ?? '',
      handedByName: map['handedByName'] as String? ?? 'User',
      messageIds: List<String>.from(map['messageIds'] as List? ?? const []),
      promptContext: map['promptContext'] as String?,
      createdAt: DateParser.parse(map['createdAt']),
      auditLog: Map<String, dynamic>.from(map['auditLog'] as Map? ?? const {}),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Handoff &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          spaceId == other.spaceId &&
          handedByUid == other.handedByUid &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      spaceId.hashCode ^
      handedByUid.hashCode ^
      createdAt.hashCode;
}
