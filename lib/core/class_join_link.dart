/// The shape of a shareable class join link (JOIN-052).
///
/// One definition serves both ends: the teacher's screen builds a link from
/// it and the student's entry point parses one with it, so the format cannot
/// drift between the side that writes links and the side that reads them.
///
/// The custom scheme matches the one already registered for the OAuth
/// callback. An owned HTTPS link would survive being pasted into a browser
/// on a device without the app, and is the better long-term form, but it
/// needs domain verification that is not in place yet.
library;

const classJoinLinkScheme = 'io.studafy.app';
const classJoinLinkHost = 'join';
const classJoinTokenParameter = 't';

/// Builds the link a teacher shares for [token].
String classJoinLinkUrl(String token) => Uri(
  scheme: classJoinLinkScheme,
  host: classJoinLinkHost,
  queryParameters: {classJoinTokenParameter: token},
).toString();

/// Whether [uri] is a class join link rather than somewhere to navigate.
bool isClassJoinLink(Uri uri) =>
    uri.scheme == classJoinLinkScheme &&
    uri.host == classJoinLinkHost &&
    (uri.queryParameters[classJoinTokenParameter]?.isNotEmpty ?? false);

/// Recovers the token from whatever the student actually pasted.
///
/// People paste the whole link, and people paste the bare token out of the
/// middle of a message. Both are accepted rather than making someone work
/// out which half of a link they were supposed to copy. Returns null when
/// the input carries no plausible token.
String? classJoinTokenFrom(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    final fromQuery = uri.queryParameters[classJoinTokenParameter];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  }

  // A bare token: base64url, the shape the server mints.
  if (RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(trimmed)) return trimmed;
  return null;
}

/// JOIN-053: the alphabet a class code is drawn from. No 0 or O, no 1 or I,
/// so a child reading it off a board cannot pick the wrong one. Must match
/// the server's, which is the side that mints them.
const classCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const classCodeLength = 8;

/// What the student has actually handed over: a link or its token, or a
/// short class code. Both redeem the same link; they differ only in how they
/// reach the server.
sealed class ClassJoinCredential {
  const ClassJoinCredential();
}

final class ClassJoinToken extends ClassJoinCredential {
  const ClassJoinToken(this.token);
  final String token;
}

final class ClassJoinCode extends ClassJoinCredential {
  const ClassJoinCode(this.code);

  /// Canonical: eight upper-case characters, no dash.
  final String code;
}

/// Recognises a link, a bare token or a class code in whatever was typed or
/// pasted, or returns null when it is none of them.
///
/// A token is at least 32 characters and a code at most nine with its dash,
/// so the two can never be mistaken for each other. For a code, case, spaces
/// and the dash are forgiven - that is how people copy one off a board - and
/// anything outside the alphabet is refused here rather than sent to be
/// refused by the server.
ClassJoinCredential? classJoinCredentialFrom(String input) {
  final token = classJoinTokenFrom(input);
  if (token != null) return ClassJoinToken(token);

  final compact = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (compact.length != classCodeLength) return null;
  for (final char in compact.split('')) {
    if (!classCodeAlphabet.contains(char)) return null;
  }
  return ClassJoinCode(compact);
}

/// `ABCD-EFGH`: the form a teacher reads out and a student copies.
String formatClassCode(String code) => code.length == classCodeLength
    ? '${code.substring(0, 4)}-${code.substring(4)}'
    : code;
