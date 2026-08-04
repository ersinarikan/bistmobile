import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_screen.dart';
import '../auth/session_controller.dart';
import '../pro/soft_gate_sheet.dart';
import 'billing_controller.dart';
import 'iap_service.dart';

/// F6 paywall — StoreKit / Play; Garanti/WebView yok.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    this.highlight = SoftGateKind.pro,
  });

  final SoftGateKind highlight;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillingController>().load();
    });
  }

  Future<void> _ensureAuth() async {
    final session = context.read<SessionController>();
    if (session.status == AuthStatus.authenticated) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AuthScreen(
          initialMode: AuthMode.login,
          popOnSuccess: true,
        ),
      ),
    );
  }

  Future<void> _buy(String productId) async {
    await _ensureAuth();
    if (!mounted) return;
    final session = context.read<SessionController>();
    if (session.status != AuthStatus.authenticated) return;

    final billing = context.read<BillingController>();
    final ok = await billing.purchase(productId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abonelik etkinleştirildi')),
      );
      Navigator.of(context).pop(true);
    } else if (billing.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(billing.error!)),
      );
    }
  }

  Future<void> _restore() async {
    await _ensureAuth();
    if (!mounted) return;
    final session = context.read<SessionController>();
    if (session.status != AuthStatus.authenticated) return;

    final billing = context.read<BillingController>();
    final ok = await billing.restorePurchases();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Abonelik geri yüklendi'
              : (billing.error ?? 'Geri yükleme başarısız'),
        ),
      ),
    );
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _openManage() async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sayfa açılamadı')),
      );
    }
  }

  Future<void> _openWebAccount() async {
    try {
      await launchUrl(
        Uri.parse('https://lotlot.net'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingController>();
    final session = context.watch<SessionController>();
    final highlightPremium = widget.highlight == SoftGateKind.premium;

    return Scaffold(
      appBar: AppBar(title: const Text('Planlar')),
      body: billing.loadingConfig
          ? const Center(
              child: CircularProgressIndicator(color: LotlotColors.accent),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'LOTLOT.NET abonelikleri',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Satın alma yalnızca App Store / Google Play üzerinden yapılır. '
                  'Yatırım tavsiyesi değildir.',
                  style: TextStyle(
                    color: LotlotColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (!billing.canPurchase) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: LotlotColors.surface,
                      borderRadius:
                          BorderRadius.circular(LotlotColors.radiusMd),
                      border: Border.all(color: LotlotColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        billing.purchaseBlockedReason,
                        style: const TextStyle(
                          color: LotlotColors.warning,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
                if (session.isPro || session.isPremium) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.isPremium
                        ? 'Aktif planınız: Premium'
                        : 'Aktif planınız: Pro',
                    style: const TextStyle(
                      color: LotlotColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _PlanCard(
                  title: 'Pro',
                  subtitle: 'Geniş analiz, AI yorum, grafik alarmları',
                  price: billing.priceLabel(kIapProductPro),
                  highlighted: !highlightPremium,
                  enabled: billing.canPurchase && !billing.busy,
                  onBuy: () => _buy(kIapProductPro),
                ),
                const SizedBox(height: 12),
                _PlanCard(
                  title: 'Premium',
                  subtitle: 'Push, Hisse Sihirbazı, geniş kota',
                  price: billing.priceLabel(kIapProductPremium),
                  highlighted: highlightPremium,
                  enabled: billing.canPurchase && !billing.busy,
                  onBuy: () => _buy(kIapProductPremium),
                ),
                const SizedBox(height: 20),
                if (billing.busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: LotlotColors.accent,
                      ),
                    ),
                  ),
                OutlinedButton(
                  onPressed: billing.busy ? null : _restore,
                  child: const Text('Aboneliği geri yükle'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openManage,
                  child: const Text('Mağazada aboneliği yönet'),
                ),
                TextButton(
                  onPressed: _openWebAccount,
                  child: const Text('Web hesabını aç'),
                ),
              ],
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.highlighted,
    required this.enabled,
    required this.onBuy,
  });

  final String title;
  final String subtitle;
  final String? price;
  final bool highlighted;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusLg),
        border: Border.all(
          color: highlighted ? LotlotColors.accent : LotlotColors.border,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  price ?? '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: highlighted
                        ? LotlotColors.accent
                        : LotlotColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: enabled ? onBuy : null,
              child: Text('$title’a geç'),
            ),
          ],
        ),
      ),
    );
  }
}
