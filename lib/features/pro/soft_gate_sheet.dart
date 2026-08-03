import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

enum SoftGateKind { pro, premium }

/// Pro/Premium soft gate — IAP yok (F6); yeni satış yok, web hesap yönetimi OK.
Future<void> showSoftGateSheet(
  BuildContext context, {
  required SoftGateKind kind,
}) {
  final title =
      kind == SoftGateKind.pro ? 'Pro gerekir' : 'Premium gerekir';
  final body = kind == SoftGateKind.pro
      ? 'Bu özellik Pro abonelik ile kullanılabilir. '
          'Uygulama içi satın alma yakında mağazada. '
          'Web’den alınmış planınız varsa hesabınızı tarayıcıda yönetebilirsiniz.'
      : 'Bu özellik Premium abonelik ile kullanılabilir. '
          'Push uyarıları ve gelişmiş kanallar Premium’dadır. '
          'Uygulama içi satın alma yakında mağazada.';

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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
            TextButton(
              onPressed: () async {
                // Yönetim / mevcut web aboneliği — yeni satış checkout değil (§9.3.1).
                final uri = Uri.parse('https://lotlot.net');
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Web hesabını aç'),
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
