import 'package:agora/core/utils/date_parser.dart';
import 'package:agora/features/chat/models/message.dart';
import 'package:agora/features/handoffs/models/handoff.dart';
import 'package:agora/features/handoffs/models/proposal.dart';
import 'package:agora/features/items/models/item.dart';
import 'package:agora/features/profile/models/user_profile.dart';
import 'package:agora/features/spaces/models/ai_consent_state.dart';
import 'package:agora/features/spaces/models/ai_policy.dart';
import 'package:agora/features/spaces/models/space.dart';
import 'package:agora/features/spaces/models/space_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateParser Tests', () {
    test('parses ISO strings and numeric timestamps properly', () {
      final now = DateTime(2026, 10, 6, 12, 0, 0);
      expect(DateParser.parse(now.toIso8601String()), equals(now));
      expect(DateParser.parse(now.millisecondsSinceEpoch), equals(now));
    });
  });

  group('UserProfile Model Tests', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime(2026, 10, 6);
      final profile = UserProfile(
        uid: 'user_123',
        handle: 'alex',
        displayName: 'Alex Morgan',
        bio: 'CS Student',
        defaultAiConsent: DefaultAiConsent.withheld,
        createdAt: now,
        updatedAt: now,
      );

      final map = profile.toMap();
      expect(map['handle'], equals('alex'));
      expect(map['defaultAiConsent'], equals('withheld'));

      final reconstructed = UserProfile.fromMap(map, 'user_123');
      expect(reconstructed.uid, equals(profile.uid));
      expect(reconstructed.handle, equals('alex'));
      expect(reconstructed.defaultAiConsent, equals(DefaultAiConsent.withheld));
    });
  });

  group('Space & Policy Model Tests', () {
    test('enforces requireReviewBeforePublish invariant on AiPolicy', () {
      const policy = AiPolicy();
      expect(policy.requireReviewBeforePublish, isTrue);

      final map = policy.toMap();
      expect(map['requireReviewBeforePublish'], isTrue);

      // Even if raw map attempts to pass false, domain model forces true
      final imported = AiPolicy.fromMap({'requireReviewBeforePublish': false});
      expect(imported.requireReviewBeforePublish, isTrue);
    });

    test('creates Space with AiPolicy correctly', () {
      final now = DateTime(2026, 10, 6);
      final space = Space(
        id: 'space_456',
        name: 'Capstone Agora',
        description: 'Testing consent boundaries',
        charter: 'Zero ambient AI.',
        createdBy: 'user_123',
        createdAt: now,
        memberCount: 3,
      );

      final map = space.toMap();
      final reconstructed = Space.fromMap(map, 'space_456');
      expect(reconstructed.name, equals('Capstone Agora'));
      expect(reconstructed.aiPolicy.requireReviewBeforePublish, isTrue);
    });

    test('SpaceMember consent state handles withheld and consented', () {
      final now = DateTime(2026, 10, 6);
      final member = SpaceMember(
        uid: 'user_123',
        spaceId: 'space_456',
        displayName: 'Alex',
        handle: 'alex',
        role: SpaceMemberRole.owner,
        consentState: MemberConsentState.withheld,
        joinedAt: now,
      );

      expect(member.isOwner, isTrue);
      expect(member.hasConsented, isFalse);

      final map = member.toMap();
      expect(map['consentState'], equals('withheld'));

      final parsed = SpaceMember.fromMap(map, 'user_123', 'space_456');
      expect(parsed.consentState, equals(MemberConsentState.withheld));
    });
  });

  group('Message Consent & Invariants Tests', () {
    test('withheld flag prevents AI ingestion', () {
      final now = DateTime(2026, 10, 6);
      final message = Message(
        id: 'msg_1',
        spaceId: 'space_456',
        senderId: 'user_123',
        senderHandle: 'alex',
        senderDisplayName: 'Alex',
        text: 'This message has author withhold shield on.',
        createdAt: now,
        aiWithheld: true,
      );

      expect(message.aiWithheld, isTrue);
      final map = message.toMap();
      expect(map['aiWithheld'], isTrue);

      final parsed = Message.fromMap(map, 'msg_1', 'space_456');
      expect(parsed.aiWithheld, isTrue);
    });
  });

  group('Item Provenance Tests', () {
    test('retains explicit source message IDs and handoff ID', () {
      final now = DateTime(2026, 10, 6);
      final item = Item(
        id: 'item_789',
        spaceId: 'space_456',
        type: ItemType.task,
        title: 'Review Agora Architecture',
        description: 'Verify zero ambient AI invariants.',
        sourceHandoffId: 'handoff_001',
        sourceMessageIds: ['msg_1', 'msg_2'],
        approvedByUid: 'user_123',
        createdAt: now,
        updatedAt: now,
      );

      expect(item.isTask, isTrue);
      expect(item.sourceMessageIds.length, equals(2));
      expect(item.sourceHandoffId, equals('handoff_001'));
      expect(item.approvedByUid, equals('user_123'));

      final map = item.toMap();
      final parsed = Item.fromMap(map, 'item_789', 'space_456');
      expect(parsed.sourceMessageIds, containsAll(['msg_1', 'msg_2']));
    });
  });

  group('Handoff & Proposal Tests', () {
    test('Handoff holds auditable message list', () {
      final now = DateTime(2026, 10, 6);
      final handoff = Handoff(
        id: 'handoff_001',
        spaceId: 'space_456',
        handedByUid: 'user_123',
        handedByName: 'Alex',
        messageIds: ['msg_1', 'msg_2'],
        createdAt: now,
      );

      expect(handoff.messageCount, equals(2));
      final map = handoff.toMap();
      final parsed = Handoff.fromMap(map, 'handoff_001', 'space_456');
      expect(parsed.messageIds.length, equals(2));
    });

    test('Proposal starts in pending status and holds provenance', () {
      final now = DateTime(2026, 10, 6);
      final proposal = Proposal(
        id: 'prop_001',
        spaceId: 'space_456',
        handoffId: 'handoff_001',
        type: ItemType.decision,
        title: 'Adopt Aegean Blue and Gold System',
        status: ProposalStatus.pending,
        createdForUid: 'user_123',
        sourceMessageIds: ['msg_1'],
        createdAt: now,
      );

      expect(proposal.isPending, isTrue);
      expect(proposal.isApproved, isFalse);
    });
  });
}
