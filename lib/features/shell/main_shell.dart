import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../account/account_settings_screen.dart';
import '../auth/auth_screen.dart';
import '../auth/session_controller.dart';
import '../browse/browse_screen.dart';
import '../stocks/stocks_search_screen.dart';
import '../watchlist/watchlist_controller.dart';
import '../watchlist/watchlist_screen.dart';

/// Ana kabuk: İzleme | Keşfet (+ AppBar katalog arama).
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = 0});

  /// 0 = İzleme, 1 = Keşfet
  final int initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AuthStatus? _lastAuth;
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1);
  }

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccountSettingsScreen(),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final status = session.status;
    if (_lastAuth != null &&
        _lastAuth == AuthStatus.authenticated &&
        status != AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<WatchlistController>().clear();
      });
    }
    _lastAuth = status;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final authenticated = session.status == AuthStatus.authenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LOTLOT.NET'),
        actions: [
          IconButton(
            tooltip: 'BIST kataloğu',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StocksSearchScreen(),
                ),
              );
            },
            icon: const Icon(Icons.search),
          ),
          if (!authenticated)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AuthScreen(
                      initialMode: AuthMode.login,
                      popOnSuccess: true,
                    ),
                  ),
                );
              },
              child: const Text('Giriş'),
            ),
          IconButton(
            tooltip: authenticated ? 'Hesap' : 'Bilgi',
            onPressed: _openAccount,
            icon: Icon(
              authenticated
                  ? Icons.account_circle_outlined
                  : Icons.info_outline,
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          WatchlistScreen(),
          BrowseScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: LotlotColors.background,
        indicatorColor: LotlotColors.accent.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark, color: LotlotColors.accent),
            label: 'İzleme',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: LotlotColors.accent),
            label: 'Keşfet',
          ),
        ],
      ),
    );
  }
}
