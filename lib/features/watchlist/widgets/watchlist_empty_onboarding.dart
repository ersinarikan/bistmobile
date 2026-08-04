import 'package:flutter/material.dart';

import '../../../core/brand/brand_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lotlot_accent_card.dart';

/// Web `brand-empty-onboarding` — auth boş izleme (dismiss yok).
class WatchlistEmptyOnboarding extends StatelessWidget {
  const WatchlistEmptyOnboarding({super.key, required this.onAddStock});

  final VoidCallback onAddStock;

  static const _steps = <({String title, String body})>[
    (
      title: 'Hisse ekle',
      body: 'İlgilendiğiniz sembolü veya şirket adını seçin.',
    ),
    (
      title: 'Ufku oku',
      body: '1G, 3G, 7G, 14G ve 30G beklentilerini karşılaştırın.',
    ),
    (
      title: "Detay'a gir",
      body: 'Sinyalin nedeni, grafik ve formasyon bağlamını inceleyin.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LotlotAccentCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  BrandAssets.heroTransparentWebp,
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Image.network(
                    BrandAssets.heroTransparentPng,
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const BrandLogo(
                      width: 72,
                      height: 72,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İlk 3 dakika',
                      style: TextStyle(
                        color: LotlotColors.accent.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Henüz takip edilen hisse bulunmuyor.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'İlk hissenizi ekleyin. Sistem seçili ufuk için fiyat '
                      'beklentisini, sinyal gücünü ve detay bağlamını gösterecek.',
                      style: TextStyle(
                        color: LotlotColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onAddStock,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('İlk hissenizi ekleyin'),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _StepRow(index: i + 1, title: _steps[i].title, body: _steps[i].body),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.title,
    required this.body,
  });

  final int index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LotlotColors.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: LotlotColors.accent.withValues(alpha: 0.5)),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: LotlotColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
