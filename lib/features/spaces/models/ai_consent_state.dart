/// Member level AI consent state in a Space
enum MemberConsentState { consented, withheld }

extension MemberConsentStateExtension on MemberConsentState {
  String get value => switch (this) {
    MemberConsentState.consented => 'consented',
    MemberConsentState.withheld => 'withheld',
  };

  static MemberConsentState fromString(String? val) {
    if (val == 'withheld') return MemberConsentState.withheld;
    return MemberConsentState.consented;
  }
}
