import 'package:agora/features/chat/models/message.dart';
import 'package:agora/features/handoffs/models/proposal.dart';
import 'package:agora/features/handoffs/screens/private_results_screen.dart';
import 'package:agora/features/items/models/item.dart';
import 'package:agora/shared/design_system/agora_badge.dart';
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
          if (msg.senderId == requesterId)
            return true; // Binding Own-Message Exception
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
  });
}
