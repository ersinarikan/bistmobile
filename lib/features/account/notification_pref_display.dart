/// Effective notification preference display (plan matrix).
/// Backend normalizes sticky flags; client still clamps for defense-in-depth.
bool effectiveEmailNotificationsOn({
  required bool isPro,
  required bool rawEmailOn,
}) =>
    isPro && rawEmailOn;

bool effectivePushNotificationsOn({
  required bool isPremium,
  required bool rawPushOn,
}) =>
    isPremium && rawPushOn;
