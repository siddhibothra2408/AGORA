/// Base Agora Failure
sealed class Failure implements Exception {
  const Failure(this.message, [this.code]);
  final String message;
  final String? code;

  @override
  String toString() => 'Failure: $message (code: $code)';
}

/// Authentication Failures
class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.code]);

  factory AuthFailure.fromCode(String code) {
    return switch (code) {
      'user-not-found' => AuthFailure('No account found for this email.', code),
      'wrong-password' => AuthFailure('Incorrect password.', code),
      'email-already-in-use' => AuthFailure(
        'An account with this email already exists.',
        code,
      ),
      'invalid-email' => AuthFailure('Invalid email address.', code),
      'weak-password' => AuthFailure('Password is too weak.', code),
      'user-disabled' => AuthFailure('This account has been disabled.', code),
      'popup-closed-by-user' => AuthFailure(
        'Sign-in was cancelled before completion.',
        code,
      ),
      'sign_in_canceled' => AuthFailure('Sign-in cancelled.', code),
      _ => AuthFailure('Authentication error: $code', code),
    };
  }
}

/// Profile and Handle Reservation Failures
class ProfileFailure extends Failure {
  const ProfileFailure(super.message, [super.code]);

  factory ProfileFailure.handleTaken(String handle) => ProfileFailure(
    'The handle "@$handle" is already claimed.',
    'handle-taken',
  );

  factory ProfileFailure.invalidHandle() => const ProfileFailure(
    'Handle must be 3-20 characters, containing only letters, numbers, and underscores.',
    'invalid-handle',
  );
}

/// Space and Permission Failures
class SpaceFailure extends Failure {
  const SpaceFailure(super.message, [super.code]);

  factory SpaceFailure.permissionDenied() => const SpaceFailure(
    'Permission denied. You must be a member of this space.',
    'permission-denied',
  );

  factory SpaceFailure.notFound() => const SpaceFailure(
    'The requested space could not be found.',
    'not-found',
  );
}

/// Network or Database Failures
class DataFailure extends Failure {
  const DataFailure(super.message, [super.code]);
}
