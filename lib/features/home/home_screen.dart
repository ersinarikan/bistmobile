import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/session_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final sub = session.subscription;
    final email = user?['email']?.toString() ?? '—';
    final tier = sub?['label']?.toString() ??
        sub?['tier']?.toString() ??
        user?['subscription_tier']?.toString() ??
        '—';
    final watchlistLimit = sub?['watchlist_limit']?.toString() ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('LOTLOT.NET'),
        actions: [
          IconButton(
            tooltip: 'Çıkış',
            onPressed: () async {
              await context.read<SessionController>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LotlotColors.surface,
              borderRadius: BorderRadius.circular(LotlotColors.radiusLg),
              border: Border.all(color: LotlotColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oturum açık',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: LotlotColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                _row('E-posta', email),
                _row('Üyelik', tier),
                _row('Watchlist limiti', watchlistLimit),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Hoş geldiniz',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'BIST analiz araçlarınız burada toplanacak. '
            'Watchlist ve hisse detayları yakında.',
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: LotlotColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
