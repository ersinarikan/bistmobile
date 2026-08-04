import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/session_controller.dart';
import '../stock/widgets/horizon_chips.dart';
import '../stocks/stocks_search_screen.dart';
import '../wizard/wizard_screen.dart';
import 'watchlist_controller.dart';
import 'widgets/add_watchlist_sheet.dart';
import 'widgets/watchlist_signal_tile.dart';

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

class _GuestWatchlistCta extends StatelessWidget {
  const _GuestWatchlistCta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.bookmark_border, size: 48, color: LotlotColors.accent),
          const SizedBox(height: 16),
          Text(
            'İzleme listeniz burada',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Giriş yaparak hisseleri takip edin ve tahmin özetlerini görün. '
            'Keşfet sekmesinde BIST 30/100 taraması; üstteki arama ile tam katalog.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 28),
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
                MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: wl.mutating
                  ? null
                  : () => showAddWatchlistSheet(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Hisse Ekle'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WizardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Hisse Sihirbazı'),
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
          const SizedBox(height: 4),
          const Text(
            'Ufuk: karttaki AL/SAT, Δ% ve sinyal gücünü günceller. '
            'Detay → özet panel; küçük grafik → büyük mum + Öngörü / AI.',
            style: TextStyle(
              color: LotlotColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (wl.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Listeniz boş. Yukarıdan Hisse Ekle ile sembol arayın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LotlotColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => showAddWatchlistSheet(context),
                    child: const Text('Sembol ara'),
                  ),
                ],
              ),
            )
          else
            ...wl.items.map((item) => WatchlistSignalTile(item: item)),
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
    final remaining = wl.mutationsRemaining;
    final quotaText = (active != null && limit != null)
        ? '$active / $limit hisse'
        : 'Kota bilgisi yükleniyor';
    final mutText = remaining == null
        ? null
        : 'Bu ay kalan değişiklik: $remaining';

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
