import 'package:flutter/material.dart';

import '../../features/stock/stock_detail_screen.dart';
import '../theme/app_theme.dart';

/// Global navigator — deep_link / socket banner.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// `deep_link` örn. `/dashboard?symbol=THYAO&horizon=7d` → StockDetail.
void openDeepLink(String? deepLink) {
  if (deepLink == null || deepLink.isEmpty) return;
  final uri = Uri.tryParse(
    deepLink.startsWith('http')
        ? deepLink
        : 'https://lotlot.net${deepLink.startsWith('/') ? deepLink : '/$deepLink'}',
  );
  if (uri == null) return;
  final symbol = uri.queryParameters['symbol'] ??
      uri.queryParameters['sembol'];
  if (symbol == null || symbol.isEmpty) return;
  final nav = appNavigatorKey.currentState;
  if (nav == null) return;
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
  final body = payload['body_tr']?.toString();
  final deep = payload['deep_link']?.toString();
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      backgroundColor: LotlotColors.surfaceElevated,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (body != null)
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
