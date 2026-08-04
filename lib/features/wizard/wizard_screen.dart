import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/session_controller.dart';
import '../pro/soft_gate_sheet.dart';
import '../stock/stock_detail_screen.dart';
import '../watchlist/watchlist_controller.dart';
import '../watchlist/widgets/add_watchlist_alert_dialog.dart';
import '../watchlist/widgets/first_stock_guide_dialog.dart';
import 'wizard_controller.dart';

const _horizonLabels = <String, String>{
  '1d': '1 gün',
  '3d': '3 gün',
  '7d': '7 gün',
  '14d': '14 gün',
  '30d': '30 gün',
};

const _signalLabels = <String, String>{
  'AL': 'Alım',
  'SAT': 'Satış',
  'TUT': 'Bekleme',
};

const _universeLabels = <String, String>{
  'all': 'Tüm aktif evren',
  'bist30': 'BIST 30',
  'bist100': 'BIST 100',
};

String _volumeLabel(String? raw) {
  if (raw == null || raw.isEmpty || raw.toLowerCase() == 'unknown') {
    return 'Bilinmiyor';
  }
  return raw;
}

class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  WizardController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= WizardController(apiClient: context.read<ApiClient>());
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _run(SessionController session) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (session.status != AuthStatus.authenticated) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(popOnSuccess: true),
        ),
      );
      return;
    }
    if (!session.isPremium) {
      await showSoftGateSheet(context, kind: SoftGateKind.premium);
      return;
    }
    final ok = await ctrl.run();
    if (!mounted) return;
    if (!ok) {
      final apiErr = ctrl.lastApiError;
      if (apiErr != null && tryShowSoftGateForApiError(context, apiErr)) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: LotlotColors.accent),
        ),
      );
    }
    final session = context.watch<SessionController>();
    final auth = session.status == AuthStatus.authenticated;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Hisse Sihirbazı')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (!auth)
                _LockedCard(
                  message: 'Sihirbaz için giriş yapın.',
                  actionLabel: 'Giriş yap',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const LoginScreen(popOnSuccess: true),
                      ),
                    );
                  },
                )
              else if (!session.isPremium)
                _LockedCard(
                  message: 'Hisse Sihirbazı Premium planda açılır.',
                  actionLabel: 'Detay',
                  onPressed: () => showSoftGateSheet(
                    context,
                    kind: SoftGateKind.premium,
                  ),
                )
              else ...[
                Text(
                  'Ufuk',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: WizardController.horizonsAll.map((h) {
                    final selected = ctrl.selectedHorizons.contains(h);
                    return FilterChip(
                      label: Text(_horizonLabels[h] ?? h),
                      selected: selected,
                      onSelected: (_) => ctrl.toggleHorizon(h),
                      selectedColor: LotlotColors.accent.withValues(alpha: 0.25),
                      checkmarkColor: LotlotColors.accent,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sinyal',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: WizardController.signalsAll.map((s) {
                    final selected = ctrl.selectedSignals.contains(s);
                    return FilterChip(
                      label: Text(_signalLabels[s] ?? s),
                      selected: selected,
                      onSelected: (_) => ctrl.toggleSignal(s),
                      selectedColor: LotlotColors.accent.withValues(alpha: 0.25),
                      checkmarkColor: LotlotColors.accent,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Evren',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: WizardController.universes.map((u) {
                    final selected = ctrl.universe == u;
                    return FilterChip(
                      label: Text(_universeLabels[u] ?? u),
                      selected: selected,
                      onSelected: (_) => ctrl.setUniverse(u),
                      selectedColor: LotlotColors.accent.withValues(alpha: 0.25),
                      checkmarkColor: LotlotColors.accent,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text('Sonuç sayısı: ${ctrl.limit}'),
                Slider(
                  value: ctrl.limit.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${ctrl.limit}',
                  activeColor: LotlotColors.accent,
                  onChanged: (v) => ctrl.setLimit(v.round()),
                ),
                Text('Geriye bakış (gün): ${ctrl.daysBack}'),
                Slider(
                  value: ctrl.daysBack.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${ctrl.daysBack}',
                  activeColor: LotlotColors.accent,
                  onChanged: (v) => ctrl.setDaysBack(v.round()),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: ctrl.loading ? null : () => _run(session),
                  child: ctrl.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Öneri getir'),
                ),
              ],
              if (ctrl.lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  ctrl.lastError!,
                  style: const TextStyle(color: LotlotColors.danger),
                ),
              ],
              if (session.isPremium && !ctrl.loading && ctrl.count == 0 && ctrl.requested != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Bu seçimlerle sonuç yok.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LotlotColors.textSecondary),
                  ),
                ),
              if (ctrl.results.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '${ctrl.count} sonuç',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...ctrl.results.map((item) => _ResultCard(
                      item: item,
                      onWatchlistAdded: (sym) => ctrl.markWatched(sym),
                    )),
              ],
              const SizedBox(height: 16),
              const Text(
                'Yatırım tavsiyesi değildir. Veri analizidir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        border: Border.all(color: LotlotColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: LotlotColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.item,
    required this.onWatchlistAdded,
  });

  final Map<String, dynamic> item;
  final void Function(String symbol) onWatchlistAdded;

  Color _signalColor(String signal) {
    switch (signal) {
      case 'AL':
        return LotlotColors.accent;
      case 'SAT':
        return LotlotColors.danger;
      default:
        return LotlotColors.textSecondary;
    }
  }

  Future<void> _addWatchlist(BuildContext context) async {
    final symbol = item['symbol']?.toString() ?? '';
    if (symbol.isEmpty) return;
    final alertEnabled = await showAddWatchlistAlertDialog(context);
    if (!context.mounted || alertEnabled == null) return;
    final wl = context.read<WatchlistController>();
    final ok = await wl.addSymbol(symbol, alertEnabled: alertEnabled);
    if (!context.mounted) return;
    if (ok) {
      final first = wl.takePendingFirstStockGuide();
      onWatchlistAdded(symbol);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$symbol izlemeye eklendi')),
      );
      if (first) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!context.mounted) return;
        await showFirstStockGuideDialog(
          context,
          horizonLabel: horizonShortLabel(wl.selectedHorizon),
        );
      }
    } else if (wl.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wl.lastError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = item['symbol']?.toString() ?? '';
    final name = item['name']?.toString();
    final horizon = item['horizon']?.toString() ?? '';
    final signal = (item['signal']?.toString() ?? 'TUT').toUpperCase();
    final label = item['label']?.toString() ?? signal;
    final reason = item['reason']?.toString();
    final delta = item['delta_pred_pct'];
    final genel = item['genel_confidence_pct'];
    final strength = item['signal_strength_pct'];
    final volume = item['volume_tier']?.toString();
    final current = item['current_price'];
    final pred = item['pred_price'];
    final watched = item['already_watched'] == true;
    final wlBusy = context.watch<WatchlistController>().mutating;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
          onTap: symbol.isEmpty
              ? null
              : () => openStockDetail(
                    context,
                    symbol: symbol,
                    name: name,
                  ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
              border: Border.all(color: LotlotColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (name != null && name.isNotEmpty)
                            Text(
                              name,
                              style: const TextStyle(
                                color: LotlotColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          Text(
                            [
                              _horizonLabels[horizon] ?? horizon,
                              if (watched) 'İzleniyor',
                            ].join(' · '),
                            style: const TextStyle(
                              color: LotlotColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _signalColor(signal).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: _signalColor(signal),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (delta is num)
                      _Metric(
                        'Beklenen',
                        '${delta.toStringAsFixed(1)}%',
                      ),
                    if (genel is num)
                      _Metric('Genel güç', '%${genel.round()}'),
                    if (strength is num)
                      _Metric('Aksiyon', '%${strength.round()}'),
                    if (volume != null) _Metric('Likidite', _volumeLabel(volume)),
                  ],
                ),
                if (current is num || pred is num) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (current is num)
                        'Güncel: ${current.toStringAsFixed(2)}',
                      if (pred is num)
                        'Hedef: ${pred.toStringAsFixed(2)}',
                    ].join(' · '),
                    style: const TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: const TextStyle(
                      color: LotlotColors.textSecondary,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: watched || wlBusy || symbol.isEmpty
                        ? null
                        : () => _addWatchlist(context),
                    icon: Icon(
                      watched ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                    ),
                    label: Text(watched ? 'İzleniyor' : 'İzlemeye ekle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: LotlotColors.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}
