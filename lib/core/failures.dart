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
  ///
  /// Errors that already know their own place in the taxonomy say so by
  /// implementing [FailureConvertible]. The dependency points that way round
  /// on purpose: a transport may name its failures in these terms, but this
  /// file stays free of transport and platform imports.
  static Failure fromError(Object error) => switch (error) {
    Failure() => error,
    FailureConvertible() => error.failure,
    _ => unknown,
  };
}

/// An error that carries its own taxonomy entry.
///
/// Implemented by errors raised outside this layer — an API envelope, a lost
/// connection — so they reach the user as the right [Failure] instead of
/// collapsing into [Failure.unknown] and saying nothing.
abstract interface class FailureConvertible {
  Failure get failure;
}
