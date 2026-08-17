/// Turns a raw caught error into a short, human-readable message safe to show
/// directly in the UI. Every network/API call in this app was surfacing raw
/// exception text instead — things like "ClientException: Connection closed
/// while receiving data, uri=https://..." — straight into error banners and
/// snackbars. That reads as a crash/glitch to a non-technical user even when
/// the underlying cause (a dropped connection, a timeout) is completely
/// routine. Pattern-matches on the exception's own text since the callers
/// here deal with a mix of ApiException, http's ClientException/SocketException,
/// TimeoutException, and plain Exception — there's no single shared type to
/// switch on.
String friendlyError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('timeoutexception') || lower.contains('timed out')) {
    return "This is taking longer than expected. Please try again.";
  }
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('connection closed') ||
      lower.contains('connection reset') ||
      lower.contains('connection refused') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable')) {
    return "Connection lost. Please check your internet and try again.";
  }
  if (lower.contains('(401)') ||
      lower.contains('status 401') ||
      lower.contains('(403)') ||
      lower.contains('status 403')) {
    return "You don't have access to do that. Please sign in again.";
  }
  if (lower.contains('(404)') || lower.contains('status 404')) {
    return "We couldn't find that — it may have been removed.";
  }
  if (lower.contains('(500)') ||
      lower.contains('(502)') ||
      lower.contains('(503)') ||
      lower.contains('(504)') ||
      lower.contains('status 500') ||
      lower.contains('status 502') ||
      lower.contains('status 503') ||
      lower.contains('status 504')) {
    return "Something went wrong on our end. Please try again in a moment.";
  }
  return "Something went wrong. Please try again.";
}
