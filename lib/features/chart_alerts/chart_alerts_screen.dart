import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_controller.dart';
import '../pro/soft_gate_sheet.dart';
import 'chart_alerts_controller.dart';

class ChartAlertsScreen extends StatefulWidget {
  const ChartAlertsScreen({super.key});

  @override
  State<ChartAlertsScreen> createState() => _ChartAlertsScreenState();
}

class _ChartAlertsScreenState extends State<ChartAlertsScreen> {
  ChartAlertsController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl != null) return;
    _ctrl = ChartAlertsController(apiClient: context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    final session = context.read<SessionController>();
    if (!session.isPro) {
      await showSoftGateSheet(context, kind: SoftGateKind.pro);
      return;
    }
    await ctrl.refresh();
    if (!mounted) return;
    final err = ctrl.lastApiError;
    if (err != null && err.statusCode == 403) {
      tryShowSoftGateForApiError(context, err);
    }
  }

  Future<void> _onAdd(SessionController session) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (!session.isPro) {
      await showSoftGateSheet(context, kind: SoftGateKind.pro);
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LotlotColors.surface,
      builder: (ctx) => _CreateAlertSheet(
        allowPush: session.isPremium && ctrl.channelsPushAllowed,
        onSubmit: (symbol, source, op, value, email, push) async {
          final ok = await ctrl.create(
            symbol: symbol,
            source: source,
            operator_: op,
            value: value,
            notifyEmail: email,
            notifyPush: push && session.isPremium,
          );
          if (!ctx.mounted) return;
          if (!ok) {
            final apiErr = ctrl.lastApiError;
            if (apiErr != null && tryShowSoftGateForApiError(ctx, apiErr)) {
              return;
            }
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(ctrl.lastError ?? 'Eklenemedi')),
            );
            return;
          }
          Navigator.pop(ctx, true);
        },
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uyarı eklendi')),
      );
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
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Grafik uyarıları'),
            actions: [
              IconButton(
                tooltip: 'Yenile',
                onPressed: ctrl.loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _onAdd(session),
            backgroundColor: LotlotColors.accent,
            foregroundColor: LotlotColors.onAccent,
            child: const Icon(Icons.add),
          ),
          body: _body(session, ctrl),
        );
      },
    );
  }

  Widget _body(SessionController session, ChartAlertsController ctrl) {
    if (!session.isPro) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Grafik uyarıları Pro planda açılır.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LotlotColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    showSoftGateSheet(context, kind: SoftGateKind.pro),
                child: const Text('Detay'),
              ),
            ],
          ),
        ),
      );
    }

    if (ctrl.loading && ctrl.alerts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: LotlotColors.accent),
      );
    }

    final used = ctrl.used;
    final limit = ctrl.limit;

    return RefreshIndicator(
      color: LotlotColors.accent,
      onRefresh: ctrl.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          if (used != null || limit != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: LotlotColors.surface,
                borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
                border: Border.all(color: LotlotColors.border),
              ),
              child: Text(
                'Kota: ${used ?? '—'} / ${limit ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          if (ctrl.lastError != null && ctrl.alerts.isEmpty)
            Text(
              ctrl.lastError!,
              style: const TextStyle(color: LotlotColors.danger),
            ),
          if (ctrl.alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Henüz grafik uyarısı yok. + ile ekleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LotlotColors.textSecondary),
              ),
            )
          else
            ...ctrl.alerts.map((a) {
              final id = a['id']?.toString() ?? '';
              final symbol = a['symbol']?.toString() ?? '—';
              final summary = a['summary_tr']?.toString() ??
                  a['conditions_summary_tr']?.toString() ??
                  a['description']?.toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LotlotColors.surface,
                  borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
                  border: Border.all(color: LotlotColors.border),
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
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: id.isEmpty || ctrl.mutating
                          ? null
                          : () async {
                              final ok = await ctrl.remove(id);
                              if (!mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ctrl.lastError ?? 'Silinemedi',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: LotlotColors.danger,
                      ),
                    ),
                  ],
                ),
              );
            }),
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
  }
}

class _CreateAlertSheet extends StatefulWidget {
  const _CreateAlertSheet({
    required this.allowPush,
    required this.onSubmit,
  });

  final bool allowPush;
  final Future<void> Function(
    String symbol,
    String source,
    String op,
    num value,
    bool email,
    bool push,
  ) onSubmit;

  @override
  State<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends State<_CreateAlertSheet> {
  final _symbol = TextEditingController();
  final _value = TextEditingController(text: '30');
  String _source = 'rsi14';
  String _op = 'lt';
  bool _email = true;
  bool _push = false;
  bool _busy = false;

  static const _sources = [
    'price',
    'rsi14',
    'ema20',
    'ema50',
    'bb_upper',
    'bb_lower',
  ];
  static const _ops = ['lt', 'gt', 'lte'];

  @override
  void dispose() {
    _symbol.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Yeni uyarı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _symbol,
              decoration: const InputDecoration(labelText: 'Sembol'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _source,
              decoration: const InputDecoration(labelText: 'Kaynak'),
              items: _sources
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _source = v ?? _source),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _op,
              decoration: const InputDecoration(labelText: 'Operatör'),
              items: _ops
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _op = v ?? _op),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Değer'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('E-posta bildir'),
              value: _email,
              onChanged: (v) => setState(() => _email = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                widget.allowPush ? 'Push bildir' : 'Push (yalnız Premium)',
              ),
              value: widget.allowPush && _push,
              onChanged:
                  widget.allowPush ? (v) => setState(() => _push = v) : null,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final sym = _symbol.text.trim();
                      final val = num.tryParse(_value.text.trim());
                      if (sym.isEmpty || val == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sembol ve değer gerekli'),
                          ),
                        );
                        return;
                      }
                      setState(() => _busy = true);
                      await widget.onSubmit(
                        sym,
                        _source,
                        _op,
                        val,
                        _email,
                        _push,
                      );
                      if (mounted) setState(() => _busy = false);
                    },
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
