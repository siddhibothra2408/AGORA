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

/// Source reference for an Item with freshness tracking
@immutable
class ItemSourceRef {
  const ItemSourceRef({
    required this.messageId,
    this.editedSinceHandoff = false,
  });

  final String messageId;
  final bool editedSinceHandoff;

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'editedSinceHandoff': editedSinceHandoff,
  };

  factory ItemSourceRef.fromMap(Map<String, dynamic> map) {
    return ItemSourceRef(
      messageId: map['messageId'] as String? ?? '',
      editedSinceHandoff: map['editedSinceHandoff'] as bool? ?? false,
    );
  }
}

/// Board Item Model (stored at `spaces/{spaceId}/items/{itemId}`)
///
/// Implements core provenance invariant:
/// Retains explicit links to [sourceRefs] and [sourceHandoffId].
/// Was approved by a human [approvedByUid] if origin is 'ai'.
@immutable
class Item {
  const Item({
    required this.id,
    required this.spaceId,
    required this.type,
    required this.title,
    required this.description,
    this.status = ItemStatus.open,
    this.origin = 'ai',
    this.sourceHandoffId = '',
    List<String>? sourceMessageIds,
    List<ItemSourceRef>? sourceRefs,
    this.approvedByUid = '',
    this.assigneeUid,
    this.ownerUid,
    this.dueDate,
    this.assignmentStatus = AssignmentStatus.accepted,
    this.editedByHuman = false,
    this.createdBy,
    this.updatedBy,
    this.approvedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  }) : _sourceMessageIds = sourceMessageIds ?? const [],
       sourceRefs = sourceRefs ?? const [];

  final String id;
  final String spaceId;
  final ItemType type;
  final String title;
  final String description;
  final ItemStatus status;
  final String origin;
  final String sourceHandoffId;
  final List<String> _sourceMessageIds;
  final List<ItemSourceRef> sourceRefs;
  final String approvedByUid;
  final String? assigneeUid;
  final String? ownerUid;
  final DateTime? dueDate;
  final AssignmentStatus assignmentStatus;
  final bool editedByHuman;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? approvedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Effective user owning or assigned to this item
  String? get effectiveOwnerUid => ownerUid ?? assigneeUid;

  String get detail => description;
  bool get isAiOrigin => origin == 'ai';
  bool get isManualOrigin => origin == 'manual';

  List<String> get sourceMessageIds => sourceRefs.isNotEmpty
      ? sourceRefs.map((r) => r.messageId).toList()
      : _sourceMessageIds;

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
    String? origin,
    String? sourceHandoffId,
    List<String>? sourceMessageIds,
    List<ItemSourceRef>? sourceRefs,
    String? approvedByUid,
    String? assigneeUid,
    String? ownerUid,
    DateTime? dueDate,
    AssignmentStatus? assignmentStatus,
    bool? editedByHuman,
    String? createdBy,
    String? updatedBy,
    DateTime? approvedAt,
    DateTime? resolvedAt,
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
      origin: origin ?? this.origin,
      sourceHandoffId: sourceHandoffId ?? this.sourceHandoffId,
      sourceMessageIds: sourceMessageIds ?? _sourceMessageIds,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      approvedByUid: approvedByUid ?? this.approvedByUid,
      assigneeUid: assigneeUid ?? this.assigneeUid,
      ownerUid: ownerUid ?? this.ownerUid,
      dueDate: dueDate ?? this.dueDate,
      assignmentStatus: assignmentStatus ?? this.assignmentStatus,
      editedByHuman: editedByHuman ?? this.editedByHuman,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
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
      'detail': description.trim(),
      'status': status.value,
      'origin': origin,
      'sourceHandoffId': sourceHandoffId,
      'sourceMessageIds': sourceMessageIds,
      'sourceRefs': sourceRefs.map((r) => r.toMap()).toList(),
      'approvedByUid': approvedByUid,
      'approvedBy': approvedByUid,
      'assigneeUid': assigneeUid,
      'ownerUid': ownerUid ?? assigneeUid,
      'dueDate': dueDate != null ? DateParser.toFirestore(dueDate!) : null,
      'assignmentStatus': assignmentStatus.value,
      'editedByHuman': editedByHuman,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'approvedAt': approvedAt != null
          ? DateParser.toFirestore(approvedAt!)
          : null,
      'resolvedAt': resolvedAt != null
          ? DateParser.toFirestore(resolvedAt!)
          : null,
      'createdAt': DateParser.toFirestore(createdAt),
      'updatedAt': DateParser.toFirestore(updatedAt),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map, String id, String spaceId) {
    // Parse sourceRefs if present, else fallback to sourceMessageIds
    List<ItemSourceRef> parsedRefs = const [];
    if (map['sourceRefs'] is List) {
      parsedRefs = (map['sourceRefs'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => ItemSourceRef.fromMap(m))
          .toList();
    }

    final rawSourceIds = List<String>.from(
      map['sourceMessageIds'] as List? ?? const [],
    );

    return Item(
      id: id,
      spaceId: spaceId,
      type: ItemTypeExtension.fromString(map['type'] as String?),
      title: map['title'] as String? ?? 'Untitled Item',
      description:
          map['detail'] as String? ?? map['description'] as String? ?? '',
      status: ItemStatusExtension.fromString(map['status'] as String?),
      origin: map['origin'] as String? ?? 'ai',
      sourceHandoffId:
          map['handoffId'] as String? ??
          map['sourceHandoffId'] as String? ??
          '',
      sourceMessageIds: rawSourceIds,
      sourceRefs: parsedRefs,
      approvedByUid:
          map['approvedBy'] as String? ?? map['approvedByUid'] as String? ?? '',
      assigneeUid: map['assigneeUid'] as String?,
      ownerUid: map['ownerUid'] as String? ?? map['assigneeUid'] as String?,
      dueDate: map['dueDate'] != null ? DateParser.parse(map['dueDate']) : null,
      assignmentStatus: AssignmentStatusExtension.fromString(
        map['assignmentStatus'] as String? ?? map['ownerState'] as String?,
      ),
      editedByHuman: map['editedByHuman'] as bool? ?? false,
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
      approvedAt: map['approvedAt'] != null
          ? DateParser.parse(map['approvedAt'])
          : null,
      resolvedAt: map['resolvedAt'] != null
          ? DateParser.parse(map['resolvedAt'])
          : null,
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
