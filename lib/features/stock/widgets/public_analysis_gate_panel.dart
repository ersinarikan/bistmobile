import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lotlot_accent_card.dart';
import '../../auth/login_screen.dart';

/// Web `/hisse` soft-gate panel — guest tek CTA (çift “Giriş yap” yok).
class PublicAnalysisGatePanel extends StatelessWidget {
  const PublicAnalysisGatePanel({super.key, required this.symbol});

  final String symbol;

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(popOnSuccess: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sym = symbol.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LotlotAccentCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'LOTLOT.NET',
              style: TextStyle(
                color: LotlotColors.accent.withValues(alpha: 0.95),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Daha Detaylı Analiz',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bu sayfada $sym için temel bilgiler ve geçmiş fiyat '
              'metrikleri görünmektedir. Otomatik kalıp (Formasyon) tespiti, '
              'sinyal güçleri, ufuklara göre analiz öngörüleri takip listesi '
              'üye girişiyle açılmaktadır.',
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Şimdi ücretsiz bir hesap aç, $sym\'i takip listesine ekle, '
              'Hisse Sihirbazı ve tecrübeli yatırımcı yorumlarını görebileceğin '
              'ayrıcalıkları kullan ve fiyat hareketlerinde anlık bildirimler al.',
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _openLogin(context),
              child: const Text('Analiz İçin Tıklayın'),
            ),
          ],
        ),
      ),
    );
  }
}
