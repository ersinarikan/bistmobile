/// Wait until APNs token is available (iOS FCM prerequisite).
///
/// [readToken] is injected so unit tests do not need Firebase / real APNs.
Future<String?> waitForApnsToken({
  required Future<String?> Function() readToken,
  int maxAttempts = 10,
  Duration delay = const Duration(milliseconds: 400),
}) async {
  if (maxAttempts < 1) return null;
  for (var i = 0; i < maxAttempts; i++) {
    final apns = await readToken();
    if (apns != null && apns.isNotEmpty) return apns;
    if (i < maxAttempts - 1) {
      await Future<void>.delayed(delay);
    }
  }
  return null;
}
