/// Centralized Firestore Collection and Document Paths
abstract final class FirestorePaths {
  // Top-level collections
  static const String profiles = 'profiles';
  static const String handles = 'handles';
  static const String users = 'users';
  static const String devices = 'devices';
  static const String spaces = 'spaces';
  static const String proposals = 'proposals';
  static const String aiOutputs = 'aiOutputs';
  static const String invites = 'invites';

  // Specific documents
  static String profile(String uid) => '$profiles/$uid';
  static String handle(String handle) =>
      '$handles/${handle.toLowerCase().trim()}';
  static String user(String uid) => '$users/$uid';
  static String device(String deviceId) => '$devices/$deviceId';
  static String space(String spaceId) => '$spaces/$spaceId';
  static String proposal(String proposalId) => '$proposals/$proposalId';
  static String aiOutput(String handoffId) => '$aiOutputs/$handoffId';
  static String invite(String code) => '$invites/$code';

  // Space subcollections
  static String spaceMembers(String spaceId) => '$spaces/$spaceId/members';
  static String spaceMember(String spaceId, String uid) =>
      '$spaces/$spaceId/members/$uid';

  static String spaceMessages(String spaceId) => '$spaces/$spaceId/messages';
  static String spaceMessage(String spaceId, String messageId) =>
      '$spaces/$spaceId/messages/$messageId';

  static String spaceItems(String spaceId) => '$spaces/$spaceId/items';
  static String spaceItem(String spaceId, String itemId) =>
      '$spaces/$spaceId/items/$itemId';

  static String spaceHandoffs(String spaceId) => '$spaces/$spaceId/handoffs';
  static String spaceHandoff(String spaceId, String handoffId) =>
      '$spaces/$spaceId/handoffs/$handoffId';
}
