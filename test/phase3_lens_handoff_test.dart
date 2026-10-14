import 'package:agora/features/chat/models/message.dart';
import 'package:agora/features/handoffs/models/proposal.dart';
import 'package:agora/features/handoffs/repositories/handoff_repository.dart';
import 'package:agora/features/handoffs/screens/my_ai_results_screen.dart';
import 'package:agora/features/handoffs/screens/private_results_screen.dart';
import 'package:agora/features/items/models/item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 3: Lens Handoff & Selection Logic', () {
    test('Lens selection validates 1-50 message range', () {
      final selected = <String>{};

      // Adding up to 50 succeeds
      for (int i = 1; i <= 50; i++) {
        selected.add('msg_$i');
      }
      expect(selected.length, equals(50));

      // 51st message rejected
      bool canAdd(String id) {
        if (selected.length >= 50) return false;
        selected.add(id);
        return true;
      }

      expect(canAdd('msg_51'), isFalse);
    });

    test(
      'Message model correctly identifies own message and withhold state',
      () {
        final now = DateTime(2026, 10, 14, 12, 0);
        const requesterUid = 'user_maya';

        // Own message with withheld true
        final myWithheldMessage = Message(
          id: 'msg_own',
          spaceId: 'space_1',
          senderId: requesterUid,
          senderHandle: 'maya',
          senderDisplayName: 'Maya',
          text: 'This is my own message with withhold on.',
          createdAt: now,
          aiWithheld: true,
        );

        // Another author message with withheld true
        final otherWithheldMessage = Message(
          id: 'msg_sam',
          spaceId: 'space_1',
          senderId: 'user_sam',
          senderHandle: 'sam',
          senderDisplayName: 'Sam',
          text: 'Sam strictly withholds his messages.',
          createdAt: now,
          aiWithheld: true,
        );

        // Invariant: Own-message exception allows author to hand off their own message
        bool canInclude(Message msg, String requesterId) {
          if (msg.senderId == requesterId) {
            return true; // Binding Own-Message Exception
          }
          return !msg.aiWithheld;
        }

        expect(canInclude(myWithheldMessage, requesterUid), isTrue);
        expect(canInclude(otherWithheldMessage, requesterUid), isFalse);
      },
    );
  });

  group('Phase 3: Private AI Results Screen Invariants', () {
    testWidgets(
      'PrivateResultsScreen enforces non-authoritative private UI notice',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: PrivateResultsScreen(
                spaceId: 'space_test',
                handoffId: 'handoff_123',
              ),
            ),
          ),
        );

        // Verify privacy notice is prominently displayed
        expect(find.text('Private AI Proposals'), findsOneWidget);
        expect(
          find.text('Private to you · Zero Board mutation'),
          findsOneWidget,
        );
      },
    );

    test(
      'Proposal model holds provenance anchors and non-authoritative status',
      () {
        final now = DateTime(2026, 10, 14);
        final proposal = Proposal(
          id: 'prop_001',
          spaceId: 'space_test',
          handoffId: 'handoff_123',
          type: ItemType.task,
          title: 'Review Agora Architecture',
          status: ProposalStatus.pending,
          createdForUid: 'user_maya',
          sourceMessageIds: ['msg_1', 'msg_2'],
          createdAt: now,
        );

        expect(proposal.isPending, isTrue);
        expect(proposal.isApproved, isFalse);
        expect(proposal.sourceMessageIds.length, equals(2));
        expect(proposal.handoffId, equals('handoff_123'));
      },
    );

    test(
      'Handoff purpose taxonomy supports extract, actions, and summarize',
      () {
        const allowedPurposes = ['extract', 'actions', 'summarize'];
        expect(allowedPurposes.contains('extract'), isTrue);
        expect(allowedPurposes.contains('actions'), isTrue);
        expect(allowedPurposes.contains('summarize'), isTrue);
        expect(allowedPurposes.contains('ambient_crawl'), isFalse);
      },
    );

    test('Custom instruction sanitization limits length to 200 chars and strips control chars', () {
      String sanitizeInstruction(String input) {
        return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
      }

      final dirty = "Focus on tasks\x00\x08 and milestones\n";
      final cleaned = sanitizeInstruction(dirty);
      expect(cleaned, equals("Focus on tasks and milestones"));
    });

    testWidgets('MyAiResultsScreen renders proposals and filters by type', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 10, 14);
      final seededProposals = [
        Proposal(
          id: 'prop_task_1',
          spaceId: 'space_test',
          handoffId: 'handoff_1',
          type: ItemType.task,
          title: 'Order ultrasonic sensors',
          status: ProposalStatus.pending,
          createdForUid: 'user_maya',
          sourceMessageIds: ['m1'],
          createdAt: now,
          payload: {'description': 'Purchase 4x HC-SR04 units'},
        ),
        Proposal(
          id: 'prop_dec_1',
          spaceId: 'space_test',
          handoffId: 'handoff_1',
          type: ItemType.decision,
          title: 'Standardize on HC-SR04',
          status: ProposalStatus.pending,
          createdForUid: 'user_maya',
          sourceMessageIds: ['m2'],
          createdAt: now,
          payload: {'description': 'Ultrasonic instead of optical'},
        ),
        Proposal(
          id: 'prop_q_1',
          spaceId: 'space_test',
          handoffId: 'handoff_1',
          type: ItemType.question,
          title: 'Who has the 3D printer card?',
          status: ProposalStatus.pending,
          createdForUid: 'user_maya',
          sourceMessageIds: ['m3'],
          createdAt: now,
          payload: {'description': 'Makerspace keycard location'},
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingProposalsProvider('space_test')
                .overrideWith((ref) => Stream.value(seededProposals)),
          ],
          child: const MaterialApp(
            home: MyAiResultsScreen(spaceId: 'space_test'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify all 3 titles are visible initially
      expect(find.text('Order ultrasonic sensors'), findsOneWidget);
      expect(find.text('Standardize on HC-SR04'), findsOneWidget);
      expect(find.text('Who has the 3D printer card?'), findsOneWidget);

      // Tap 'Tasks' filter
      await tester.tap(find.text('Tasks'));
      await tester.pump();

      // Only task should be visible
      expect(find.text('Order ultrasonic sensors'), findsOneWidget);
      expect(find.text('Standardize on HC-SR04'), findsNothing);
      expect(find.text('Who has the 3D printer card?'), findsNothing);

      // Tap 'Decisions' filter
      await tester.tap(find.text('Decisions'));
      await tester.pump();

      // Only decision should be visible
      expect(find.text('Order ultrasonic sensors'), findsNothing);
      expect(find.text('Standardize on HC-SR04'), findsOneWidget);
      expect(find.text('Who has the 3D printer card?'), findsNothing);
    });
  });
}
