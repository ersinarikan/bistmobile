import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/session_controller.dart';
import '../watchlist/watchlist_controller.dart';

/// F3 öncesi hisse satırı — teaser yok; CTA + isteğe bağlı listeye ekle.
Future<void> showStockPlaceholderSheet(
  BuildContext context, {
  required String symbol,
  String? name,
  required bool isAuthenticated,
  WatchlistController? watchlist,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: LotlotColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(LotlotColors.radiusLg)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              symbol,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    color: LotlotColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (name != null && name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(color: LotlotColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Hisse detayı yakında. Şimdilik izleme listesine ekleyebilir '
              'veya giriş yaparak listenizi yönetebilirsiniz.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 20),
            if (isAuthenticated && watchlist != null)
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  final ok = await watchlist.addSymbol(symbol);
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? '$symbol listeye eklendi'
                            : (watchlist.lastError ?? 'Eklenemedi'),
                      ),
                    ),
                  );
                },
                child: const Text('İzleme listesine ekle'),
              )
            else ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Giriş yap'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
            ],
            if (isAuthenticated)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
          ],
        ),
      );
    },
  );
}

/// Session durumuna göre sheet açar.
void openStockSheet(
  BuildContext context, {
  required String symbol,
  String? name,
  required SessionController session,
  WatchlistController? watchlist,
}) {
  showStockPlaceholderSheet(
    context,
    symbol: symbol,
    name: name,
    isAuthenticated: session.status == AuthStatus.authenticated,
    watchlist: watchlist,
  );
}
