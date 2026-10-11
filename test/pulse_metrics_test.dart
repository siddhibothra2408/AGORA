import 'package:agora/features/items/models/item.dart';
import 'package:agora/features/pulse/models/pulse_metrics.dart';
import 'package:agora/features/spaces/models/ai_consent_state.dart';
import 'package:agora/features/spaces/models/space_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PulseMetrics Deterministic Calculation Tests', () {
    final now = DateTime.utc(2026, 10, 15, 12, 0, 0);

    final members = [
      SpaceMember(
        uid: 'maya',
        spaceId: 's1',
        displayName: 'Maya Lin',
        handle: 'maya',
        role: SpaceMemberRole.owner,
        consentState: MemberConsentState.consented,
        joinedAt: DateTime.utc(2026, 10, 1),
      ),
      SpaceMember(
        uid: 'ravi',
        spaceId: 's1',
        displayName: 'Ravi Patel',
        handle: 'ravi',
        role: SpaceMemberRole.member,
        consentState: MemberConsentState.consented,
        joinedAt: DateTime.utc(2026, 10, 1),
      ),
    ];

    test('empty items returns zero metrics and 14-day zero sparkline', () {
      final metrics = PulseMetrics.calculate(
        items: [],
        members: members,
        now: now,
      );

      expect(metrics.openTasksCount, equals(0));
      expect(metrics.doneTasksCount, equals(0));
      expect(metrics.overdueTasksCount, equals(0));
      expect(metrics.staleTasksCount, equals(0));
      expect(metrics.openQuestionsOver3DaysCount, equals(0));
      expect(metrics.decisionsThisWeekCount, equals(0));
      expect(metrics.perMemberOpenLoad['maya'], equals(0));
      expect(metrics.perMemberOpenLoad['ravi'], equals(0));
      expect(metrics.completionTrend14Days.length, equals(14));
      expect(
        metrics.completionTrend14Days.every((count) => count == 0),
        isTrue,
      );
    });

    test('all items done produces 0 open tasks, 0 overdue, and updates completion trend', () {
      final items = [
        Item(
          id: 't1',
          spaceId: 's1',
          type: ItemType.task,
          title: 'Finished Task 1',
          description: '',
          status: ItemStatus.completed,
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'maya',
          ownerUid: 'maya',
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now, // Completed today
        ),
        Item(
          id: 't2',
          spaceId: 's1',
          type: ItemType.task,
          title: 'Finished Task 2',
          description: '',
          status: ItemStatus.completed,
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'ravi',
          ownerUid: 'ravi',
          createdAt: now.subtract(const Duration(days: 4)),
          updatedAt: now.subtract(
            const Duration(days: 1),
          ), // Completed yesterday
        ),
      ];

      final metrics = PulseMetrics.calculate(
        items: items,
        members: members,
        now: now,
      );

      expect(metrics.openTasksCount, equals(0));
      expect(metrics.doneTasksCount, equals(2));
      expect(metrics.overdueTasksCount, equals(0));
      expect(metrics.completionTrend14Days[13], equals(1)); // Today
      expect(metrics.completionTrend14Days[12], equals(1)); // Yesterday
    });

    test('computes overdue, stale tasks, open questions >3d, and decisions this week', () {
      final items = [
        // Overdue task (due yesterday)
        Item(
          id: 't_overdue',
          spaceId: 's1',
          type: ItemType.task,
          title: 'Draft wiring diagram',
          description: '',
          status: ItemStatus.open,
          dueDate: now.subtract(const Duration(days: 1)),
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'maya',
          ownerUid: 'maya',
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
        // Stale task (no update in 8 days)
        Item(
          id: 't_stale',
          spaceId: 's1',
          type: ItemType.task,
          title: 'Research sensor suppliers',
          description: '',
          status: ItemStatus.open,
          dueDate: now.add(const Duration(days: 5)),
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'ravi',
          ownerUid: 'ravi',
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
        // Question open > 3 days (created 4 days ago)
        Item(
          id: 'q1',
          spaceId: 's1',
          type: ItemType.question,
          title: 'Which microcontroller voltage?',
          description: '',
          status: ItemStatus.open,
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'maya',
          createdAt: now.subtract(const Duration(days: 4)),
          updatedAt: now.subtract(const Duration(days: 4)),
        ),
        // Decision this week (created 2 days ago)
        Item(
          id: 'd1',
          spaceId: 's1',
          type: ItemType.decision,
          title: 'Selected Ultrasonic HC-SR04',
          description: '',
          status: ItemStatus.open,
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'maya',
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      final metrics = PulseMetrics.calculate(
        items: items,
        members: members,
        now: now,
      );

      expect(metrics.openTasksCount, equals(2));
      expect(metrics.overdueTasksCount, equals(1));
      expect(metrics.staleTasksCount, equals(1));
      expect(metrics.openQuestionsOver3DaysCount, equals(1));
      expect(metrics.decisionsThisWeekCount, equals(1));
      expect(metrics.perMemberOpenLoad['maya'], equals(1));
      expect(metrics.perMemberOpenLoad['ravi'], equals(1));
    });

    test('timezone-free date-only handling aggregates cleanly across midnight boundaries', () {
      // 11:59pm vs 12:01am on the same UTC day
      final dt1 = DateTime.utc(2026, 10, 15, 0, 5, 0);
      final dt2 = DateTime.utc(2026, 10, 15, 23, 50, 0);

      final items = [
        Item(
          id: 't1',
          spaceId: 's1',
          type: ItemType.task,
          title: 'Early item',
          description: '',
          status: ItemStatus.completed,
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'maya',
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: dt1,
        ),
        Item(
          id: 't2',
          spaceId: 's1',
          type: ItemType.task,
          title: 'Late item',
          description: '',
          status: ItemStatus.completed,
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'maya',
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: dt2,
        ),
      ];

      final metrics = PulseMetrics.calculate(
        items: items,
        members: members,
        now: now,
      );

      // Both belong to "today" (index 13)
      expect(metrics.completionTrend14Days[13], equals(2));
    });
  });
}
