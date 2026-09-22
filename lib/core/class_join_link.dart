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
