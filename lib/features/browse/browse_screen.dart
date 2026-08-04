import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/lotlot_accent_card.dart';
import '../stock/stock_detail_screen.dart';
import 'browse_controller.dart';

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: browse.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Hisse ara (ör. THYAO)',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: LotlotColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
                borderSide: const BorderSide(color: LotlotColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
                borderSide: const BorderSide(color: LotlotColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
                borderSide: const BorderSide(color: LotlotColors.accent),
              ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LotlotAccentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    browse.error!,
                    style: const TextStyle(color: LotlotColors.danger),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          context.read<BrowseController>().retry(),
                      child: const Text('Yeniden dene'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: browse.isSearching
              ? _SearchBody(
                  browse: browse,
                  onTap: (symbol, name) => openStockDetail(
                    context,
                    symbol: symbol,
                    name: name,
                  ),
                )
              : _ScreenerBody(
                  browse: browse,
                  onTap: (symbol, name) => openStockDetail(
                    context,
                    symbol: symbol,
                    name: name,
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
      selectedColor: LotlotColors.accent.withValues(alpha: 0.28),
      labelStyle: TextStyle(
        color: selected ? LotlotColors.accent : LotlotColors.textSecondary,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? LotlotColors.accent : LotlotColors.border,
        width: selected ? 1.4 : 1,
      ),
      backgroundColor: LotlotColors.surface,
    );
  }
}

class _BrowseStockRow extends StatelessWidget {
  const _BrowseStockRow({
    required this.symbol,
    this.name,
    this.meta,
    this.price,
    required this.onTap,
  });

  final String symbol;
  final String? name;
  final String? meta;
  final num? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LotlotAccentCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                if (name != null && name!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (meta != null && meta!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (price != null)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 2),
              child: Text(
                '₺${price!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _emptyCard({
  required String message,
  VoidCallback? onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: LotlotAccentCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text('Yeniden dene'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
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
      return _emptyCard(
        message: 'Sonuç bulunamadı. Sembol veya şirket adı deneyin.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: browse.searchResults.length,
      itemBuilder: (context, i) {
        final row = browse.searchResults[i];
        final symbol = row['symbol']?.toString() ?? '';
        final name = row['name']?.toString();
        final sector = row['sector']?.toString();
        final priceRaw = row['price'];
        final price = priceRaw is num
            ? priceRaw
            : num.tryParse(priceRaw?.toString() ?? '');
        return _BrowseStockRow(
          symbol: symbol,
          name: name,
          meta: sector,
          price: price,
          onTap: () => onTap(symbol, name),
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
      return _emptyCard(
        message: 'Özet henüz hazır değil. Biraz sonra tekrar deneyin.',
        onRetry: browse.error == null
            ? () => context.read<BrowseController>().retry()
            : null,
      );
    }
    final horizon = browse.defaultHorizon ?? '30d';
    final hzLabel = horizon.toUpperCase().replaceAll('D', 'G');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: browse.screenerRows.length,
      itemBuilder: (context, i) {
        final row = browse.screenerRows[i];
        final symbol = row['symbol']?.toString() ?? '';
        final name = row['name']?.toString();
        final closeRaw = row['last_close'];
        final close = closeRaw is num
            ? closeRaw
            : num.tryParse(closeRaw?.toString() ?? '');
        final fv = row['fair_value'];
        final label = fv is Map ? fv['valuation_label_tr']?.toString() : null;
        final scores = row['lotlot_scores'];
        final score = scores is Map ? scores[horizon] : null;
        final metaParts = <String>[
          if (label != null && label.isNotEmpty) label,
          if (score != null) 'Skor $score · $hzLabel',
        ];
        return _BrowseStockRow(
          symbol: symbol,
          name: name,
          meta: metaParts.isEmpty ? null : metaParts.join(' · '),
          price: close,
          onTap: () => onTap(symbol, name),
        );
      },
    );
  }
}
