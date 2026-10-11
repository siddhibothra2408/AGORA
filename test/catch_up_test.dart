import 'package:agora/features/chat/models/message.dart';
import 'package:agora/features/handoffs/models/handoff.dart';
import 'package:agora/features/items/models/item.dart';
import 'package:agora/features/spaces/models/catch_up_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatchUpSummary Deterministic Calculation Tests', () {
    final t0 = DateTime.utc(2026, 10, 12, 10, 0, 0);
    final tPast = DateTime.utc(2026, 10, 12, 9, 0, 0);
    final tFuture = DateTime.utc(2026, 10, 12, 11, 0, 0);

    test('first-ever visit (lastReadAt == null) displays nothing', () {
      final summary = CatchUpSummary.calculate(
        lastReadAt: null,
        messages: [
          Message(
            id: 'm1',
            spaceId: 's1',
            senderId: 'user1',
            senderDisplayName: 'User 1',
            senderHandle: 'user1',
            text: 'Hello!',
            createdAt: tFuture,
          ),
        ],
        items: [],
        handoffs: [],
        currentUserId: 'me',
      );

      expect(summary.shouldDisplay, isFalse);
      expect(summary.lastReadAt, isNull);
      expect(summary.totalChangesCount, equals(0));
    });

    test('no activity since lastReadAt displays nothing', () {
      final summary = CatchUpSummary.calculate(
        lastReadAt: t0,
        messages: [
          Message(
            id: 'm1',
            spaceId: 's1',
            senderId: 'user1',
            senderDisplayName: 'User 1',
            senderHandle: 'user1',
            text: 'Old message',
            createdAt: tPast,
          ),
        ],
        items: [
          Item(
            id: 'i1',
            spaceId: 's1',
            type: ItemType.task,
            title: 'Old task',
            description: '',
            sourceHandoffId: '',
            sourceMessageIds: [],
            approvedByUid: 'user1',
            createdAt: tPast,
            updatedAt: tPast,
          ),
        ],
        handoffs: [],
        currentUserId: 'me',
      );

      expect(summary.shouldDisplay, isFalse);
      expect(summary.totalChangesCount, equals(0));
      expect(summary.newMessagesCount, equals(0));
    });

    test('correctly tallies new messages, items created, assigned to me, decisions, and handoffs', () {
      final messages = [
        Message(
          id: 'm1',
          spaceId: 's1',
          senderId: 'user1',
          senderDisplayName: 'User 1',
          senderHandle: 'user1',
          text: 'Message 1',
          createdAt: tFuture,
        ),
        Message(
          id: 'm2',
          spaceId: 's1',
          senderId: 'user2',
          senderDisplayName: 'User 2',
          senderHandle: 'user2',
          text: 'Message 2',
          createdAt: tFuture,
        ),
        Message(
          id: 'm0',
          spaceId: 's1',
          senderId: 'user1',
          senderDisplayName: 'User 1',
          senderHandle: 'user1',
          text: 'Past message',
          createdAt: tPast,
        ),
      ];

      final items = [
        Item(
          id: 'i1',
          spaceId: 's1',
          type: ItemType.task,
          title: 'Task for me',
          description: '',
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'user1',
          ownerUid: 'me',
          createdAt: tFuture,
          updatedAt: tFuture,
        ),
        Item(
          id: 'i2',
          spaceId: 's1',
          type: ItemType.decision,
          title: 'Decided sensor architecture',
          description: '',
          sourceHandoffId: 'h1',
          sourceMessageIds: ['m1'],
          approvedByUid: 'user1',
          ownerUid: 'other',
          createdAt: tFuture,
          updatedAt: tFuture,
        ),
        Item(
          id: 'i3',
          spaceId: 's1',
          type: ItemType.task,
          title: 'Task completed by someone',
          description: '',
          status: ItemStatus.completed,
          sourceHandoffId: '',
          sourceMessageIds: [],
          approvedByUid: 'user1',
          ownerUid: 'other',
          createdAt: tPast,
          updatedAt: tFuture, // Completed since lastReadAt
        ),
      ];

      final handoffs = [
        Handoff(
          id: 'h1',
          spaceId: 's1',
          handedByUid: 'user1',
          handedByName: 'User 1',
          messageIds: ['m1'],
          createdAt: tFuture,
        ),
      ];

      final summary = CatchUpSummary.calculate(
        lastReadAt: t0,
        messages: messages,
        items: items,
        handoffs: handoffs,
        currentUserId: 'me',
      );

      expect(summary.shouldDisplay, isTrue);
      expect(summary.newMessagesCount, equals(2));
      expect(summary.itemsCreatedCount, equals(2));
      expect(summary.itemsAssignedToYouCount, equals(1));
      expect(summary.decisionsMadeCount, equals(1));
      expect(summary.itemsCompletedCount, equals(1));
      expect(summary.handoffsRunCount, equals(1));
    });
  });
}
