import 'package:flutter/material.dart';

import '../../core/legal/legal_urls.dart';
import '../../core/theme/app_theme.dart';

/// Guideline 3.1.2 — satın alma ekranında süre + otomatik yenileme + yasal link.
abstract final class PaywallSubscriptionCopy {
  static const periodLabel = 'Aylık · otomatik yenilenir';

  static const termsBody =
      'Pro ve Premium aylık otomatik yenilenen aboneliklerdir. '
      'Ödeme, onaydan sonra Apple kimliğinize veya Google hesabınıza yansır. '
      'Dönem bitmeden 24 saat kala yenilenir. Otomatik yenilemeyi bitişten '
      'en az 24 saat önce kapatırsanız yenilenmez. Aboneliği mağaza hesap '
      'ayarlarından yönetebilir veya iptal edebilirsiniz.';
}

class PaywallSubscriptionTerms extends StatelessWidget {
  const PaywallSubscriptionTerms({
    super.key,
    required this.onOpenUrl,
    this.showAppleEula = false,
  });

  final Future<void> Function(String url) onOpenUrl;
  final bool showAppleEula;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          PaywallSubscriptionCopy.termsBody,
          style: const TextStyle(
            color: LotlotColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed: () => onOpenUrl(LegalUrls.terms),
              child: const Text('Kullanım koşulları'),
            ),
            TextButton(
              onPressed: () => onOpenUrl(LegalUrls.gizlilik),
              child: const Text('Gizlilik'),
            ),
            if (showAppleEula)
              TextButton(
                onPressed: () => onOpenUrl(LegalUrls.appleStdEula),
                child: const Text('Apple EULA'),
              ),
          ],
        ),
      ],
    );
  }
}
