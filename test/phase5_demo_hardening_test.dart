import 'dart:io';

import 'package:agora/core/services/firebase_providers.dart';
import 'package:agora/core/theme/agora_colors.dart';
import 'package:agora/features/focus/screens/focus_screen.dart';
import 'package:agora/features/handoffs/repositories/handoff_repository.dart';
import 'package:agora/features/items/models/item.dart';
import 'package:agora/features/items/repositories/item_repository.dart';
import 'package:agora/features/pulse/screens/pulse_screen.dart';
import 'package:agora/features/spaces/models/ai_consent_state.dart';
import 'package:agora/features/spaces/models/ai_policy.dart';
import 'package:agora/features/spaces/models/catch_up_summary.dart';
import 'package:agora/features/spaces/models/space.dart';
import 'package:agora/features/spaces/models/space_member.dart';
import 'package:agora/features/spaces/repositories/space_repository.dart';
import 'package:agora/features/spaces/widgets/catch_up_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testSpaceId = 'space_capstone_smart_bin';
  const testRequesterUid = 'user_maya';
  const testAssigneeUid = 'user_ravi';
  final now = DateTime.utc(2026, 10, 15, 12, 0, 0);

  final testSpace = Space(
    id: testSpaceId,
    name: 'Capstone: Smart Bin',
    description: 'IoT telemetry and fill level tracking',
    charter: 'All members agree AI has zero ambient access.',
    createdBy: testRequesterUid,
    createdAt: now.subtract(const Duration(days: 3)),
    memberCount: 4,
    aiPolicy: const AiPolicy(),
  );

  final testMembers = [
    SpaceMember(
      uid: testRequesterUid,
      spaceId: testSpaceId,
      displayName: 'Maya Lin',
      handle: 'maya',
      role: SpaceMemberRole.owner,
      consentState: MemberConsentState.consented,
      joinedAt: now.subtract(const Duration(days: 3)),
      lastReadAt: now.subtract(const Duration(hours: 4)),
    ),
    SpaceMember(
      uid: testAssigneeUid,
      spaceId: testSpaceId,
      displayName: 'Ravi Patel',
      handle: 'ravi',
      role: SpaceMemberRole.member,
      consentState: MemberConsentState.consented,
      joinedAt: now.subtract(const Duration(days: 3)),
      lastReadAt: now.subtract(const Duration(hours: 2)),
    ),
  ];

  final overdueTask = Item(
    id: 'item_overdue_1',
    spaceId: testSpaceId,
    type: ItemType.task,
    title: 'Order ultrasonic sensors and brackets',
    description: 'Component purchase order for 4x HC-SR04 modules.',
    status: ItemStatus.open,
    origin: 'ai',
    ownerUid: testAssigneeUid,
    assignmentStatus: AssignmentStatus.accepted,
    dueDate: now.subtract(const Duration(days: 1)), // Overdue
    approvedByUid: testRequesterUid,
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now.subtract(const Duration(days: 2)),
  );

  final proposedTask = Item(
    id: 'item_proposed_1',
    spaceId: testSpaceId,
    type: ItemType.task,
    title: 'Measure bin lip dimensions',
    description:
        'Take caliper measurements of the 40-liter university bin rim.',
    status: ItemStatus.open,
    origin: 'ai',
    ownerUid: testAssigneeUid,
    assignmentStatus: AssignmentStatus.proposed, // Proposed for Ravi
    dueDate: now.add(const Duration(days: 2)),
    approvedByUid: testRequesterUid,
    createdAt: now.subtract(const Duration(hours: 5)),
    updatedAt: now.subtract(const Duration(hours: 5)),
  );

  final completedTask = Item(
    id: 'item_done_1',
    spaceId: testSpaceId,
    type: ItemType.task,
    title: 'Bench test IR sensor vs dark bags',
    description: 'Optical beam gets absorbed by black plastic liners.',
    status: ItemStatus.completed,
    origin: 'manual',
    ownerUid: testAssigneeUid,
    assignmentStatus: AssignmentStatus.accepted,
    approvedByUid: testRequesterUid,
    createdAt: now.subtract(const Duration(days: 3)),
    updatedAt: now.subtract(const Duration(days: 1)),
  );

  final decisionItem = Item(
    id: 'item_decision_1',
    spaceId: testSpaceId,
    type: ItemType.decision,
    title: 'Standardize on HC-SR04 ultrasonic sensor',
    description: 'Ultrasonic acoustic ping reflects reliably off dark plastic.',
    status: ItemStatus.open,
    origin: 'ai',
    approvedByUid: testRequesterUid,
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now.subtract(const Duration(days: 2)),
  );

  group('P1: Deterministic Catch-Up & Zero-Gold Aesthetics', () {
    testWidgets('CatchUpCard renders activity with Aegean blue and ZERO gold', (
      tester,
    ) async {
      bool dismissed = false;

      final summary = CatchUpSummary.calculate(
        lastReadAt: now.subtract(const Duration(days: 3)),
        messages: [],
        items: [overdueTask, decisionItem],
        handoffs: [],
        currentUserId: testAssigneeUid,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatchUpCard(
              spaceId: testSpaceId,
              summary: summary,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Since you were last here'), findsOneWidget);
      expect(find.text('2 items created'), findsOneWidget);
      expect(find.text('1 assigned to you'), findsOneWidget);
      expect(find.text('1 decisions recorded'), findsOneWidget);

      // Verify zero gold elements on CatchUpCard
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final container in containers) {
        final color = (container.decoration as BoxDecoration?)?.color;
        if (color != null) {
          expect(color, isNot(equals(AgoraColors.gold)));
          expect(color, isNot(equals(AgoraColors.goldContainer)));
        }
      }

      // Test dismiss action
      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);
    });

    testWidgets('First-ever visit (lastReadAt == null) displays nothing', (
      tester,
    ) async {
      final summary = CatchUpSummary.calculate(
        lastReadAt: null, // First-ever visit
        messages: [],
        items: [overdueTask],
        handoffs: [],
        currentUserId: testAssigneeUid,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatchUpCard(
              spaceId: testSpaceId,
              summary: summary,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Since you were last here'), findsNothing);
    });
  });

  group('P1: Focus Screen Fan-Out & Overdue Highlights', () {
    testWidgets(
      'Focus queue surfaces assigned tasks, overdue highlights, and proposed banner',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWith((ref) => testAssigneeUid),
              userSpacesProvider.overrideWith(
                (ref) => Stream.value([testSpace]),
              ),
              spaceItemsProvider((spaceId: testSpaceId, type: null))
                  .overrideWith(
                    (ref) => Stream.value([overdueTask, proposedTask]),
                  ),
              pendingProposalsProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value([])),
            ],
            child: const MaterialApp(home: FocusScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Overdue task rendered with warning badge
        expect(
          find.text('Order ultrasonic sensors and brackets'),
          findsOneWidget,
        );
        expect(find.text('OVERDUE'), findsOneWidget);

        // 2. Proposed assignment banner
        expect(find.text('Proposed For You'), findsOneWidget);
        expect(find.text('Measure bin lip dimensions'), findsOneWidget);
        expect(find.text('Accept Assignment'), findsOneWidget);
        expect(find.text('Decline'), findsOneWidget);
      },
    );
  });

  group('P1: Pulse Screen Determinism & Visualizations', () {
    testWidgets(
      'Pulse screen renders deterministic stats without external chart package',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentSpaceProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(testSpace)),
              spaceMembersProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value(testMembers)),
              spaceItemsProvider((spaceId: testSpaceId, type: null))
                  .overrideWith(
                    (ref) => Stream.value([
                      overdueTask,
                      proposedTask,
                      completedTask,
                      decisionItem,
                    ]),
                  ),
              spaceHandoffsProvider(testSpaceId)
                  .overrideWith((ref) => Stream.value([])),
            ],
            child: const MaterialApp(
              home: Scaffold(body: PulseScreen(spaceId: testSpaceId)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Space Pulse'), findsOneWidget);
        expect(find.text('DETERMINISTIC'), findsOneWidget);
        expect(find.text('Open Tasks'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('Requires attention'), findsOneWidget);
        expect(find.text('Decisions This Week'), findsOneWidget);
        expect(find.text('Open Tasks Distribution'), findsOneWidget);
      },
    );
  });

  group('P2: Hardening & Thesis Security Invariants', () {
    test('Zero Gemini API keys or SDK imports in client code', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          // Never contain GoogleGenAI SDK in Flutter
          expect(
            content.contains('GoogleGenAI'),
            isFalse,
            reason: 'GoogleGenAI found in ${entity.path}',
          );
          expect(
            content.contains('package:google_generative_ai'),
            isFalse,
            reason: 'Gemini client SDK found in ${entity.path}',
          );
          // Never contain raw API keys
          expect(
            content.contains('AIzaSy'),
            isFalse,
            reason: 'Hardcoded Gemini API key found in ${entity.path}',
          );
        }
      }
    });

    test('Zero End-to-End Encryption (E2EE) false claims in client lib', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final positiveE2eePattern = RegExp(
        r'(?<!NOT\s)(?<!not\s)(?<!never\s)(?<!non-)end-to-end\s*encrypt|(?<!NOT\s)(?<!not\s)(?<!never\s)(?<!non-)\bE2EE\b',
        caseSensitive: false,
      );

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          expect(
            positiveE2eePattern.hasMatch(content),
            isFalse,
            reason: 'Positive E2EE claim found in ${entity.path}',
          );
        }
      }
    });

    test('Zero message content logging in lib repository', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          // Ensure no print(message.text) or debugPrint(message.text)
          expect(
            RegExp(
              r'(?:print|debugPrint)\s*\([^)]*message\.text',
              caseSensitive: false,
            ).hasMatch(content),
            isFalse,
            reason: 'Logging message text found in ${entity.path}',
          );
        }
      }
    });
  });
}
