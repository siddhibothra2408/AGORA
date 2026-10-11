import 'package:flutter/foundation.dart';

import '../../items/models/item.dart';
import '../../spaces/models/space_member.dart';

/// Deterministic Pulse Metrics Model & Pure Calculation Engine
///
/// Principles:
/// - Strictly deterministic; zero AI extrapolation.
/// - Timezone-safe date-only arithmetic.
/// - Handles edge cases: empty items, all done, zero members.
@immutable
class PulseMetrics {
  const PulseMetrics({
    required this.openTasksCount,
    required this.doneTasksCount,
    required this.overdueCount,
    required this.staleTasksCount,
    required this.questionsOpenOver3DaysCount,
    required this.decisionsThisWeekCount,
    required this.perMemberOpenLoad,
    required this.sparkline14Days,
  });

  final int openTasksCount;
  final int doneTasksCount;
  final int overdueCount;
  final int staleTasksCount;
  final int questionsOpenOver3DaysCount;
  final int decisionsThisWeekCount;
  final Map<String, int> perMemberOpenLoad;
  final List<int> sparkline14Days;

  int get overdueTasksCount => overdueCount;
  int get openQuestionsOver3DaysCount => questionsOpenOver3DaysCount;
  List<int> get completionTrend14Days => sparkline14Days;

  bool get isEmpty =>
      openTasksCount == 0 &&
      doneTasksCount == 0 &&
      questionsOpenOver3DaysCount == 0 &&
      decisionsThisWeekCount == 0;

  double get taskCompletionRatio {
    final total = openTasksCount + doneTasksCount;
    if (total == 0) return 0.0;
    return doneTasksCount / total;
  }

  /// Normalizes a DateTime to date-only midnight (year, month, day)
  static DateTime normalizeDate(DateTime dt) {
    return DateTime.utc(dt.year, dt.month, dt.day);
  }

  /// Pure calculation function
  static PulseMetrics calculate({
    required List<Item> items,
    required List<SpaceMember> members,
    required DateTime now,
  }) {
    final today = normalizeDate(now);
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    final threeDaysAgo = today.subtract(const Duration(days: 3));

    int openTasks = 0;
    int doneTasks = 0;
    int overdue = 0;
    int staleTasks = 0;
    int questionsOpenOver3Days = 0;
    int decisionsThisWeek = 0;

    final memberLoad = <String, int>{};
    for (final member in members) {
      memberLoad[member.uid] = 0;
    }

    // 14 days sparkline slots: day 0 is 13 days ago, day 13 is today
    final sparkline = List<int>.filled(14, 0);

    for (final item in items) {
      final itemCreatedDate = normalizeDate(item.createdAt);
      final itemUpdatedDate = normalizeDate(item.updatedAt);

      if (item.isTask) {
        final isOpen =
            item.status == ItemStatus.open ||
            item.status == ItemStatus.inProgress;
        final isDone = item.status == ItemStatus.completed;

        if (isOpen) {
          openTasks++;

          // Overdue: due date in the past
          if (item.dueDate != null) {
            final due = normalizeDate(item.dueDate!);
            if (due.isBefore(today)) {
              overdue++;
            }
          }

          // Stale: not updated in 7 days
          if (itemUpdatedDate.isBefore(sevenDaysAgo)) {
            staleTasks++;
          }

          // Member load tracking
          final assignedUid = item.effectiveOwnerUid;
          if (assignedUid != null && assignedUid.isNotEmpty) {
            memberLoad[assignedUid] = (memberLoad[assignedUid] ?? 0) + 1;
          }
        } else if (isDone) {
          doneTasks++;

          // Completion date for sparkline
          final daysDiff = today.difference(itemUpdatedDate).inDays;
          if (daysDiff >= 0 && daysDiff < 14) {
            final index = 13 - daysDiff;
            sparkline[index] = sparkline[index] + 1;
          }
        }
      } else if (item.isQuestion) {
        if (item.status == ItemStatus.open) {
          if (itemCreatedDate.isBefore(threeDaysAgo)) {
            questionsOpenOver3Days++;
          }
        }
      } else if (item.isDecision) {
        if (!itemCreatedDate.isBefore(sevenDaysAgo)) {
          decisionsThisWeek++;
        }
      }
    }

    return PulseMetrics(
      openTasksCount: openTasks,
      doneTasksCount: doneTasks,
      overdueCount: overdue,
      staleTasksCount: staleTasks,
      questionsOpenOver3DaysCount: questionsOpenOver3Days,
      decisionsThisWeekCount: decisionsThisWeek,
      perMemberOpenLoad: memberLoad,
      sparkline14Days: sparkline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PulseMetrics &&
          runtimeType == other.runtimeType &&
          openTasksCount == other.openTasksCount &&
          doneTasksCount == other.doneTasksCount &&
          overdueCount == other.overdueCount &&
          staleTasksCount == other.staleTasksCount &&
          questionsOpenOver3DaysCount == other.questionsOpenOver3DaysCount &&
          decisionsThisWeekCount == other.decisionsThisWeekCount &&
          mapEquals(perMemberOpenLoad, other.perMemberOpenLoad) &&
          listEquals(sparkline14Days, other.sparkline14Days);

  @override
  int get hashCode =>
      openTasksCount.hashCode ^
      doneTasksCount.hashCode ^
      overdueCount.hashCode ^
      staleTasksCount.hashCode ^
      questionsOpenOver3DaysCount.hashCode ^
      decisionsThisWeekCount.hashCode;
}
