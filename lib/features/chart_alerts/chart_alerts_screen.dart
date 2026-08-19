import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_controller.dart';
import '../pro/soft_gate_sheet.dart';
import 'chart_alert_row.dart';
import 'chart_alerts_controller.dart';
import 'create_chart_alert_sheet.dart';

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
    _ctrl = ChartAlertsController(
      apiClient: context.read<ApiClient>(),
    );
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
    // Free: soft gate otomatik açılmaz — boş durum + Detay yeterli.
    if (!session.isPro) return;
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
      builder: (ctx) => CreateChartAlertSheet(
        allowPush: session.isPremium && ctrl.channelsPushAllowed,
        onSubmit: (symbol, source, op, value, email, push, frequency) async {
          final ok = await ctrl.create(
            symbol: symbol,
            source: source,
            operator_: op,
            value: value,
            notifyEmail: email,
            notifyPush: push && session.isPremium,
            frequency: frequency,
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
          floatingActionButton: session.isPro
              ? FloatingActionButton(
                  onPressed: () => _onAdd(session),
                  backgroundColor: LotlotColors.accent,
                  foregroundColor: LotlotColors.onAccent,
                  child: const Icon(Icons.add),
                )
              : null,
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
                child: const Text('Planları gör'),
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
              final id = a['id']?.toString() ??
                  a['alert_id']?.toString() ??
                  a['_id']?.toString() ??
                  '';
              return ChartAlertRow(
                alert: a,
                deleting: ctrl.mutating,
                onDelete: id.isEmpty
                    ? null
                    : () async {
                        final ok = await ctrl.remove(id);
                        if (!mounted) return;
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ctrl.lastError ?? 'Silinemedi'),
                            ),
                          );
                        }
                      },
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
