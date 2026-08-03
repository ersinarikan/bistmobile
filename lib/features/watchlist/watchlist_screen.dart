import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/session_controller.dart';
import '../stock/stock_detail_screen.dart';
import '../stock/widgets/horizon_chips.dart';
import '../stocks/stocks_search_screen.dart';
import '../wizard/wizard_screen.dart';
import 'watchlist_controller.dart';
import 'widgets/watchlist_signal_tile.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  AuthStatus? _lastStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final wl = context.read<WatchlistController>();
    if (session.status != _lastStatus) {
      _lastStatus = session.status;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (session.status == AuthStatus.authenticated) {
          wl.refresh();
        } else {
          wl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status != AuthStatus.authenticated) {
      return const _GuestWatchlistCta();
    }
    return const _AuthWatchlistBody();
  }
}

class _GuestWatchlistCta extends StatelessWidget {
  const _GuestWatchlistCta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.bookmark_border, size: 48, color: LotlotColors.accent),
          const SizedBox(height: 16),
          Text(
            'İzleme listeniz burada',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Giriş yaparak hisseleri takip edin ve tahmin özetlerini görün. '
            'Keşfet sekmesinde BIST 30/100 taraması; üstteki arama ile tam katalog.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 28),
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
              );
            },
            child: const Text('Hesap oluştur'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StocksSearchScreen(),
                ),
              );
            },
            child: const Text('BIST Hisseleri'),
          ),
        ],
      ),
    );
  }
}

class _AuthWatchlistBody extends StatelessWidget {
  const _AuthWatchlistBody();

  @override
  Widget build(BuildContext context) {
    final wl = context.watch<WatchlistController>();

    if (wl.loading && wl.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: LotlotColors.accent),
      );
    }

    return RefreshIndicator(
      color: LotlotColors.accent,
      onRefresh: () => context.read<WatchlistController>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _QuotaBar(wl: wl),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WizardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Hisse Sihirbazı'),
          ),
          if (wl.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              wl.lastError!,
              style: const TextStyle(color: LotlotColors.danger),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Listem',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          HorizonChips(
            selected: wl.selectedHorizon,
            onSelected: wl.setHorizon,
          ),
          const SizedBox(height: 4),
          const Text(
            'Ufuk: kartlardaki AL/SAT, Δ% ve sinyal gücünü günceller.',
            style: TextStyle(
              color: LotlotColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (wl.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Listeniz boş — arama ile hisse ekleyin.',
                style: TextStyle(color: LotlotColors.textSecondary),
              ),
            )
          else
            ...wl.items.map((item) => WatchlistSignalTile(item: item)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tahmin özeti',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (wl.predictions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aktif listedeki hisseler için tahmin henüz yok.',
                style: TextStyle(color: LotlotColors.textSecondary),
              ),
            )
          else
            ...wl.predictions.map((p) => _PredictionCard(pred: p, wl: wl)),
          const SizedBox(height: 16),
          Text(
            'Yatırım tavsiyesi değildir. Veri analizidir.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LotlotColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({required this.wl});

  final WatchlistController wl;

  @override
  Widget build(BuildContext context) {
    final active = wl.activeCount;
    final limit = wl.watchlistLimit;
    final remaining = wl.mutationsRemaining;
    final quotaText = (active != null && limit != null)
        ? '$active / $limit hisse'
        : 'Kota bilgisi yükleniyor';
    final mutText = remaining == null
        ? null
        : 'Bu ay kalan değişiklik: $remaining';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        border: Border.all(color: LotlotColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quotaText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (mutText != null) ...[
            const SizedBox(height: 4),
            Text(
              mutText,
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.pred, required this.wl});

  final Map<String, dynamic> pred;
  final WatchlistController wl;

  Color _barColor(String? type) => confidenceBarColor(type);

  String _overallLabel(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'bullish':
        return 'Yükseliş';
      case 'bearish':
        return 'Düşüş';
      case 'neutral':
        return 'Nötr';
      default:
        return (raw ?? '').replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = pred['symbol']?.toString() ?? '';
    final overall = pred['overall_signal']?.toString();
    final signal = wl.signalFor(pred);
    final label = signal?['label']?.toString();
    final summary = signal?['summary_tr']?.toString();
    final genel = signal?['genel_confidence_pct'];
    final barType = signal?['confidence_bar_type']?.toString();
    final modelHealth = signal?['model_health']?.toString() ??
        pred['model_health']?.toString();
    final stale = pred['stale'] == true;
    final current = pred['current_price'];
    final delta = formatDeltaPct(signal?['delta_pct']);
    final session = context.watch<SessionController>();
    final muted = isMutedActionable(
      signal,
      isPaid: session.isPro || session.isPremium,
    );
    final degraded = isModelDegraded(signal);
    final pill = actionPill(signal);
    final pillColor = pillColorFor(pill, muted: muted, degraded: degraded);

    return InkWell(
      onTap: symbol.isEmpty
          ? null
          : () => openStockDetail(
                context,
                symbol: symbol,
                name: pred['name']?.toString(),
              ),
      borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LotlotColors.surface,
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          border: Border.all(color: LotlotColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (pill != null)
                  Opacity(
                    opacity: muted ? 0.58 : 1,
                    child: Text(
                      pill,
                      style: TextStyle(
                        color: pillColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else if (overall != null)
                  Text(
                    _overallLabel(overall),
                    style: const TextStyle(
                      color: LotlotColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (label != null || delta != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  ?label,
                  if (delta != null) 'Δ $delta',
                ].join(' · '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
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
            if (genel is num) ...[
              const SizedBox(height: 8),
              const Text(
                'Genel Sinyal Gücü',
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: genel.toDouble().clamp(0, 100) / 100.0,
                        minHeight: 6,
                        color: muted
                            ? LotlotColors.textSecondary
                            : _barColor(barType),
                        backgroundColor: LotlotColors.border,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '%${genel.round()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: muted
                          ? LotlotColors.textSecondary
                          : _barColor(barType),
                    ),
                  ),
                ],
              ),
            ],
            if (current is num || modelHealth != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (current is num) 'Fiyat: ${current.toStringAsFixed(2)}',
                  ?modelHealth,
                ].join(' · '),
                style: const TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            if (stale)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Veri güncel olmayabilir',
                  style: TextStyle(color: LotlotColors.warning, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
