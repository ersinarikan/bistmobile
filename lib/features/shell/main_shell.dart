import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../account/account_settings_screen.dart';
import '../auth/login_screen.dart';
import '../auth/session_controller.dart';
import '../browse/browse_screen.dart';
import '../watchlist/watchlist_screen.dart';

/// F2 ortak shell: Keşfet | İzleme (guest + auth). F4: Hesap/Bilgi.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccountSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final authenticated = session.status == AuthStatus.authenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LOTLOT.NET'),
        actions: [
          if (!authenticated) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LoginScreen(popOnSuccess: true),
                  ),
                );
              },
              child: const Text('Giriş'),
            ),
            IconButton(
              tooltip: 'Bilgi',
              onPressed: _openAccount,
              icon: const Icon(Icons.info_outline),
            ),
          ] else
            IconButton(
              tooltip: 'Hesap',
              onPressed: _openAccount,
              icon: const Icon(Icons.account_circle_outlined),
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          BrowseScreen(),
          WatchlistScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'İzleme',
          ),
        ],
      ),
    );
  }
}
