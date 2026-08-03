import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_controller.dart';
import '../watchlist/watchlist_controller.dart';
import 'stock_detail_controller.dart';
import 'widgets/corporate_card.dart';
import 'widgets/fundamentals_card.dart';
import 'widgets/pattern_section.dart';
import 'widgets/simple_candle_chart.dart';
import 'widgets/valuation_card.dart';

class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({
    super.key,
    required this.symbol,
    this.name,
  });

  final String symbol;
  final String? name;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  StockDetailController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl != null) return;
    _ctrl = StockDetailController(
      apiClient: context.read<ApiClient>(),
      session: context.read<SessionController>(),
      symbol: widget.symbol.toUpperCase(),
      name: widget.name,
    );
    _ctrl!.load();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  bool _inWatchlist(WatchlistController wl) {
    final sym = widget.symbol.toUpperCase();
    return wl.items.any(
      (e) => (e['symbol']?.toString().toUpperCase() ?? '') == sym,
    );
  }

  Future<void> _toggleWatchlist() async {
    final wl = context.read<WatchlistController>();
    final session = context.read<SessionController>();
    if (session.status != AuthStatus.authenticated) return;

    final messenger = ScaffoldMessenger.of(context);
    final sym = widget.symbol.toUpperCase();
    final inList = _inWatchlist(wl);
    final ok = inList ? await wl.removeSymbol(sym) : await wl.addSymbol(sym);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (inList ? '$sym listeden çıkarıldı' : '$sym listeye eklendi')
              : (wl.lastError ?? 'İşlem başarısız'),
        ),
      ),
    );
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
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final session = context.watch<SessionController>();
        final wl = context.watch<WatchlistController>();
        final auth = session.status == AuthStatus.authenticated;
        final inList = auth && _inWatchlist(wl);
        final lastClose =
            ctrl.bars.isNotEmpty ? ctrl.bars.last.close : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.symbol.toUpperCase()),
            actions: [
              if (auth)
                IconButton(
                  tooltip: inList ? 'Listeden çıkar' : 'Listeye ekle',
                  onPressed: wl.mutating ? null : _toggleWatchlist,
                  icon: Icon(
                    inList ? Icons.bookmark : Icons.bookmark_border,
                    color: LotlotColors.accent,
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            color: LotlotColors.accent,
            onRefresh: ctrl.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.name != null && widget.name!.isNotEmpty)
                        Text(
                          widget.name!,
                          style: const TextStyle(
                            color: LotlotColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      if (lastClose != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          lastClose.toStringAsFixed(
                            lastClose >= 100 ? 1 : 2,
                          ),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ctrl.loadingPublic && ctrl.bars.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: LotlotColors.accent,
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: SimpleCandleChart(
                      bars: ctrl.bars,
                      levels: ctrl.levels,
                    ),
                  ),
                  if (ctrl.levels != null &&
                      (ctrl.levels!['support'] != null ||
                          ctrl.levels!['resistance'] != null))
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        'Kesik çizgi: destek / direnç (auth grafik)',
                        style: TextStyle(
                          fontSize: 11,
                          color: LotlotColors.textSecondary,
                        ),
                      ),
                    ),
                  ValuationCard(valuation: ctrl.valuation),
                  FundamentalsCard(fundamentals: ctrl.fundamentals),
                  CorporateCard(corporate: ctrl.corporate),
                  PatternSection(
                    isAuthenticated: auth,
                    loading: ctrl.loadingAuth,
                    pending: ctrl.patternPending,
                    pattern: ctrl.pattern,
                  ),
                ],
                if (ctrl.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      ctrl.error!,
                      style: const TextStyle(color: LotlotColors.danger),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Text(
                    'Yatırım tavsiyesi değildir. Veri analizidir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Browse / watchlist satırından hisse detayına gider.
void openStockDetail(
  BuildContext context, {
  required String symbol,
  String? name,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StockDetailScreen(symbol: symbol, name: name),
    ),
  );
}
