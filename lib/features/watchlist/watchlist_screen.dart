import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/lotlot_accent_card.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/session_controller.dart';
import '../stock/widgets/horizon_chips.dart';
import '../stocks/stocks_search_screen.dart';
import '../wizard/wizard_screen.dart';
import 'watchlist_controller.dart';
import 'widgets/add_watchlist_sheet.dart';
import 'widgets/first_stock_guide_dialog.dart';
import 'widgets/watchlist_empty_onboarding.dart';
import 'widgets/watchlist_signal_tile.dart';
import 'widgets/watchlist_tier_hold_banner.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  AuthStatus? _lastStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final wl = context.read<WatchlistController>();
    if (session.status != _lastStatus) {
      _lastStatus = session.status;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (session.status == AuthStatus.authenticated) {
          wl.refresh();
        } else {
          wl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status != AuthStatus.authenticated) {
      return const _GuestWatchlistCta();
    }
    return const _AuthWatchlistBody();
  }
}

Future<void> _openAddAndMaybeGuide(BuildContext context) async {
  final wl = context.read<WatchlistController>();
  final first = await showAddWatchlistSheet(context);
  if (!context.mounted || !first) return;
  await showFirstStockGuideDialog(
    context,
    horizonLabel: horizonShortLabel(wl.selectedHorizon),
  );
}

class _GuestWatchlistCta extends StatelessWidget {
  const _GuestWatchlistCta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SingleChildScrollView(
          child: LotlotAccentCard(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandLogo(width: 72, height: 72)),
                const SizedBox(height: 16),
                Text(
                  'İzleme listeniz burada',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Giriş yaparak hisseleri takip edin ve tahmin özetlerini görün. '
                  'Keşfet sekmesinde BIST 30/100 taraması; üstteki arama ile tam katalog.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LotlotColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(popOnSuccess: true),
                      ),
                    );
                  },
                  child: const Text('Giriş yap'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('Hesap oluştur'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StocksSearchScreen(),
                      ),
                    );
                  },
                  child: const Text('BIST Hisseleri'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthWatchlistBody extends StatelessWidget {
  const _AuthWatchlistBody();

  @override
  Widget build(BuildContext context) {
    final wl = context.watch<WatchlistController>();

    if (wl.loading && wl.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: LotlotColors.accent),
      );
    }

    return RefreshIndicator(
      color: LotlotColors.accent,
      onRefresh: () => context.read<WatchlistController>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _QuotaBar(wl: wl),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: wl.mutating
                  ? null
                  : () => _openAddAndMaybeGuide(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Hisse Ekle'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WizardScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Hisse Sihirbazı'),
            ),
          ),
          if (wl.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              wl.lastError!,
              style: const TextStyle(color: LotlotColors.danger),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    context.read<WatchlistController>().refresh(),
                child: const Text('Yeniden dene'),
              ),
            ),
          ],
          if (wl.enriching && wl.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              minHeight: 2,
              color: LotlotColors.accent,
              backgroundColor: LotlotColors.border,
            ),
            const SizedBox(height: 6),
            Text(
              wl.enrichingPredictions
                  ? 'Sinyaller yükleniyor…'
                  : 'Kartlar güncelleniyor…',
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Takip Edilen Hisseler',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          HorizonChips(
            selected: wl.selectedHorizon,
            onSelected: wl.setHorizon,
          ),
          const SizedBox(height: 12),
          if (wl.items.isEmpty)
            WatchlistEmptyOnboarding(
              onAddStock: () => _openAddAndMaybeGuide(context),
            )
          else ...[
            ...wl.items
                .where(WatchlistController.isItemActive)
                .map((item) => WatchlistSignalTile(item: item)),
            if (wl.items.any((e) => !WatchlistController.isItemActive(e))) ...[
              const WatchlistTierHoldBanner(),
              ...wl.items
                  .where((e) => !WatchlistController.isItemActive(e))
                  .map((item) => WatchlistSignalTile(item: item)),
            ],
          ],
          const SizedBox(height: 16),
          Text(
            'Yatırım tavsiyesi değildir. Veri analizidir.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LotlotColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({required this.wl});

  final WatchlistController wl;

  @override
  Widget build(BuildContext context) {
    final active = wl.activeCount;
    final limit = wl.watchlistLimit;
    final inactive = wl.inactiveCount;
    final remaining = wl.mutationsRemaining;
    final quotaText = (active != null && limit != null)
        ? '$active / $limit hisse'
        : 'Kota bilgisi yükleniyor';

    String? mutText;
    if (wl.mutationsCarryoverExhausted) {
      // Web account-modal.js _quotaBar over note
      mutText =
          'Üst sınır aşıldı; yeni hak yok. Fazla kullanım önceki plandan kalma.';
    } else if (remaining != null) {
      mutText = 'Bu ay kalan değişiklik: $remaining';
    }

    final inactiveNote = (inactive != null && inactive > 0)
        ? '$inactive hisse plan limitinde bekliyor'
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        border: Border.all(color: LotlotColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quotaText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (inactiveNote != null) ...[
            const SizedBox(height: 4),
            Text(
              inactiveNote,
              style: const TextStyle(
                color: LotlotColors.warning,
                fontSize: 13,
              ),
            ),
          ],
          if (mutText != null) ...[
            const SizedBox(height: 4),
            Text(
              mutText,
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
