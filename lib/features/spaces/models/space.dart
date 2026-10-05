import 'package:flutter/foundation.dart';

import '../../../core/utils/date_parser.dart';
import 'ai_policy.dart';

/// Space Model (stored at `spaces/{spaceId}`)
@immutable
class Space {
  const Space({
    required this.id,
    required this.name,
    required this.description,
    required this.charter,
    required this.createdBy,
    required this.createdAt,
    this.memberCount = 1,
    this.aiPolicy = const AiPolicy(),
  });

  final String id;
  final String name;
  final String description;
  final String charter;
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;
  final AiPolicy aiPolicy;

  Space copyWith({
    String? id,
    String? name,
    String? description,
    String? charter,
    String? createdBy,
    DateTime? createdAt,
    int? memberCount,
    AiPolicy? aiPolicy,
  }) {
    return Space(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      charter: charter ?? this.charter,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      aiPolicy: aiPolicy ?? this.aiPolicy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name.trim(),
      'description': description.trim(),
      'charter': charter.trim(),
      'createdBy': createdBy,
      'createdAt': DateParser.toFirestore(createdAt),
      'memberCount': memberCount,
      'aiPolicy': aiPolicy.toMap(),
    };
  }

  factory Space.fromMap(Map<String, dynamic> map, String id) {
    return Space(
      id: id,
      name: map['name'] as String? ?? 'Untitled Space',
      description: map['description'] as String? ?? '',
      charter: map['charter'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: DateParser.parse(map['createdAt']),
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 1,
      aiPolicy: AiPolicy.fromMap(map['aiPolicy'] as Map<String, dynamic>?),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Space &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          charter == other.charter &&
          createdBy == other.createdBy &&
          memberCount == other.memberCount &&
          aiPolicy == other.aiPolicy;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      charter.hashCode ^
      createdBy.hashCode ^
      memberCount.hashCode ^
      aiPolicy.hashCode;
}
