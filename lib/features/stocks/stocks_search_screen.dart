import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/lotlot_accent_card.dart';
import '../account/account_settings_screen.dart';
import '../stock/stock_detail_screen.dart';
import 'stocks_catalog_controller.dart';

/// Web `/stocks` parity — BIST Hisse Merkezi arama.
class StocksSearchScreen extends StatefulWidget {
  const StocksSearchScreen({super.key});

  @override
  State<StocksSearchScreen> createState() => _StocksSearchScreenState();
}

class _StocksSearchScreenState extends State<StocksSearchScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StocksCatalogController>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<StocksCatalogController>();
    final rows = catalog.filtered;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const BrandLogo(width: 30, height: 28),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'LOTLOT',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: LotlotColors.textPrimary,
                        ),
                  ),
                  TextSpan(
                    text: '.NET',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: LotlotColors.accent,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bilgi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IntroCard(total: catalog.totalCount),
                  const SizedBox(height: 12),
                  _ControlsCard(search: _search, catalog: catalog),
                  const SizedBox(height: 20),
                  Text(
                    catalog.indexFilter == null
                        ? 'Tüm hisse sayfaları'
                        : catalog.indexFilter == 'bist-30'
                            ? 'BIST 30 hisseleri'
                            : 'BIST 100 hisseleri',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    catalog.loading
                        ? 'Yükleniyor…'
                        : '${rows.length} hisse listeleniyor.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: LotlotColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (catalog.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: LotlotAccentCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              catalog.error!,
                              style: const TextStyle(color: LotlotColors.danger),
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: catalog.reload,
                              child: const Text('Yeniden dene'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (catalog.loading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: LotlotColors.accent,
                        ),
                      ),
                    )
                  else if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LotlotAccentCard(
                        child: Text(
                          'Sonuç bulunamadı. Sembol, şirket adı veya sektör deneyin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LotlotColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!catalog.loading && catalog.error == null && rows.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  return _StockTile(
                    symbol: row['symbol']?.toString() ?? '',
                    name: row['name']?.toString(),
                    sector: row['sector']?.toString(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final count = total > 0 ? total : 635;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusLg),
        border: Border.all(color: LotlotColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: LotlotColors.backgroundMid,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: LotlotColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: LotlotColors.accent),
                  SizedBox(width: 8),
                  Text(
                    'BIST Hisse Merkezi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'BIST Hisseleri',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Borsa İstanbul\'daki $count aktif hisseyi sembol, şirket adı '
              'veya kısaltmayla arayın. Analiz özet sayfasına doğrudan ulaşın.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: LotlotColors.textSecondary,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({
    required this.search,
    required this.catalog,
  });

  final TextEditingController search;
  final StocksCatalogController catalog;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusLg),
        border: Border.all(color: LotlotColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hisse ara',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: LotlotColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: search,
              onChanged: catalog.setQuery,
              decoration: InputDecoration(
                hintText: 'Sembol, şirket adı veya kısaltma',
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
            const SizedBox(height: 14),
            Text(
              'Sektör',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: LotlotColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey(catalog.sector ?? ''),
              initialValue: catalog.sector ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Tüm sektörler'),
                ),
                ...catalog.sectors.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => catalog.setSector(v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _IndexChip(
                  label: 'BIST 30',
                  selected: catalog.indexFilter == 'bist-30',
                  onTap: () => catalog.toggleIndex('bist-30'),
                ),
                const SizedBox(width: 8),
                _IndexChip(
                  label: 'BIST 100',
                  selected: catalog.indexFilter == 'bist-100',
                  onTap: () => catalog.toggleIndex('bist-100'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${catalog.totalCount > 0 ? catalog.totalCount : 635} aktif '
              'hisse · BIST 30: ${catalog.bist30Count > 0 ? catalog.bist30Count : 30} · '
              'BIST 100: ${catalog.bist100Count > 0 ? catalog.bist100Count : 100} · '
              'Kısa parçalar da çalışır (ör. garan, tha)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LotlotColors.textSecondary,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
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
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor:
            selected ? LotlotColors.accent : LotlotColors.textPrimary,
        side: BorderSide(
          color: selected ? LotlotColors.accent : LotlotColors.border,
          width: selected ? 1.4 : 1,
        ),
        backgroundColor: selected
            ? LotlotColors.accent.withValues(alpha: 0.18)
            : Colors.transparent,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.symbol,
    required this.name,
    required this.sector,
  });

  final String symbol;
  final String? name;
  final String? sector;

  @override
  Widget build(BuildContext context) {
    if (symbol.isEmpty) return const SizedBox.shrink();
    return LotlotAccentCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      onTap: () => openStockDetail(
        context,
        symbol: symbol,
        name: name,
      ),
      child: Row(
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
                if (sector != null &&
                    sector!.isNotEmpty &&
                    sector != 'N/A') ...[
                  const SizedBox(height: 4),
                  Text(
                    sector!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: LotlotColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
