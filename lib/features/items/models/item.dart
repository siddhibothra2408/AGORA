import 'package:flutter/foundation.dart';

import '../../../core/utils/date_parser.dart';

enum ItemType { task, decision, question }

extension ItemTypeExtension on ItemType {
  String get value => switch (this) {
    ItemType.task => 'task',
    ItemType.decision => 'decision',
    ItemType.question => 'question',
  };

  static ItemType fromString(String? val) {
    if (val == 'decision') return ItemType.decision;
    if (val == 'question') return ItemType.question;
    return ItemType.task;
  }
}

enum ItemStatus { open, inProgress, completed, dismissed }

extension ItemStatusExtension on ItemStatus {
  String get value => switch (this) {
    ItemStatus.open => 'open',
    ItemStatus.inProgress => 'in_progress',
    ItemStatus.completed => 'completed',
    ItemStatus.dismissed => 'dismissed',
  };

  static ItemStatus fromString(String? val) {
    if (val == 'in_progress') return ItemStatus.inProgress;
    if (val == 'completed') return ItemStatus.completed;
    if (val == 'dismissed') return ItemStatus.dismissed;
    return ItemStatus.open;
  }
}

enum AssignmentStatus { proposed, accepted, declined }

extension AssignmentStatusExtension on AssignmentStatus {
  String get value => switch (this) {
    AssignmentStatus.proposed => 'proposed',
    AssignmentStatus.accepted => 'accepted',
    AssignmentStatus.declined => 'declined',
  };

  static AssignmentStatus fromString(String? val) {
    if (val == 'proposed') return AssignmentStatus.proposed;
    if (val == 'declined') return AssignmentStatus.declined;
    return AssignmentStatus.accepted;
  }
}

/// Board Item Model (stored at `spaces/{spaceId}/items/{itemId}`)
///
/// Implements core provenance invariant:
/// Retains explicit links to [sourceMessageIds] and [sourceHandoffId].
/// Was approved by a human [approvedByUid].
@immutable
class Item {
  const Item({
    required this.id,
    required this.spaceId,
    required this.type,
    required this.title,
    required this.description,
    this.status = ItemStatus.open,
    required this.sourceHandoffId,
    required this.sourceMessageIds,
    required this.approvedByUid,
    this.assigneeUid,
    this.ownerUid,
    this.dueDate,
    this.assignmentStatus = AssignmentStatus.accepted,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String spaceId;
  final ItemType type;
  final String title;
  final String description;
  final ItemStatus status;
  final String sourceHandoffId;
  final List<String> sourceMessageIds;
  final String approvedByUid;
  final String? assigneeUid;
  final String? ownerUid;
  final DateTime? dueDate;
  final AssignmentStatus assignmentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Effective user owning or assigned to this item
  String? get effectiveOwnerUid => ownerUid ?? assigneeUid;

  bool get isTask => type == ItemType.task;
  bool get isDecision => type == ItemType.decision;
  bool get isQuestion => type == ItemType.question;

  Item copyWith({
    String? id,
    String? spaceId,
    ItemType? type,
    String? title,
    String? description,
    ItemStatus? status,
    String? sourceHandoffId,
    List<String>? sourceMessageIds,
    String? approvedByUid,
    String? assigneeUid,
    String? ownerUid,
    DateTime? dueDate,
    AssignmentStatus? assignmentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      sourceHandoffId: sourceHandoffId ?? this.sourceHandoffId,
      sourceMessageIds: sourceMessageIds ?? this.sourceMessageIds,
      approvedByUid: approvedByUid ?? this.approvedByUid,
      assigneeUid: assigneeUid ?? this.assigneeUid,
      ownerUid: ownerUid ?? this.ownerUid,
      dueDate: dueDate ?? this.dueDate,
      assignmentStatus: assignmentStatus ?? this.assignmentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spaceId': spaceId,
      'type': type.value,
      'title': title.trim(),
      'description': description.trim(),
      'status': status.value,
      'sourceHandoffId': sourceHandoffId,
      'sourceMessageIds': sourceMessageIds,
      'approvedByUid': approvedByUid,
      'assigneeUid': assigneeUid,
      'ownerUid': ownerUid ?? assigneeUid,
      'dueDate': dueDate != null ? DateParser.toFirestore(dueDate!) : null,
      'assignmentStatus': assignmentStatus.value,
      'createdAt': DateParser.toFirestore(createdAt),
      'updatedAt': DateParser.toFirestore(updatedAt),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map, String id, String spaceId) {
    return Item(
      id: id,
      spaceId: spaceId,
      type: ItemTypeExtension.fromString(map['type'] as String?),
      title: map['title'] as String? ?? 'Untitled Item',
      description: map['description'] as String? ?? '',
      status: ItemStatusExtension.fromString(map['status'] as String?),
      sourceHandoffId: map['sourceHandoffId'] as String? ?? '',
      sourceMessageIds: List<String>.from(
        map['sourceMessageIds'] as List? ?? const [],
      ),
      approvedByUid: map['approvedByUid'] as String? ?? '',
      assigneeUid: map['assigneeUid'] as String?,
      ownerUid: map['ownerUid'] as String? ?? map['assigneeUid'] as String?,
      dueDate: map['dueDate'] != null ? DateParser.parse(map['dueDate']) : null,
      assignmentStatus: AssignmentStatusExtension.fromString(
        map['assignmentStatus'] as String?,
      ),
      createdAt: DateParser.parse(map['createdAt']),
      updatedAt: DateParser.parse(map['updatedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          spaceId == other.spaceId &&
          type == other.type &&
          title == other.title &&
          status == other.status &&
          sourceHandoffId == other.sourceHandoffId &&
          ownerUid == other.ownerUid &&
          dueDate == other.dueDate &&
          assignmentStatus == other.assignmentStatus;

  @override
  int get hashCode =>
      id.hashCode ^
      spaceId.hashCode ^
      type.hashCode ^
      title.hashCode ^
      status.hashCode ^
      sourceHandoffId.hashCode ^
      (ownerUid?.hashCode ?? 0) ^
      (dueDate?.hashCode ?? 0) ^
      assignmentStatus.hashCode;
}
