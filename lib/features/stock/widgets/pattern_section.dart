import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';

const _mlSources = {'ML_PREDICTOR', 'ENHANCED_ML', 'FINGPT'};

const _sourceLabels = <String, String>{
  'VISUAL_YOLO': 'Görsel',
  'ADVANCED_TA': 'Teknik Analiz',
  'BASIC': 'Teknik Analiz',
  'FINGPT': 'Sezgisel',
};

String _directionLabel(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'bullish':
    case 'al':
      return 'Yükseliş';
    case 'bearish':
    case 'sat':
      return 'Düşüş';
    case 'neutral':
    case 'tut':
    case 'hold':
      return 'Nötr';
    default:
      return raw?.isNotEmpty == true ? raw!.replaceAll('_', ' ') : 'Nötr';
  }
}

class _NewsRow {
  const _NewsRow({required this.title, this.source, this.direction});
  final String title;
  final String? source;
  final String? direction;
}

/// Pattern özeti + Sezgisel + Formasyonlar — thin client (§16.1).
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
            'Formasyon ve sezgisel özet için giriş yapın.',
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginScreen(popOnSuccess: true),
                ),
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

    final session = context.watch<SessionController>();
    final overall = pattern!['overall_signal']?.toString();
    final rawPatterns = pattern!['patterns'];
    final allPatterns = rawPatterns is List
        ? rawPatterns.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];

    final newsContext = pattern!['news_context'] is Map
        ? Map<String, dynamic>.from(pattern!['news_context'] as Map)
        : null;

    final fingpt = allPatterns.cast<Map<String, dynamic>?>().firstWhere(
          (p) => (p?['source']?.toString() ?? '') == 'FINGPT',
          orElse: () => null,
        );

    final formations = allPatterns
        .where((p) => !_mlSources.contains(p['source']?.toString() ?? ''))
        .toList();

    final signals = pattern!['signals_by_horizon'];
    Map<String, dynamic>? signalRow;
    if (signals is Map) {
      final raw = signals['7d'] ?? signals['30d'] ?? signals['1d'];
      if (raw is Map) signalRow = Map<String, dynamic>.from(raw);
    }
    final label = signalRow?['label']?.toString();
    final summary = signalRow?['summary_tr']?.toString() ??
        signalRow?['analysis_disclaimer_tr']?.toString();

    final hasSezgisel = fingpt != null ||
        (newsContext != null &&
            ((newsContext['items'] is List &&
                    (newsContext['items'] as List).isNotEmpty) ||
                (newsContext['news_count'] is num &&
                    (newsContext['news_count'] as num) > 0)));

    final hasContent = overall != null ||
        label != null ||
        summary != null ||
        formations.isNotEmpty ||
        hasSezgisel;

    if (!hasContent) {
      if (!session.isPro) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ayrıntılı formasyonlar ve Sezgisel (haber) özeti Pro planda açılır.',
              style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  showSoftGateSheet(context, kind: SoftGateKind.pro),
              child: const Text('Detay'),
            ),
          ],
        );
      }
      return const Text(
        'Bu sembol için formasyon veya sezgisel özet bulunamadı.',
        style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Text(
            label,
            style: const TextStyle(
              color: LotlotColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          )
        else if (overall != null)
          Text(
            _directionLabel(overall),
            style: const TextStyle(
              color: LotlotColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
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
        if (hasSezgisel) ...[
          const SizedBox(height: 12),
          _SezgiselChip(
            fingpt: fingpt,
            newsContext: newsContext,
          ),
        ],
        if (formations.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Formasyonlar',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          for (final item in formations.take(12))
            _FormationRow(item: item),
        ] else if (session.isPro && !hasSezgisel) ...[
          const SizedBox(height: 10),
          const Text(
            'Formasyon tespit edilemedi.',
            style: TextStyle(
              color: LotlotColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _SezgiselChip extends StatelessWidget {
  const _SezgiselChip({this.fingpt, this.newsContext});

  final Map<String, dynamic>? fingpt;
  final Map<String, dynamic>? newsContext;

  @override
  Widget build(BuildContext context) {
    final dir = fingpt?['signal']?.toString() ??
        newsContext?['display_direction']?.toString() ??
        'neutral';
    final conf = fingpt?['confidence'] ?? newsContext?['confidence'];
    final count = fingpt?['news_count'] ?? newsContext?['news_count'];
    final confPct = conf is num ? (conf <= 1 ? conf * 100 : conf).round() : null;
    final label = [
      'Sezgisel',
      _directionLabel(dir),
      if (confPct != null) '(%$confPct)',
      if (count is num && count > 0) '· $count haber',
    ].join(' ');

    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: LotlotColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: LotlotColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: LotlotColors.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: LotlotColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final rows = <_NewsRow>[];
    final items = newsContext?['items'];
    if (items is List) {
      for (final it in items.take(8)) {
        if (it is! Map) continue;
        final t = it['title']?.toString();
        if (t == null || t.isEmpty) continue;
        rows.add(
          _NewsRow(
            title: t,
            source: it['source']?.toString(),
            direction: it['direction']?.toString(),
          ),
        );
      }
    }
    if (rows.isEmpty) {
      final ni = fingpt?['news_items'];
      if (ni is List) {
        for (final t in ni.take(8)) {
          final s = t?.toString();
          if (s != null && s.isNotEmpty) {
            rows.add(_NewsRow(title: s));
          }
        }
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LotlotColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LotlotColors.radiusLg),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sezgisel Analiz',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: LotlotColors.accent,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'İlgili haberler',
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Text(
                  'Haber özeti şu an yok.',
                  style: TextStyle(color: LotlotColors.textSecondary),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (_, i) {
                      final row = rows[i];
                      final meta = [
                        if (row.source != null && row.source!.isNotEmpty)
                          row.source!,
                        if (row.direction != null && row.direction!.isNotEmpty)
                          _directionLabel(row.direction),
                      ].join(' · ');
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title,
                            style: const TextStyle(height: 1.4, fontSize: 14),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              meta,
                              style: const TextStyle(
                                color: LotlotColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Yatırım tavsiyesi değildir. Veri analizidir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FormationRow extends StatelessWidget {
  const _FormationRow({required this.item});

  final Map<String, dynamic> item;

  bool get _visualOk {
    final conf = item['confirmation_sources'];
    if (conf is List) {
      return conf.any((e) => e?.toString() == 'VISUAL_YOLO');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final name = item['pattern']?.toString() ?? 'Formasyon';
    final signal = item['signal']?.toString();
    final source = item['source']?.toString() ?? '';
    final sourceLabel = _sourceLabels[source] ?? source;
    final effect = item['effect_label']?.toString() ??
        item['effect_hint_tr']?.toString();
    final conf = item['confidence'];
    final confPct = conf is num ? (conf <= 1 ? conf * 100 : conf).round() : null;
    final isVisual = source == 'VISUAL_YOLO';
    final signalLabel =
        signal != null && signal.isNotEmpty ? _directionLabel(signal) : null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  [
                    name,
                    ?signalLabel,
                  ].join(' · '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              if (confPct != null)
                Text(
                  '%$confPct',
                  style: const TextStyle(
                    color: LotlotColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (sourceLabel.isNotEmpty && !isVisual)
                _MiniBadge(sourceLabel),
              if (isVisual) const _MiniBadge('Görsel'),
              if (_visualOk && !isVisual) const _MiniBadge('görsel onay'),
            ],
          ),
          if (effect != null && effect.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              effect,
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: LotlotColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LotlotColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
