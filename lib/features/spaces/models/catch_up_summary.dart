import 'package:flutter/foundation.dart';

import '../../chat/models/message.dart';
import '../../handoffs/models/handoff.dart';
import '../../items/models/item.dart';

/// Deterministic Catch-Up Summary
///
/// Principles:
/// - Strictly non-AI, pure deterministic summary of activity since `lastReadAt`.
/// - If `lastReadAt` is null (first-ever visit), shows nothing.
/// - Returns accurate counts for messages, items created/assigned, decisions, completed, handoffs.
@immutable
class CatchUpSummary {
  const CatchUpSummary({
    required this.hasActivity,
    required this.newMessagesCount,
    required this.itemsCreatedCount,
    required this.itemsAssignedToYouCount,
    required this.decisionsMadeCount,
    required this.itemsCompletedCount,
    required this.handoffsRunCount,
    this.lastReadAt,
  });

  final bool hasActivity;
  final int newMessagesCount;
  final int itemsCreatedCount;
  final int itemsAssignedToYouCount;
  final int decisionsMadeCount;
  final int itemsCompletedCount;
  final int handoffsRunCount;
  final DateTime? lastReadAt;

  bool get shouldDisplay => hasActivity;

  int get totalChangesCount =>
      newMessagesCount +
      itemsCreatedCount +
      itemsAssignedToYouCount +
      decisionsMadeCount +
      itemsCompletedCount +
      handoffsRunCount;

  static CatchUpSummary calculate({
    required DateTime? lastReadAt,
    required List<Message> messages,
    required List<Item> items,
    required List<Handoff> handoffs,
    required String currentUserId,
  }) {
    if (lastReadAt == null) {
      // First-ever visit shows nothing
      return const CatchUpSummary(
        hasActivity: false,
        newMessagesCount: 0,
        itemsCreatedCount: 0,
        itemsAssignedToYouCount: 0,
        decisionsMadeCount: 0,
        itemsCompletedCount: 0,
        handoffsRunCount: 0,
        lastReadAt: null,
      );
    }

    final newMessages = messages
        .where((m) => m.createdAt.isAfter(lastReadAt))
        .length;
    final itemsCreated = items
        .where((i) => i.createdAt.isAfter(lastReadAt))
        .length;
    final itemsAssigned = items
        .where(
          (i) =>
              i.effectiveOwnerUid == currentUserId &&
              i.createdAt.isAfter(lastReadAt),
        )
        .length;
    final decisionsMade = items
        .where(
          (i) => i.type == ItemType.decision && i.createdAt.isAfter(lastReadAt),
        )
        .length;
    final itemsCompleted = items
        .where(
          (i) =>
              i.status == ItemStatus.completed &&
              i.updatedAt.isAfter(lastReadAt),
        )
        .length;
    final handoffsRun = handoffs
        .where((h) => h.createdAt.isAfter(lastReadAt))
        .length;

    final hasAny =
        newMessages > 0 ||
        itemsCreated > 0 ||
        itemsAssigned > 0 ||
        decisionsMade > 0 ||
        itemsCompleted > 0 ||
        handoffsRun > 0;

    return CatchUpSummary(
      hasActivity: hasAny,
      newMessagesCount: newMessages,
      itemsCreatedCount: itemsCreated,
      itemsAssignedToYouCount: itemsAssigned,
      decisionsMadeCount: decisionsMade,
      itemsCompletedCount: itemsCompleted,
      handoffsRunCount: handoffsRun,
      lastReadAt: lastReadAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatchUpSummary &&
          runtimeType == other.runtimeType &&
          hasActivity == other.hasActivity &&
          newMessagesCount == other.newMessagesCount &&
          itemsCreatedCount == other.itemsCreatedCount &&
          itemsAssignedToYouCount == other.itemsAssignedToYouCount &&
          decisionsMadeCount == other.decisionsMadeCount &&
          itemsCompletedCount == other.itemsCompletedCount &&
          handoffsRunCount == other.handoffsRunCount;

  @override
  int get hashCode =>
      hasActivity.hashCode ^
      newMessagesCount.hashCode ^
      itemsCreatedCount.hashCode ^
      itemsAssignedToYouCount.hashCode ^
      decisionsMadeCount.hashCode ^
      itemsCompletedCount.hashCode ^
      handoffsRunCount.hashCode;
}
