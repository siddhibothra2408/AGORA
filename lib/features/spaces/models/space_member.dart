import 'package:flutter/foundation.dart';

import '../../../core/utils/date_parser.dart';
import 'ai_consent_state.dart';

enum SpaceMemberRole { owner, admin, member }

extension SpaceMemberRoleExtension on SpaceMemberRole {
  String get value => switch (this) {
    SpaceMemberRole.owner => 'owner',
    SpaceMemberRole.admin => 'admin',
    SpaceMemberRole.member => 'member',
  };

  static SpaceMemberRole fromString(String? val) {
    if (val == 'owner') return SpaceMemberRole.owner;
    if (val == 'admin') return SpaceMemberRole.admin;
    return SpaceMemberRole.member;
  }
}

/// Space Member (stored at `spaces/{spaceId}/members/{uid}`)
@immutable
class SpaceMember {
  const SpaceMember({
    required this.uid,
    required this.spaceId,
    required this.displayName,
    required this.handle,
    this.photoUrl,
    this.role = SpaceMemberRole.member,
    this.consentState = MemberConsentState.consented,
    required this.joinedAt,
    this.lastReadAt,
  });

  final String uid;
  final String spaceId;
  final String displayName;
  final String handle;
  final String? photoUrl;
  final SpaceMemberRole role;
  final MemberConsentState consentState;
  final DateTime joinedAt;
  final DateTime? lastReadAt;

  bool get isOwner => role == SpaceMemberRole.owner;
  bool get isAdmin => role == SpaceMemberRole.admin || isOwner;
  bool get hasConsented => consentState == MemberConsentState.consented;

  SpaceMember copyWith({
    String? uid,
    String? spaceId,
    String? displayName,
    String? handle,
    String? photoUrl,
    SpaceMemberRole? role,
    MemberConsentState? consentState,
    DateTime? joinedAt,
    DateTime? lastReadAt,
  }) {
    return SpaceMember(
      uid: uid ?? this.uid,
      spaceId: spaceId ?? this.spaceId,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      consentState: consentState ?? this.consentState,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'spaceId': spaceId,
      'displayName': displayName,
      'handle': handle,
      'photoUrl': photoUrl,
      'role': role.value,
      'consentState': consentState.value,
      'joinedAt': DateParser.toFirestore(joinedAt),
      'lastReadAt': lastReadAt != null
          ? DateParser.toFirestore(lastReadAt!)
          : null,
    };
  }

  factory SpaceMember.fromMap(
    Map<String, dynamic> map,
    String uid,
    String spaceId,
  ) {
    return SpaceMember(
      uid: uid,
      spaceId: spaceId,
      displayName: map['displayName'] as String? ?? 'Member',
      handle: map['handle'] as String? ?? 'user',
      photoUrl: map['photoUrl'] as String?,
      role: SpaceMemberRoleExtension.fromString(map['role'] as String?),
      consentState: MemberConsentStateExtension.fromString(
        map['consentState'] as String?,
      ),
      joinedAt: DateParser.parse(map['joinedAt']),
      lastReadAt: map['lastReadAt'] != null
          ? DateParser.parse(map['lastReadAt'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpaceMember &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          spaceId == other.spaceId &&
          role == other.role &&
          consentState == other.consentState &&
          lastReadAt == other.lastReadAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      spaceId.hashCode ^
      role.hashCode ^
      consentState.hashCode ^
      (lastReadAt?.hashCode ?? 0);
}
