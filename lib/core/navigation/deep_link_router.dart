import 'package:flutter/material.dart';

import '../../features/stock/stock_detail_screen.dart';
import '../theme/app_theme.dart';

/// Global navigator — deep_link / socket banner.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

String? _pendingDeepLink;

/// Splash / ilk frame öncesi deep_link sakla; hazır olunca aç.
void openDeepLink(String? deepLink) {
  if (deepLink == null || deepLink.isEmpty) return;
  final nav = appNavigatorKey.currentState;
  if (nav == null) {
    _pendingDeepLink = deepLink;
    return;
  }
  _pendingDeepLink = null;
  _pushStockFromDeepLink(nav, deepLink);
}

/// MaterialApp ayağa kalktıktan / splash sonrası çağır.
void flushPendingDeepLink() {
  final pending = _pendingDeepLink;
  if (pending == null) return;
  openDeepLink(pending);
}

void _pushStockFromDeepLink(NavigatorState nav, String deepLink) {
  final uri = Uri.tryParse(
    deepLink.startsWith('http')
        ? deepLink
        : 'https://lotlot.net${deepLink.startsWith('/') ? deepLink : '/$deepLink'}',
  );
  if (uri == null) return;
  final symbol = uri.queryParameters['symbol'] ??
      uri.queryParameters['sembol'];
  if (symbol == null || symbol.isEmpty) return;
  nav.push(
    MaterialPageRoute<void>(
      builder: (_) => StockDetailScreen(symbol: symbol),
    ),
  );
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
