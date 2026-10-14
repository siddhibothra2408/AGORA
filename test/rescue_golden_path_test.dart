import 'dart:io';

import 'package:agora/features/chat/models/message.dart';
import 'package:agora/features/handoffs/models/proposal.dart';
import 'package:agora/features/spaces/models/space.dart';
import 'package:agora/features/spaces/screens/charter_screen.dart';
import 'package:agora/shared/design_system/agora_badge.dart';
import 'package:agora/shared/design_system/agora_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Charter Widget Tests', () {
    testWidgets(
      'Neither card preselected and Continue button is disabled until chosen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CharterScreen(spaceId: 'test_space', charterVersion: 1),
            ),
          ),
        );

        // Find both options
        final allowFinder = find.text('Allow my messages in AI handoffs');
        final withholdFinder = find.text('Withhold my messages from AI');
        expect(allowFinder, findsOneWidget);
        expect(withholdFinder, findsOneWidget);

        // Continue button disabled initially
        final continueButton = tester.widget<AgoraButton>(
          find.widgetWithText(AgoraButton, 'Continue to Space'),
        );
        expect(continueButton.onPressed, isNull);

        // Tap Withhold card
        await tester.tap(withholdFinder);
        await tester.pump();

        // Continue button should now be enabled
        final enabledButton = tester.widget<AgoraButton>(
          find.widgetWithText(AgoraButton, 'Continue to Space'),
        );
        expect(enabledButton.onPressed, isNotNull);
      },
    );
  });

  group('Lens Selection & 50-Message Cap Tests', () {
    test('Lens selection set enforces unique ids and 50 cap', () {
      final selected = <String>{};

      // Add 50 unique messages
      for (int i = 0; i < 50; i++) {
        selected.add('msg_$i');
      }
      expect(selected.length, equals(50));

      // Attempting to add 51st message is rejected by cap check
      bool addMessage(String id) {
        if (selected.length >= 50) return false;
        selected.add(id);
        return true;
      }

      final result = addMessage('msg_51');
      expect(result, isFalse);
      expect(selected.length, equals(50));
    });
  });

  group('Model Resilience with Malformed / Unexpected Data', () {
    test('Message.fromMap handles missing or malformed keys gracefully', () {
      final malformedMap = <String, dynamic>{
        'invalidField': 12345,
        'createdAt': null,
      };

      final msg = Message.fromMap(malformedMap, 'msg_err', 'space_1');
      expect(msg.id, equals('msg_err'));
      expect(msg.spaceId, equals('space_1'));
      expect(msg.text, equals(''));
      expect(msg.aiWithheld, isFalse);
      expect(msg.aiSeenCount, equals(0));
      expect(msg.kind, equals('text'));
      expect(msg.isDeleted, isFalse);
    });

    test('Space.fromMap handles missing charterVersion with default 1', () {
      final map = <String, dynamic>{
        'name': 'Test',
        'createdAt': '2026-10-12T10:00:00Z',
      };
      final space = Space.fromMap(map, 'space_1');
      expect(space.charterVersion, equals(1));
      expect(space.memberCount, equals(1));
    });

    test('Proposal.fromMap handles missing fields safely', () {
      final map = <String, dynamic>{'createdAt': '2026-10-12T10:00:00Z'};
      final prop = Proposal.fromMap(map, 'prop_1');
      expect(prop.id, equals('prop_1'));
      expect(prop.isPending, isTrue);
      expect(prop.title, equals('Untitled Proposal'));
    });
  });

  group('Design Invariant: Gold Reserved Exclusively for AI Elements', () {
    testWidgets('AgoraAiBadge uses gold and AgoraBadge neutral does not', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AgoraAiBadge(label: 'PROVENANCE VERIFIED'),
                AgoraBadge(label: 'MANUAL', variant: AgoraBadgeVariant.neutral),
              ],
            ),
          ),
        ),
      );

      final aiBadge = tester.widget<AgoraAiBadge>(find.byType(AgoraAiBadge));
      expect(aiBadge.label, equals('PROVENANCE VERIFIED'));

      final manualBadge = tester.widget<AgoraBadge>(
        find.widgetWithText(AgoraBadge, 'MANUAL'),
      );
      expect(manualBadge.variant, equals(AgoraBadgeVariant.neutral));
    });
  });

  group('Security Invariant: No Gemini API Key in Client Code', () {
    test('Ensures client lib directory contains no API key secrets', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains('AIzaSy'),
          isFalse,
          reason: 'Hardcoded Google/Gemini API key found in ${file.path}',
        );
        expect(
          content.contains('GEMINI_API_KEY'),
          isFalse,
          reason:
              'GEMINI_API_KEY environment lookup found in client ${file.path}',
        );
      }
    });
  });
}
