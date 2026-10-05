import 'package:agora/core/theme/agora_colors.dart';
import 'package:agora/core/theme/agora_spacing.dart';
import 'package:agora/shared/design_system/agora_badge.dart';
import 'package:agora/shared/design_system/agora_button.dart';
import 'package:agora/shared/design_system/agora_card.dart';
import 'package:agora/shared/design_system/agora_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AgoraButton meets 48dp minimum touch target', (
    WidgetTester tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AgoraButton(
              label: 'Commit Item',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    final buttonFinder = find.byType(AgoraButton);
    expect(buttonFinder, findsOneWidget);

    final size = tester.getSize(buttonFinder);
    expect(size.height, greaterThanOrEqualTo(AgoraSpacing.minTouchTarget));

    await tester.tap(buttonFinder);
    expect(tapped, isTrue);
  });

  testWidgets('AgoraConsentBadge renders withhold and eligible states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AgoraConsentBadge(isWithheld: true),
              AgoraConsentBadge(isWithheld: false),
            ],
          ),
        ),
      ),
    );

    expect(find.text('AI WITHHELD'), findsOneWidget);
    expect(find.text('ELIGIBLE'), findsOneWidget);
  });

  testWidgets('AgoraAiBadge displays gold accent', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AgoraAiBadge(label: 'PROPOSAL VERIFIED')),
        ),
      ),
    );

    expect(find.text('PROPOSAL VERIFIED'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
  });

  testWidgets('AgoraCard renders content with border styling', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AgoraCard(
            backgroundColor: AgoraColors.surface,
            child: Text('Card Content'),
          ),
        ),
      ),
    );

    expect(find.text('Card Content'), findsOneWidget);
  });

  testWidgets('AgoraEmptyState renders action button and fires callback', (
    WidgetTester tester,
  ) async {
    bool actionClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgoraEmptyState(
            title: 'Quiet Space',
            message: 'Nothing here yet.',
            actionLabel: 'Create Space',
            onAction: () => actionClicked = true,
          ),
        ),
      ),
    );

    expect(find.text('Quiet Space'), findsOneWidget);
    expect(find.text('Create Space'), findsOneWidget);

    await tester.tap(find.text('Create Space'));
    expect(actionClicked, isTrue);
  });
}
