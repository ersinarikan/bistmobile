import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_screen.dart';
import '../auth/session_controller.dart';
import '../billing/paywall_screen.dart';

enum SoftGateKind { pro, premium }

/// Pro/Premium soft gate — F6: paywall’a yönlendirir (Garanti/WebView yok).
Future<void> showSoftGateSheet(
  BuildContext context, {
  required SoftGateKind kind,
}) {
  final title =
      kind == SoftGateKind.pro ? 'Pro ile açılır' : 'Premium ile açılır';
  final body = kind == SoftGateKind.pro
      ? 'AI yorum, Öngörü, formasyon vurgusu ve grafik uyarıları Pro planında.'
      : 'İzleme sinyal bildirimi, cihaz push, Hisse Sihirbazı ve daha yüksek kota Premium’da.';

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: LotlotColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(LotlotColors.radiusLg),
      ),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: LotlotColors.accent,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Satın alma App Store veya Google Play üzerinden yapılır.',
              style: TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final session = context.read<SessionController>();
                if (session.status != AuthStatus.authenticated) {
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(
                        initialMode: AuthMode.login,
                        popOnSuccess: true,
                      ),
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                }
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PaywallScreen(highlight: kind),
                  ),
                );
              },
              child: const Text('Planları gör'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Şimdilik değil'),
            ),
            TextButton(
              onPressed: () async {
                final uri = Uri.parse('https://lotlot.net');
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text(
                'Web hesabını aç',
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// API 403 / error kodundan soft gate aç. true = gate gösterildi.
bool tryShowSoftGateForApiError(BuildContext context, ApiException e) {
  final code = (e.errorCode ?? '').toLowerCase();
  final msg = '${e.message} ${e.body?['error'] ?? ''}'.toLowerCase();
  if (code == 'premium_required' ||
      msg.contains('premium access required') ||
      msg.contains('premium_required')) {
    showSoftGateSheet(context, kind: SoftGateKind.premium);
    return true;
  }
  if (code == 'pro_required' ||
      code == 'chart_alerts_not_available' ||
      msg.contains('pro access required') ||
      msg.contains('chart_alerts_not_available')) {
    showSoftGateSheet(context, kind: SoftGateKind.pro);
    return true;
  }
  return false;
}
