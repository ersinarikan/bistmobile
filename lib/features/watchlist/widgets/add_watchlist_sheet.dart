import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../watchlist_controller.dart';
import 'add_watchlist_alert_dialog.dart';

/// Web `#addStockModal` — sembol ara + izlemeye ekle.
Future<void> showAddWatchlistSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LotlotColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(LotlotColors.radiusLg),
      ),
    ),
    builder: (ctx) => const _AddWatchlistSheet(),
  );
}

class _AddWatchlistSheet extends StatefulWidget {
  const _AddWatchlistSheet();

  @override
  State<_AddWatchlistSheet> createState() => _AddWatchlistSheetState();
}

class _AddWatchlistSheetState extends State<_AddWatchlistSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final data = await context.read<ApiClient>().searchStocks(q);
      if (!mounted) return;
      final rawList = data['stocks'] ?? data['results'] ?? data['data'] ?? data['items'];
      final list = rawList is List
          ? rawList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _results = list.take(20).toList();
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.message;
        _results = [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Arama başarısız';
        _results = [];
      });
    }
  }

  Future<void> _add(String symbol, {String? name}) async {
    final alertEnabled = await showAddWatchlistAlertDialog(context);
    if (!mounted || alertEnabled == null) return;
    final wl = context.read<WatchlistController>();
    final ok = await wl.addSymbol(symbol, alertEnabled: alertEnabled);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wl.lastError ?? 'Eklenemedi')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$symbol izlemeye eklendi')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final wl = context.watch<WatchlistController>();
    final active = wl.activeCount;
    final limit = wl.watchlistLimit;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LotlotColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Hisse Ekle',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (active != null && limit != null) ...[
              const SizedBox(height: 6),
              Text(
                'Kota: $active / $limit',
                style: const TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _query,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Sembol veya şirket ara',
                hintText: 'Örn. THYAO, Garanti…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: _runSearch,
            ),
            const SizedBox(height: 12),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: LotlotColors.accent),
                ),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: LotlotColors.danger))
            else if (_query.text.trim().isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Takip etmek istediğiniz sembolü yazın.',
                  style: TextStyle(color: LotlotColors.textSecondary),
                ),
              )
            else if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Sonuç yok. Sembolü kontrol edin.',
                  style: TextStyle(color: LotlotColors.textSecondary),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: LotlotColors.border),
                  itemBuilder: (context, i) {
                    final row = _results[i];
                    final sym = (row['symbol'] ?? row['code'] ?? '')
                        .toString()
                        .toUpperCase();
                    final name = row['name']?.toString() ??
                        row['company_name']?.toString();
                    final watched = wl.items.any(
                      (e) =>
                          (e['symbol']?.toString() ?? '').toUpperCase() == sym,
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        sym,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: name == null || name.isEmpty
                          ? null
                          : Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: LotlotColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                      trailing: watched
                          ? const Text(
                              'İzleniyor',
                              style: TextStyle(
                                color: LotlotColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : TextButton(
                              onPressed: wl.mutating || sym.isEmpty
                                  ? null
                                  : () => _add(sym, name: name),
                              child: const Text('Ekle'),
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
