import 'package:flutter/foundation.dart';

/// Space AI Policy
///
/// Enforces product invariants:
/// - Humans must approve proposals before becoming items
/// - Allowed proposal types (Tasks, Decisions, Questions)
@immutable
class AiPolicy {
  const AiPolicy({
    this.allowTasks = true,
    this.allowDecisions = true,
    this.allowQuestions = true,
    this.requireReviewBeforePublish = true,
    this.allowMemberHandoffs = true,
  });

  final bool allowTasks;
  final bool allowDecisions;
  final bool allowQuestions;
  final bool requireReviewBeforePublish;
  final bool allowMemberHandoffs;

  Map<String, dynamic> toMap() {
    return {
      'allowTasks': allowTasks,
      'allowDecisions': allowDecisions,
      'allowQuestions': allowQuestions,
      'requireReviewBeforePublish':
          true, // Strict invariant: cannot be overridden to false
      'allowMemberHandoffs': allowMemberHandoffs,
    };
  }

  factory AiPolicy.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AiPolicy();
    return AiPolicy(
      allowTasks: map['allowTasks'] as bool? ?? true,
      allowDecisions: map['allowDecisions'] as bool? ?? true,
      allowQuestions: map['allowQuestions'] as bool? ?? true,
      requireReviewBeforePublish: true, // Invariant enforced
      allowMemberHandoffs: map['allowMemberHandoffs'] as bool? ?? true,
    );
  }

  AiPolicy copyWith({
    bool? allowTasks,
    bool? allowDecisions,
    bool? allowQuestions,
    bool? allowMemberHandoffs,
  }) {
    return AiPolicy(
      allowTasks: allowTasks ?? this.allowTasks,
      allowDecisions: allowDecisions ?? this.allowDecisions,
      allowQuestions: allowQuestions ?? this.allowQuestions,
      requireReviewBeforePublish: true,
      allowMemberHandoffs: allowMemberHandoffs ?? this.allowMemberHandoffs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiPolicy &&
          runtimeType == other.runtimeType &&
          allowTasks == other.allowTasks &&
          allowDecisions == other.allowDecisions &&
          allowQuestions == other.allowQuestions &&
          requireReviewBeforePublish == other.requireReviewBeforePublish &&
          allowMemberHandoffs == other.allowMemberHandoffs;

  @override
  int get hashCode =>
      allowTasks.hashCode ^
      allowDecisions.hashCode ^
      allowQuestions.hashCode ^
      requireReviewBeforePublish.hashCode ^
      allowMemberHandoffs.hashCode;
}
