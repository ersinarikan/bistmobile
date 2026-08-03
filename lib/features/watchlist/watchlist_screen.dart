import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/session_controller.dart';
import '../pro/soft_gate_sheet.dart';
import '../stock/stock_detail_screen.dart';
import '../wizard/wizard_screen.dart';
import 'watchlist_controller.dart';

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
      if (session.status == AuthStatus.authenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) wl.refresh();
        });
      } else {
        wl.clear();
      }
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
            'Keşfet sekmesinden kayıtsız arama yapabilirsiniz.',
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
          if (wl.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Listeniz boş — Keşfet’ten hisse ekleyin.',
                style: TextStyle(color: LotlotColors.textSecondary),
              ),
            )
          else
            ...wl.items.map((item) => _WatchlistTile(item: item)),
          const SizedBox(height: 24),
          Text(
            'Tahmin özeti',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _HorizonChips(wl: wl),
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

class _HorizonChips extends StatelessWidget {
  const _HorizonChips({required this.wl});

  final WatchlistController wl;

  static const _horizons = ['1d', '3d', '7d', '14d', '30d'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _horizons.map((h) {
        final selected = wl.selectedHorizon == h;
        return ChoiceChip(
          label: Text(h),
          selected: selected,
          onSelected: (_) => wl.setHorizon(h),
          selectedColor: LotlotColors.accent.withValues(alpha: 0.25),
          labelStyle: TextStyle(
            color: selected ? LotlotColors.accent : LotlotColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected ? LotlotColors.accent : LotlotColors.border,
          ),
          backgroundColor: LotlotColors.surface,
        );
      }).toList(),
    );
  }
}

class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final symbol = item['symbol']?.toString() ?? '';
    final name = item['name']?.toString();
    final active = item['active'] != false;
    final reason = item['disabled_reason']?.toString();
    final alertOn = item['alert_enabled'] == true;
    final session = context.watch<SessionController>();
    final wl = context.watch<WatchlistController>();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        symbol,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: active ? LotlotColors.textPrimary : LotlotColors.textSecondary,
        ),
      ),
      subtitle: Text(
        [
          ?name,
          if (!active && reason != null) 'Pasif ($reason)',
          if (alertOn) 'Sinyal uyarısı açık',
        ].join(' · '),
        style: const TextStyle(color: LotlotColors.textSecondary),
      ),
      onTap: symbol.isEmpty
          ? null
          : () => openStockDetail(context, symbol: symbol, name: name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: alertOn ? 'Sinyal uyarısını kapat' : 'Sinyal uyarısını aç',
            icon: Icon(
              alertOn ? Icons.notifications_active : Icons.notifications_none,
              color: alertOn ? LotlotColors.accent : LotlotColors.textSecondary,
            ),
            onPressed: symbol.isEmpty || wl.mutating
                ? null
                : () async {
                    if (!session.isPremium) {
                      await showSoftGateSheet(
                        context,
                        kind: SoftGateKind.premium,
                      );
                      return;
                    }
                    final turningOn = !alertOn;
                    final ok = await wl.setAlertEnabled(symbol, !alertOn);
                    if (!context.mounted) return;
                    if (!ok) {
                      final apiErr = wl.lastApiError;
                      if (apiErr != null &&
                          tryShowSoftGateForApiError(context, apiErr)) {
                        return;
                      }
                      if (wl.lastError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(wl.lastError!)),
                        );
                      }
                      return;
                    }
                    if (turningOn && !session.pushNotificationsOn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sinyal uyarısı açıldı; cihaz push için '
                            'Hesap → Push bildirimlerini açın.',
                          ),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  },
          ),
          IconButton(
            tooltip: 'Kaldır',
            icon: const Icon(
              Icons.remove_circle_outline,
              color: LotlotColors.danger,
            ),
            onPressed: symbol.isEmpty
                ? null
                : () async {
                    final ok = await context
                        .read<WatchlistController>()
                        .removeSymbol(symbol);
                    if (!context.mounted) return;
                    if (!ok) {
                      final err = context.read<WatchlistController>().lastError;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err)),
                        );
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.pred, required this.wl});

  final Map<String, dynamic> pred;
  final WatchlistController wl;

  Color _barColor(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'buy':
        return LotlotColors.accent;
      case 'sell':
        return LotlotColors.danger;
      case 'warning':
        return LotlotColors.warning;
      default:
        return LotlotColors.textSecondary;
    }
  }

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
                if (overall != null)
                  Text(
                    _overallLabel(overall),
                    style: const TextStyle(
                      color: LotlotColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
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
            if (genel is num) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: genel.toDouble().clamp(0, 100) / 100.0,
                        minHeight: 6,
                        color: _barColor(barType),
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
                      color: _barColor(barType),
                    ),
                  ),
                ],
              ),
            ],
            if (current is num || modelHealth != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (current is num)
                    'Fiyat: ${current.toStringAsFixed(2)}',
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
