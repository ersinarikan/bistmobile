import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/session_controller.dart';
import '../watchlist/watchlist_controller.dart';
import 'browse_controller.dart';
import 'stock_placeholder_sheet.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BrowseController>().loadScreener();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browse = context.watch<BrowseController>();
    final session = context.watch<SessionController>();
    final watchlist = context.watch<WatchlistController>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: browse.onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Hisse ara (ör. THYAO)',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (!browse.isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _IndexChip(
                  label: 'BIST 30',
                  selected: browse.indexKey == 'bist-30',
                  onTap: () => browse.loadScreener(index: 'bist-30'),
                ),
                const SizedBox(width: 8),
                _IndexChip(
                  label: 'BIST 100',
                  selected: browse.indexKey == 'bist-100',
                  onTap: () => browse.loadScreener(index: 'bist-100'),
                ),
              ],
            ),
          ),
        if (browse.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              browse.error!,
              style: const TextStyle(color: LotlotColors.danger),
            ),
          ),
        Expanded(
          child: browse.isSearching
              ? _SearchBody(
                  browse: browse,
                  onTap: (symbol, name) => openStockSheet(
                    context,
                    symbol: symbol,
                    name: name,
                    session: session,
                    watchlist: watchlist,
                  ),
                )
              : _ScreenerBody(
                  browse: browse,
                  onTap: (symbol, name) => openStockSheet(
                    context,
                    symbol: symbol,
                    name: name,
                    session: session,
                    watchlist: watchlist,
                  ),
                ),
        ),
      ],
    );
  }
}

class _IndexChip extends StatelessWidget {
  const _IndexChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
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
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({required this.browse, required this.onTap});

  final BrowseController browse;
  final void Function(String symbol, String? name) onTap;

  @override
  Widget build(BuildContext context) {
    if (browse.loadingSearch) {
      return const Center(
        child: CircularProgressIndicator(color: LotlotColors.accent),
      );
    }
    if (browse.searchResults.isEmpty) {
      return const Center(
        child: Text(
          'Sonuç bulunamadı',
          style: TextStyle(color: LotlotColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: browse.searchResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: LotlotColors.border),
      itemBuilder: (context, i) {
        final row = browse.searchResults[i];
        final symbol = row['symbol']?.toString() ?? '';
        final name = row['name']?.toString();
        final price = row['price'];
        final sector = row['sector']?.toString();
        return ListTile(
          title: Text(
            symbol,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [?name, ?sector].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: LotlotColors.textSecondary),
          ),
          trailing: price != null
              ? Text(
                  price.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
              : null,
          onTap: symbol.isEmpty ? null : () => onTap(symbol, name),
        );
      },
    );
  }
}

class _ScreenerBody extends StatelessWidget {
  const _ScreenerBody({required this.browse, required this.onTap});

  final BrowseController browse;
  final void Function(String symbol, String? name) onTap;

  @override
  Widget build(BuildContext context) {
    if (browse.loadingScreener) {
      return const Center(
        child: CircularProgressIndicator(color: LotlotColors.accent),
      );
    }
    if (browse.screenerRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Özet henüz hazır değil. Biraz sonra tekrar deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LotlotColors.textSecondary),
          ),
        ),
      );
    }
    final horizon = browse.defaultHorizon ?? '30d';
    return ListView.separated(
      itemCount: browse.screenerRows.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: LotlotColors.border),
      itemBuilder: (context, i) {
        final row = browse.screenerRows[i];
        final symbol = row['symbol']?.toString() ?? '';
        final name = row['name']?.toString();
        final close = row['last_close'];
        final fv = row['fair_value'];
        final label = fv is Map ? fv['valuation_label_tr']?.toString() : null;
        final scores = row['lotlot_scores'];
        final score = scores is Map ? scores[horizon] : null;
        return ListTile(
          title: Text(
            symbol,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              ?name,
              ?label,
              if (score != null) 'Skor $score',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: LotlotColors.textSecondary),
          ),
          trailing: close != null
              ? Text(
                  close.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
              : null,
          onTap: symbol.isEmpty ? null : () => onTap(symbol, name),
        );
      },
    );
  }
}
