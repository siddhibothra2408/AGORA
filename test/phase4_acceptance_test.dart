import 'dart:io';

import 'package:agora/core/services/firebase_providers.dart';
import 'package:agora/features/chat/models/message.dart';
import 'package:agora/features/chat/repositories/chat_repository.dart';
import 'package:agora/features/chat/screens/chat_screen.dart';
import 'package:agora/features/handoffs/models/handoff.dart';
import 'package:agora/features/handoffs/models/proposal.dart';
import 'package:agora/features/handoffs/repositories/handoff_repository.dart';
import 'package:agora/features/handoffs/screens/ai_ledger_screen.dart';
import 'package:agora/features/handoffs/widgets/proposal_tray_sheet.dart';
import 'package:agora/features/items/models/item.dart';
import 'package:agora/features/items/repositories/item_repository.dart';
import 'package:agora/features/items/screens/board_screen.dart';
import 'package:agora/features/items/widgets/item_receipts_sheet.dart';
import 'package:agora/features/profile/models/user_profile.dart';
import 'package:agora/features/profile/repositories/profile_repository.dart';
import 'package:agora/features/spaces/models/space_member.dart';
import 'package:agora/features/spaces/repositories/space_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testSpaceId = 'space_test_123';
  const testRequesterUid = 'user_requester';
  const testOtherUid = 'user_other';
  final now = DateTime(2026, 10, 15, 12, 0);

  final testMembers = [
    SpaceMember(
      uid: testRequesterUid,
      spaceId: testSpaceId,
      handle: 'requester',
      displayName: 'Requester Alice',
      role: SpaceMemberRole.admin,
      joinedAt: now.subtract(const Duration(days: 10)),
    ),
    SpaceMember(
      uid: testOtherUid,
      spaceId: testSpaceId,
      handle: 'bob',
      displayName: 'Bob Builder',
      role: SpaceMemberRole.member,
      joinedAt: now.subtract(const Duration(days: 5)),
    ),
  ];

  final activeSourceMsg = Message(
    id: 'msg_1',
    spaceId: testSpaceId,
    senderId: testOtherUid,
    senderHandle: 'bob',
    senderDisplayName: 'Bob Builder',
    text: 'We must ship the database migration by next Tuesday.',
    createdAt: now.subtract(const Duration(minutes: 20)),
    aiWithheld: false,
    aiSeenCount: 1,
  );

  final editedSourceMsg = Message(
    id: 'msg_2',
    spaceId: testSpaceId,
    senderId: testOtherUid,
    senderHandle: 'bob',
    senderDisplayName: 'Bob Builder',
    text: 'Updated: ship database migration by Wednesday.',
    createdAt: now.subtract(const Duration(minutes: 15)),
    editedAt: now.subtract(const Duration(minutes: 5)),
    aiWithheld: false,
    aiSeenCount: 1,
  );

  final deletedSourceMsg = Message(
    id: 'msg_3',
    spaceId: testSpaceId,
    senderId: testOtherUid,
    senderHandle: 'bob',
    senderDisplayName: 'Bob Builder',
    text: '',
    createdAt: now.subtract(const Duration(minutes: 10)),
    deletedAt: now.subtract(const Duration(minutes: 8)),
    aiWithheld: false,
  );

  final allMessages = [activeSourceMsg, editedSourceMsg, deletedSourceMsg];

  group('Proposal Tray & Ratification Invariants', () {
    testWidgets(
      'Renders proposal with title, detail, confidence, and source quotes',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final proposal = Proposal(
          id: 'prop_1',
          spaceId: testSpaceId,
          handoffId: 'handoff_1',
          type: ItemType.task,
          title: 'Ship database migration',
          payload: {
            'detail': 'Run schema scripts and verify indexes',
            'confidence': 'High confidence',
            'dueDate': '2026-10-20',
            'suggestedAssigneeName': 'Bob Builder',
            'suggestedAssigneeUid': testOtherUid,
          },
          status: ProposalStatus.pending,
          createdForUid: testRequesterUid,
          sourceMessageIds: ['msg_1'],
          createdAt: now.subtract(const Duration(minutes: 10)),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pendingProposalsProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value([proposal])),
              spaceMessagesProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(allMessages)),
              spaceMembersProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(testMembers)),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ProposalTraySheet(spaceId: testSpaceId)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Non-authoritative Gold Header
        expect(find.text('AI Proposals Tray'), findsOneWidget);
        expect(
          find.text('AI-generated · proposal · visible only to you'),
          findsOneWidget,
        );

        // Proposal content
        expect(find.text('Ship database migration'), findsOneWidget);
        expect(
          find.text('Run schema scripts and verify indexes'),
          findsOneWidget,
        );
        expect(find.text('High confidence'), findsOneWidget);
        expect(find.text('Assignee: Bob Builder'), findsOneWidget);

        // Grounding Quote
        expect(
          find.textContaining('We must ship the database migration'),
          findsOneWidget,
        );

        // Actions exist
        expect(find.widgetWithText(TextButton, 'Dismiss'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);
      },
    );

    testWidgets(
      'Honest Provenance: Deleted source message shows "Source message deleted"',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final proposalWithDeletedSource = Proposal(
          id: 'prop_deleted_source',
          spaceId: testSpaceId,
          handoffId: 'handoff_1',
          type: ItemType.task,
          title: 'Task with deleted source',
          status: ProposalStatus.pending,
          createdForUid: testRequesterUid,
          sourceMessageIds: ['msg_3'], // msg_3 is deleted
          createdAt: now.subtract(const Duration(minutes: 10)),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pendingProposalsProvider(testSpaceId).overrideWith(
                (ref) => Stream.value([proposalWithDeletedSource]),
              ),
              spaceMessagesProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(allMessages)),
              spaceMembersProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(testMembers)),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ProposalTraySheet(spaceId: testSpaceId)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Source message deleted'), findsOneWidget);
      },
    );

    testWidgets('Edited source message shows "edited since handoff" tag', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final proposal = Proposal(
        id: 'prop_edited_source',
        spaceId: testSpaceId,
        handoffId: 'handoff_1',
        type: ItemType.task,
        title: 'Task with edited source',
        status: ProposalStatus.pending,
        createdForUid: testRequesterUid,
        sourceMessageIds: ['msg_2'], // msg_2 was edited
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingProposalsProvider(testSpaceId)
                .overrideWith((ref) => Stream.value([proposal])),
            spaceMessagesProvider(testSpaceId)
                .overrideWith((ref) => Stream.value(allMessages)),
            spaceMembersProvider(testSpaceId)
                .overrideWith((ref) => Stream.value(testMembers)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProposalTraySheet(spaceId: testSpaceId)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('edited since handoff'), findsOneWidget);
    });
  });

  group('Board Screen & Gold Discipline Invariants', () {
    testWidgets(
      'AI-origin item renders Gold badge, manual item has ZERO gold',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final aiItem = Item(
          id: 'item_ai',
          spaceId: testSpaceId,
          type: ItemType.task,
          title: 'AI Proposed Task',
          description: 'Task proposed by AI and approved by Alice',
          status: ItemStatus.open,
          origin: 'ai',
          sourceHandoffId: 'handoff_1',
          sourceMessageIds: ['msg_1'],
          approvedByUid: testRequesterUid,
          createdAt: now,
          updatedAt: now,
        );

        final manualItem = Item(
          id: 'item_manual',
          spaceId: testSpaceId,
          type: ItemType.decision,
          title: 'Manual Decision',
          description: 'Decision created directly by Alice without AI',
          status: ItemStatus.open,
          origin: 'manual',
          sourceHandoffId: '',
          sourceMessageIds: [],
          createdBy: testRequesterUid,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              spaceItemsProvider((spaceId: testSpaceId, type: null))
                  .overrideWith((ref) => Stream.value([aiItem, manualItem])),
              spaceMembersProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(testMembers)),
              spaceMessagesProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value([])),
              spaceHandoffsProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value([])),
              currentUserIdProvider.overrideWith((ref) => testRequesterUid),
            ],
            child: const MaterialApp(home: BoardScreen(spaceId: testSpaceId)),
          ),
        );
        await tester.pumpAndSettle();

        // AI item displays AI-assisted origin chip with approver
        expect(
          find.textContaining('AI-assisted · approved by Requester Alice'),
          findsOneWidget,
        );

        // Manual item displays MANUAL ENTRY neutral badge
        expect(find.text('MANUAL ENTRY'), findsOneWidget);

        // Filter chips exist
        expect(find.text('All Items'), findsOneWidget);
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.text('Decisions'), findsOneWidget);
        expect(find.text('Questions'), findsOneWidget);
      },
    );

    testWidgets(
      'Proposed assignment for current user displays Accept / Decline actions',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final proposedItem = Item(
          id: 'item_proposed',
          spaceId: testSpaceId,
          type: ItemType.task,
          title: 'Review PR #42',
          description: 'Verify all changes in pull request',
          status: ItemStatus.open,
          origin: 'ai',
          sourceHandoffId: 'handoff_1',
          sourceMessageIds: ['msg_1'],
          approvedByUid: testRequesterUid,
          ownerUid: testOtherUid,
          assigneeUid: testOtherUid,
          assignmentStatus: AssignmentStatus.proposed,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              spaceItemsProvider((spaceId: testSpaceId, type: null))
                  .overrideWith((ref) => Stream.value([proposedItem])),
              spaceMembersProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(testMembers)),
              spaceMessagesProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value([])),
              spaceHandoffsProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value([])),
              currentUserIdProvider.overrideWith(
                (ref) => testOtherUid,
              ), // logged in as Bob
            ],
            child: const MaterialApp(home: BoardScreen(spaceId: testSpaceId)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Proposed assignment for you'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Decline'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Accept'), findsOneWidget);
      },
    );
  });

  group('Item Receipts Sheet & Provenance Context', () {
    testWidgets('Renders source anchor message and context before / after', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = Item(
        id: 'item_receipt_test',
        spaceId: testSpaceId,
        type: ItemType.task,
        title: 'Grounding Task',
        description: 'Grounding detail message',
        status: ItemStatus.open,
        origin: 'ai',
        sourceHandoffId: 'handoff_1',
        sourceMessageIds: ['msg_1'],
        approvedByUid: testRequesterUid,
        createdAt: now,
        updatedAt: now,
      );

      final handoff = Handoff(
        id: 'handoff_1',
        spaceId: testSpaceId,
        handedByUid: testRequesterUid,
        handedByName: 'Requester Alice',
        messageIds: ['msg_1'],
        createdAt: now.subtract(const Duration(minutes: 10)),
        auditLog: {'provider': 'gemini-1.5-pro', 'dispatched': true},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceMessagesProvider(testSpaceId)
                .overrideWith((ref) => Stream.value(allMessages)),
            spaceHandoffsProvider(testSpaceId)
                .overrideWith((ref) => Stream.value([handoff])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ItemReceiptsSheet(spaceId: testSpaceId, item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI-Assisted · Human Approved'), findsOneWidget);
      expect(find.text('AI Provenance Record'), findsOneWidget);
      expect(
        find.textContaining('Handed off by Requester Alice'),
        findsOneWidget,
      );
      expect(
        find.textContaining('SOURCE ANCHOR · Bob Builder'),
        findsOneWidget,
      );
      expect(
        find.textContaining('We must ship the database migration'),
        findsOneWidget,
      );
    });
  });

  group('Footprint Dot & AI Ledger Invariants', () {
    testWidgets(
      'Message with aiSeenCount > 0 renders gold footprint with semantics',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();

        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                spaceMessagesProvider(testSpaceId)
                    .overrideWith((ref) => Stream.value([activeSourceMsg])),
                spaceMembersProvider(testSpaceId)
                    .overrideWith((ref) => Stream.value(testMembers)),
                spaceMemberProvider((
                  spaceId: testSpaceId,
                  uid: testRequesterUid,
                )).overrideWith((ref) => Stream.value(testMembers.first)),
                spaceItemsProvider((spaceId: testSpaceId, type: null))
                    .overrideWith((ref) => Stream.value([])),
                spaceHandoffsProvider(testSpaceId)
                    .overrideWith((ref) => Stream.value([])),
                pendingProposalsProvider(testSpaceId)
                    .overrideWith((ref) => Stream.value([])),
                currentUserIdProvider.overrideWith((ref) => testRequesterUid),
                currentProfileProvider.overrideWith(
                  (ref) => Stream.value(
                    UserProfile(
                      uid: testRequesterUid,
                      handle: 'requester',
                      displayName: 'Requester Alice',
                      createdAt: now,
                      updatedAt: now,
                    ),
                  ),
                ),
              ],
              child: const MaterialApp(
                home: Scaffold(body: ChatScreen(spaceId: testSpaceId)),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Footprint badge
          expect(find.text('AI Seen'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  w.properties.label == 'Included in an AI handoff',
            ),
            findsOneWidget,
          );
        } finally {
          semanticsHandle.dispose();
        }
      },
    );

    testWidgets(
      'AI Ledger lists handoff records with live messages and integrity status',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final handoff = Handoff(
          id: 'handoff_ledger_1',
          spaceId: testSpaceId,
          handedByUid: testRequesterUid,
          handedByName: 'Requester Alice',
          messageIds: ['msg_1'],
          promptContext: 'Extract tasks, decisions, questions',
          createdAt: now.subtract(const Duration(minutes: 30)),
          auditLog: {
            'provider': 'gemini-1.5-pro',
            'proposalCount': 2,
            'acceptedCount': 1,
            'dismissedCount': 0,
            'withheldCount': 1,
            'deletedCount': 0,
            'dispatched': true,
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              spaceHandoffsProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value([handoff])),
              spaceMessagesProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(allMessages)),
              spaceItemsProvider((spaceId: testSpaceId, type: null))
                  .overrideWith((ref) => Stream.value([])),
            ],
            child: const MaterialApp(
              home: AiLedgerScreen(spaceId: testSpaceId),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('AI Handoff Ledger'), findsOneWidget);
        expect(find.text('Requested by Requester Alice'), findsOneWidget);
        expect(find.text('1 included'), findsOneWidget);
        expect(find.text('1 withheld'), findsOneWidget);
        expect(find.text('2 proposed'), findsOneWidget);
        expect(find.text('1 accepted'), findsOneWidget);
      },
    );
  });

  group('Phase 4 Thesis & Security Invariants', () {
    test('Zero Gemini API key in client lib directory', () {
      final libDir = Directory('lib');
      final files = libDir.listSync(recursive: true).whereType<File>();

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();
        expect(
          content.contains('AIzaSy'),
          isFalse,
          reason: 'Client file ${file.path} contains Google API key prefix!',
        );
      }
    });

    test('Zero End-to-End Encryption (E2EE) claims in client lib', () {
      final libDir = Directory('lib');
      final files = libDir.listSync(recursive: true).whereType<File>();

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();
        // Disallow asserting that Agora IS end-to-end encrypted or E2EE
        final matches = RegExp(
          r'(?<!NOT\s)(?<!not\s)(?<!never\s)end-to-end\s*encrypt',
          caseSensitive: false,
        ).allMatches(content);
        expect(
          matches.isEmpty,
          isTrue,
          reason:
              'Client file ${file.path} falsely claims End-to-End Encryption!',
        );
      }
    });
  });
}
