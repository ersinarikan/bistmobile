import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/session_controller.dart';
import '../pro/soft_gate_sheet.dart';
import 'chart_alerts_controller.dart';

const sourceLabels = <String, String>{
  'price': 'Fiyat',
  'rsi14': 'RSI (14)',
  'ema20': 'EMA 20',
  'ema50': 'EMA 50',
  'bb_upper': 'Bollinger üst',
  'bb_lower': 'Bollinger alt',
};

const opLabels = <String, String>{
  'lt': 'Küçüktür (<)',
  'gt': 'Büyüktür (>)',
  'lte': 'Küçük eşit (≤)',
  'gte': 'Büyük eşit (≥)',
};

const freqLabels = <String, String>{
  'once': 'Bir kez',
  'every_time': 'Her tetiklenmede',
};

/// Web `#chartModal` alarm — Pro gate + opsiyonel sembol/fiyat ön doldurma.
Future<bool> showCreateChartAlertSheet(
  BuildContext context, {
  String? initialSymbol,
  String initialSource = 'price',
  num? initialValue,
}) async {
  final session = context.read<SessionController>();
  if (session.status != AuthStatus.authenticated) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(popOnSuccess: true),
      ),
    );
    if (!context.mounted) return false;
    if (context.read<SessionController>().status != AuthStatus.authenticated) {
      return false;
    }
  }
  if (!context.read<SessionController>().isPro) {
    await showSoftGateSheet(context, kind: SoftGateKind.pro);
    return false;
  }

  final api = context.read<ApiClient>();
  final alertsCtrl = ChartAlertsController(apiClient: api);
  await alertsCtrl.refresh();
  if (!context.mounted) {
    alertsCtrl.dispose();
    return false;
  }
  if (alertsCtrl.lastApiError != null &&
      alertsCtrl.lastApiError!.statusCode == 403) {
    tryShowSoftGateForApiError(context, alertsCtrl.lastApiError!);
    alertsCtrl.dispose();
    return false;
  }

  final sessionNow = context.read<SessionController>();
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LotlotColors.surface,
    builder: (ctx) => CreateChartAlertSheet(
      allowPush: sessionNow.isPremium && alertsCtrl.channelsPushAllowed,
      initialSymbol: initialSymbol,
      initialSource: initialSource,
      initialValue: initialValue,
      onSubmit: (symbol, source, op, value, email, push, frequency) async {
        final ok = await alertsCtrl.create(
          symbol: symbol,
          source: source,
          operator_: op,
          value: value,
          notifyEmail: email,
          notifyPush: push && sessionNow.isPremium,
          frequency: frequency,
        );
        if (!ctx.mounted) return;
        if (!ok) {
          final apiErr = alertsCtrl.lastApiError;
          if (apiErr != null && tryShowSoftGateForApiError(ctx, apiErr)) {
            return;
          }
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(alertsCtrl.lastError ?? 'Eklenemedi')),
          );
          return;
        }
        Navigator.pop(ctx, true);
      },
    ),
  );
  alertsCtrl.dispose();
  return created == true;
}

class CreateChartAlertSheet extends StatefulWidget {
  const CreateChartAlertSheet({
    super.key,
    required this.allowPush,
    required this.onSubmit,
    this.initialSymbol,
    this.initialSource = 'rsi14',
    this.initialValue,
  });

  final bool allowPush;
  final String? initialSymbol;
  final String initialSource;
  final num? initialValue;
  final Future<void> Function(
    String symbol,
    String source,
    String op,
    num value,
    bool email,
    bool push,
    String frequency,
  ) onSubmit;

  @override
  State<CreateChartAlertSheet> createState() => _CreateChartAlertSheetState();
}

class _CreateChartAlertSheetState extends State<CreateChartAlertSheet> {
  late final TextEditingController _symbol;
  late final TextEditingController _value;
  late String _source;
  String _op = 'lt';
  String _frequency = 'once';
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
  static const _ops = ['lt', 'gt', 'lte', 'gte'];
  static const _freqs = ['once', 'every_time'];

  @override
  void initState() {
    super.initState();
    _symbol = TextEditingController(
      text: (widget.initialSymbol ?? '').toUpperCase(),
    );
    final v = widget.initialValue;
    _value = TextEditingController(
      text: v == null
          ? (widget.initialSource == 'price' ? '' : '30')
          : (v is int ? '$v' : v.toStringAsFixed(2)),
    );
    _source = _sources.contains(widget.initialSource)
        ? widget.initialSource
        : 'price';
    if (_source == 'price') {
      _op = 'lte';
    }
  }

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
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(sourceLabels[s] ?? s),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _source = v ?? _source),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _op,
              decoration: const InputDecoration(labelText: 'Operatör'),
              items: _ops
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(opLabels[s] ?? s),
                    ),
                  )
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
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Sıklık'),
              items: _freqs
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(freqLabels[s] ?? s),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _frequency = v ?? _frequency),
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
                      final val = num.tryParse(
                        _value.text.trim().replaceAll(',', '.'),
                      );
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
                        _frequency,
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
