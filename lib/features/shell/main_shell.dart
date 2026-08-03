import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/session_controller.dart';
import '../browse/browse_screen.dart';
import '../watchlist/watchlist_controller.dart';
import '../watchlist/watchlist_screen.dart';

/// F2 ortak shell: Keşfet | İzleme (guest + auth).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı sil'),
        content: const Text(
          'Hesabınız ve ilişkili veriler kalıcı olarak silinir. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: LotlotColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final session = context.read<SessionController>();
    final deleted = await session.deleteAccount();
    if (!context.mounted) return;
    if (deleted) {
      context.read<WatchlistController>().clear();
      setState(() => _index = 0);
    } else if (session.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final authenticated = session.status == AuthStatus.authenticated;
    final email = session.user?['email']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('LOTLOT.NET'),
        actions: [
          if (!authenticated)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LoginScreen(popOnSuccess: true),
                  ),
                );
              },
              child: const Text('Giriş'),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Hesap',
              onSelected: (value) async {
                if (value == 'logout') {
                  await context.read<SessionController>().logout();
                  if (!context.mounted) return;
                  context.read<WatchlistController>().clear();
                  setState(() => _index = 0);
                } else if (value == 'delete') {
                  await _confirmDelete(context);
                }
              },
              itemBuilder: (ctx) => [
                if (email != null)
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      email,
                      style: const TextStyle(color: LotlotColors.textSecondary),
                    ),
                  ),
                const PopupMenuItem(value: 'logout', child: Text('Çıkış')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Hesabı sil',
                    style: TextStyle(color: LotlotColors.danger),
                  ),
                ),
              ],
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
