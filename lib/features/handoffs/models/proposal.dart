import 'package:flutter/foundation.dart';

import '../../../core/utils/date_parser.dart';
import '../../items/models/item.dart';

enum ProposalStatus { pending, approved, dismissed, edited }

extension ProposalStatusExtension on ProposalStatus {
  String get value => switch (this) {
    ProposalStatus.pending => 'pending',
    ProposalStatus.approved => 'approved',
    ProposalStatus.dismissed => 'dismissed',
    ProposalStatus.edited => 'edited',
  };

  static ProposalStatus fromString(String? val) {
    if (val == 'approved') return ProposalStatus.approved;
    if (val == 'dismissed') return ProposalStatus.dismissed;
    if (val == 'edited') return ProposalStatus.edited;
    return ProposalStatus.pending;
  }
}

/// AI Proposal Model (stored at `proposals/{proposalId}`)
///
/// Implements non-authoritative invariant:
/// AI outputs are strictly Proposals. They have NO system authority
/// until a human explicitly reviews, edits, or approves them.
@immutable
class Proposal {
  const Proposal({
    required this.id,
    required this.spaceId,
    required this.handoffId,
    required this.type,
    required this.title,
    this.payload = const {},
    this.status = ProposalStatus.pending,
    required this.createdForUid,
    required this.sourceMessageIds,
    required this.createdAt,
  });

  final String id;
  final String spaceId;
  final String handoffId;
  final ItemType type;
  final String title;
  final Map<String, dynamic> payload;
  final ProposalStatus status;
  final String createdForUid;
  final List<String> sourceMessageIds;
  final DateTime createdAt;

  bool get isPending => status == ProposalStatus.pending;
  bool get isApproved => status == ProposalStatus.approved;
  bool get isDismissed => status == ProposalStatus.dismissed;

  String get detail =>
      payload['detail'] as String? ?? payload['description'] as String? ?? '';

  String? get confidence {
    if (payload['confidence'] != null) {
      return payload['confidence'].toString();
    }
    if (payload['confidenceScore'] != null) {
      return '${((payload['confidenceScore'] as num) * 100).toInt()}%';
    }
    return null;
  }

  String? get suggestedAssigneeUid =>
      payload['suggestedAssigneeUid'] as String?;
  String? get suggestedAssigneeName =>
      payload['suggestedAssigneeName'] as String?;

  DateTime? get dueDate {
    if (payload['dueDate'] == null) return null;
    return DateTime.tryParse(payload['dueDate'].toString());
  }

  bool get confirmDate =>
      payload['confirmDate'] as bool? ??
      payload['needsDateConfirmation'] as bool? ??
      false;

  String? get quote => payload['quote'] as String?;

  Proposal copyWith({
    String? id,
    String? spaceId,
    String? handoffId,
    ItemType? type,
    String? title,
    Map<String, dynamic>? payload,
    ProposalStatus? status,
    String? createdForUid,
    List<String>? sourceMessageIds,
    DateTime? createdAt,
  }) {
    return Proposal(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      handoffId: handoffId ?? this.handoffId,
      type: type ?? this.type,
      title: title ?? this.title,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      createdForUid: createdForUid ?? this.createdForUid,
      sourceMessageIds: sourceMessageIds ?? this.sourceMessageIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spaceId': spaceId,
      'handoffId': handoffId,
      'type': type.value,
      'title': title.trim(),
      'payload': payload,
      'status': status.value,
      'createdForUid': createdForUid,
      'sourceMessageIds': sourceMessageIds,
      'createdAt': DateParser.toFirestore(createdAt),
    };
  }

  factory Proposal.fromMap(Map<String, dynamic> map, String id) {
    return Proposal(
      id: id,
      spaceId: map['spaceId'] as String? ?? '',
      handoffId: map['handoffId'] as String? ?? '',
      type: ItemTypeExtension.fromString(map['type'] as String?),
      title: map['title'] as String? ?? 'Untitled Proposal',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
      status: ProposalStatusExtension.fromString(map['status'] as String?),
      createdForUid: map['createdForUid'] as String? ?? '',
      sourceMessageIds: List<String>.from(
        map['sourceMessageIds'] as List? ?? const [],
      ),
      createdAt: DateParser.parse(map['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Proposal &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          spaceId == other.spaceId &&
          handoffId == other.handoffId &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^ spaceId.hashCode ^ handoffId.hashCode ^ status.hashCode;
}
