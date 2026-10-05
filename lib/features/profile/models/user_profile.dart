import 'package:flutter/foundation.dart';

import '../../../core/utils/date_parser.dart';

/// Default AI consent preference at user level
enum DefaultAiConsent { optIn, withheld }

extension DefaultAiConsentExtension on DefaultAiConsent {
  String get value => switch (this) {
    DefaultAiConsent.optIn => 'opt_in',
    DefaultAiConsent.withheld => 'withheld',
  };

  static DefaultAiConsent fromString(String? val) {
    if (val == 'withheld') return DefaultAiConsent.withheld;
    return DefaultAiConsent.optIn;
  }
}

/// User Public Profile Model (stored at `profiles/{uid}`)
@immutable
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.handle,
    required this.displayName,
    this.photoUrl,
    this.bio,
    this.defaultAiConsent = DefaultAiConsent.optIn,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String handle;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final DefaultAiConsent defaultAiConsent;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? uid,
    String? handle,
    String? displayName,
    String? photoUrl,
    String? bio,
    DefaultAiConsent? defaultAiConsent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      defaultAiConsent: defaultAiConsent ?? this.defaultAiConsent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'handle': handle.toLowerCase().trim(),
      'displayName': displayName.trim(),
      'photoUrl': photoUrl,
      'bio': bio?.trim(),
      'defaultAiConsent': defaultAiConsent.value,
      'createdAt': DateParser.toFirestore(createdAt),
      'updatedAt': DateParser.toFirestore(updatedAt),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      handle: (map['handle'] as String? ?? '').toLowerCase(),
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      bio: map['bio'] as String?,
      defaultAiConsent: DefaultAiConsentExtension.fromString(
        map['defaultAiConsent'] as String?,
      ),
      createdAt: DateParser.parse(map['createdAt']),
      updatedAt: DateParser.parse(map['updatedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          handle == other.handle &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl &&
          bio == other.bio &&
          defaultAiConsent == other.defaultAiConsent;

  @override
  int get hashCode =>
      uid.hashCode ^
      handle.hashCode ^
      displayName.hashCode ^
      (photoUrl?.hashCode ?? 0) ^
      (bio?.hashCode ?? 0) ^
      defaultAiConsent.hashCode;
}
