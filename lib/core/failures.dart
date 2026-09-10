/// Stable failure taxonomy (ARC-011). `code` is a machine string that must
/// never change once shipped; `message` is safe to show to a user and must
/// never contain server internals, stack traces, or personal data.
class Failure {
  const Failure(this.code, this.message);

  final String code;
  final String message;

  static const networkCode = 'NETWORK';
  static const unauthorizedCode = 'UNAUTHORIZED';
  static const forbiddenCode = 'FORBIDDEN';
  static const notFoundCode = 'NOT_FOUND';
  static const unsupportedCode = 'UNSUPPORTED';
  static const validationCode = 'VALIDATION';
  static const unknownCode = 'UNKNOWN';

  static const network = Failure(
    networkCode,
    'Studafy could not reach the school system. Check your connection and '
    'try again.',
  );
  static const unauthorized = Failure(
    unauthorizedCode,
    'Please sign in again.',
  );
  static const forbidden = Failure(
    forbiddenCode,
    'Your account does not have access to this.',
  );
  static const notFound = Failure(
    notFoundCode,
    'This record no longer exists.',
  );
  static const unknown = Failure(
    unknownCode,
    'Something went wrong. Please try again.',
  );

  const Failure.unsupported(String message) : this(unsupportedCode, message);
  const Failure.validation(String message) : this(validationCode, message);

  /// Maps an arbitrary caught error onto the taxonomy without leaking its
  /// text into user-presentable messages.
  static Failure fromError(Object error) => error is Failure ? error : unknown;
}
