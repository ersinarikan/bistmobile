import 'package:flutter/material.dart';

import '../../features/auth/auth_helpers.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/stock/stock_detail_screen.dart';
import '../push/app_badge.dart';
import '../theme/app_theme.dart';

/// Global navigator — deep_link / socket banner / custom scheme handoff.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

String? _pendingDeepLink;

/// Pure deep-link hedefi (Navigator / Firebase yok — birim test).
sealed class DeepLinkTarget {
  const DeepLinkTarget();
}

/// `lotlot://auth/login?email=&password_reset=`
final class DeepLinkAuthLogin extends DeepLinkTarget {
  const DeepLinkAuthLogin({
    this.email = '',
    this.passwordReset = false,
  });

  final String email;
  final bool passwordReset;
}

/// Hisse detay — FCM `/dashboard?symbol=` veya `lotlot://symbol/THYAO`.
final class DeepLinkStock extends DeepLinkTarget {
  const DeepLinkStock(this.symbol);

  final String symbol;
}

/// Deep link string → hedef. Boş / anlaşılamayan → `null` (no-op).
///
/// Öncelik: auth login → `lotlot://symbol/…` → query `symbol`/`sembol`.
/// `lotlot://` asla `https://lotlot.net/lotlot://…` olarak yeniden yazılmaz.
DeepLinkTarget? resolveDeepLink(String? deepLink) {
  if (deepLink == null) return null;
  final raw = deepLink.trim();
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.scheme.toLowerCase() == 'lotlot') {
    final host = uri.host.toLowerCase();
    final path = uri.path;
    final pathLower = path.toLowerCase();

    final isAuthLogin = host == 'auth' &&
        (pathLower == '/login' ||
            pathLower.endsWith('/login') ||
            pathLower.isEmpty);
    if (isAuthLogin || (host.isEmpty && pathLower.contains('login'))) {
      final email = uri.queryParameters['email']?.trim() ?? '';
      return DeepLinkAuthLogin(
        email: email,
        passwordReset: isPasswordResetQuery(uri.queryParameters),
      );
    }

    // lotlot://symbol/THYAO → host=symbol, path=/THYAO
    if (host == 'symbol') {
      final sym = _symbolFromPathSegments(uri.pathSegments);
      if (sym != null) return DeepLinkStock(sym);
      return null;
    }

    // lotlot:///symbol/THYAO veya lotlot:/symbol/THYAO
    if (pathLower.startsWith('/symbol/') || pathLower == '/symbol') {
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs.first.toLowerCase() == 'symbol') {
        final sym = _normalizeSymbol(segs[1]);
        if (sym != null) return DeepLinkStock(sym);
      }
      return null;
    }

    // Bilinmeyen lotlot host — query fallback (nadir)
    final q = uri.queryParameters['symbol'] ?? uri.queryParameters['sembol'];
    final fromQuery = _normalizeSymbol(q);
    if (fromQuery != null) return DeepLinkStock(fromQuery);
    return null;
  }

  // http(s) veya relative path (`/dashboard?symbol=…`)
  final httpUri = Uri.tryParse(
    raw.startsWith('http')
        ? raw
        : 'https://lotlot.net${raw.startsWith('/') ? raw : '/$raw'}',
  );
  if (httpUri == null) return null;
  final symbol = httpUri.queryParameters['symbol'] ??
      httpUri.queryParameters['sembol'];
  final normalized = _normalizeSymbol(symbol);
  if (normalized == null) return null;
  return DeepLinkStock(normalized);
}

String? _symbolFromPathSegments(List<String> segments) {
  if (segments.isEmpty) return null;
  return _normalizeSymbol(segments.first);
}

String? _normalizeSymbol(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toUpperCase();
  if (s.isEmpty) return null;
  return s;
}

/// Splash / ilk frame öncesi deep_link sakla; hazır olunca aç.
void openDeepLink(String? deepLink) {
  if (deepLink == null || deepLink.isEmpty) return;
  // P0: notification / deep link open clears sticky OS badge.
  // ignore: discarded_futures
  AppBadge.clear();
  final nav = appNavigatorKey.currentState;
  if (nav == null) {
    _pendingDeepLink = deepLink;
    return;
  }
  _pendingDeepLink = null;
  _routeDeepLink(nav, deepLink);
}

/// MaterialApp ayağa kalktıktan / splash sonrası çağır.
void flushPendingDeepLink() {
  final pending = _pendingDeepLink;
  if (pending == null) return;
  openDeepLink(pending);
}

void _routeDeepLink(NavigatorState nav, String deepLink) {
  final target = resolveDeepLink(deepLink);
  switch (target) {
    case DeepLinkAuthLogin(:final email, :final passwordReset):
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => AuthScreen(
            initialMode: AuthMode.login,
            initialEmail: email.isEmpty ? null : email,
            passwordResetHandoff: passwordReset,
          ),
        ),
      );
    case DeepLinkStock(:final symbol):
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => StockDetailScreen(symbol: symbol),
        ),
      );
    case null:
      break;
  }
}

void showActionableAlertSnack(Map<String, dynamic> payload) {
  final ctx = appNavigatorKey.currentContext;
  if (ctx == null) return;
  final title = payload['title_tr']?.toString() ??
      payload['symbol']?.toString() ??
      'Uyarı';
  String? body =
      payload['body_tr']?.toString() ?? payload['body']?.toString();
  if (body == null) {
    final n = payload['notification'];
    if (n is Map) body = n['body']?.toString();
  }
  final deep = payload['deep_link']?.toString();
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      backgroundColor: LotlotColors.surfaceElevated,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (body != null && body.isNotEmpty)
            Text(body, style: const TextStyle(fontSize: 13)),
        ],
      ),
      action: deep != null
          ? SnackBarAction(
              label: 'Aç',
              textColor: LotlotColors.accent,
              onPressed: () => openDeepLink(deep),
            )
          : null,
      duration: const Duration(seconds: 6),
    ),
  );
}

/// FCM RemoteMessage.data (+ isteğe bağlı notification).
void showFcmForegroundSnack(Map<String, dynamic> data, {String? title, String? body}) {
  showActionableAlertSnack({
    ...data,
    'title_tr': ?title,
    'body_tr': ?body,
  });
}
