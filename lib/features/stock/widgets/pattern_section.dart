import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';

/// Pattern özeti — guest CTA; auth render-only; pending loading.
class PatternSection extends StatelessWidget {
  const PatternSection({
    super.key,
    required this.isAuthenticated,
    required this.loading,
    required this.pending,
    this.pattern,
  });

  final bool isAuthenticated;
  final bool loading;
  final bool pending;
  final Map<String, dynamic>? pattern;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analiz özeti',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LotlotColors.surface,
              borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
              border: Border.all(color: LotlotColors.border),
            ),
            child: _body(context),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!isAuthenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Formasyon ve sinyal özeti için giriş yapın.',
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Giriş yap'),
          ),
        ],
      );
    }

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: LotlotColors.accent,
            ),
          ),
        ),
      );
    }

    if (pending) {
      return const Text(
        'Analiz hazırlanıyor…',
        style: TextStyle(color: LotlotColors.textSecondary),
      );
    }

    if (pattern == null) {
      return const Text(
        'Analiz özeti şu an kullanılamıyor.',
        style: TextStyle(color: LotlotColors.textSecondary),
      );
    }

    final overall = pattern!['overall_signal']?.toString();
    final patterns = pattern!['patterns'];
    final list = patterns is List ? patterns : const [];
    final signals = pattern!['signals_by_horizon'];
    Map<String, dynamic>? signal7d;
    if (signals is Map) {
      final raw = signals['7d'] ?? signals['30d'] ?? signals['1d'];
      if (raw is Map) signal7d = Map<String, dynamic>.from(raw);
    }

    final label = signal7d?['label']?.toString();
    final summary = signal7d?['summary_tr']?.toString();
    final displayState = signal7d?['display_state']?.toString();

    final hasContent = overall != null ||
        label != null ||
        summary != null ||
        list.isNotEmpty;

    if (!hasContent) {
      return const Text(
        'Sınırlı özet — bu hesap için ayrıntılı formasyon listesi '
        'sunulmuyor olabilir.',
        style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overall != null)
          Text(
            overall.replaceAll('_', ' '),
            style: const TextStyle(
              color: LotlotColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
        if (summary != null) ...[
          const SizedBox(height: 4),
          Text(
            summary,
            style: const TextStyle(
              color: LotlotColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        if (displayState != null) ...[
          const SizedBox(height: 6),
          Text(
            displayState.replaceAll('_', ' '),
            style: const TextStyle(
              fontSize: 12,
              color: LotlotColors.textSecondary,
            ),
          ),
        ],
        if (list.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Formasyon: ${list.length}',
            style: const TextStyle(
              color: LotlotColors.textSecondary,
              fontSize: 13,
            ),
          ),
          for (final item in list.take(5))
            if (item is Map)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    item['pattern']?.toString(),
                    item['signal']?.toString(),
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
        ],
      ],
    );
  }
}
