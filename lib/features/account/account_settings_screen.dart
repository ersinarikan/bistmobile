import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/legal_urls.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/session_controller.dart';
import '../watchlist/watchlist_controller.dart';

/// F4 Hesap / yasal — auth: profil+tercihler; guest: yasal + giriş.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _patchingPush = false;
  bool _patchingEmail = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIfAuth());
  }

  Future<void> _refreshIfAuth() async {
    final session = context.read<SessionController>();
    if (session.status != AuthStatus.authenticated) return;
    setState(() => _refreshing = true);
    await session.refreshMe();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sayfa açılamadı')),
      );
    }
  }

  Future<void> _setPush(bool value) async {
    final session = context.read<SessionController>();
    setState(() => _patchingPush = true);
    final ok = await session.updateNotificationPrefs(pushNotifications: value);
    if (!mounted) return;
    setState(() => _patchingPush = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastError ?? 'Güncellenemedi')),
      );
    }
  }

  Future<void> _setEmail(bool value) async {
    final session = context.read<SessionController>();
    setState(() => _patchingEmail = true);
    final ok = await session.updateNotificationPrefs(emailNotifications: value);
    if (!mounted) return;
    setState(() => _patchingEmail = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastError ?? 'Güncellenemedi')),
      );
    }
  }

  Future<void> _logout() async {
    final session = context.read<SessionController>();
    await session.logout();
    if (!mounted) return;
    context.read<WatchlistController>().clear();
    Navigator.of(context).pop();
  }

  Future<void> _deleteAccount() async {
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
    if (ok != true || !mounted) return;

    final session = context.read<SessionController>();
    final deleted = await session.deleteAccount();
    if (!mounted) return;
    if (deleted) {
      context.read<WatchlistController>().clear();
      Navigator.of(context).pop();
    } else if (session.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final auth = session.status == AuthStatus.authenticated;
    final user = session.user;
    final sub = session.subscription;
    final email = user?['email']?.toString();
    final label = sub?['label']?.toString();
    final limit = sub?['watchlist_limit'];
    final mutRemaining = sub?['monthly_watchlist_mutations_remaining'];
    final pushOn = user?['push_notifications'] == true;
    final emailOn = user?['email_notifications'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(auth ? 'Hesap' : 'Bilgi'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                color: LotlotColors.accent,
                minHeight: 2,
              ),
            ),
          if (auth) ...[
            Text(
              email ?? 'Hesap',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (label != null)
              Text(
                label,
                style: const TextStyle(
                  color: LotlotColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            if (limit != null) ...[
              const SizedBox(height: 6),
              Text(
                'İzleme limiti: $limit'
                '${mutRemaining != null ? ' · Bu ay kalan değişiklik: $mutRemaining' : ''}',
                style: const TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Bildirim tercihleri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cihaz bildirimi sonraki sürümde. Bu ayarlar hesap tercihini kaydeder.',
              style: TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Push bildirimleri'),
              value: pushOn,
              onChanged: _patchingPush ? null : _setPush,
              activeThumbColor: LotlotColors.onAccent,
              activeTrackColor: LotlotColors.accent,
            ),
            if (_patchingPush)
              const LinearProgressIndicator(
                color: LotlotColors.accent,
                minHeight: 2,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('E-posta bildirimleri'),
              value: emailOn,
              onChanged: _patchingEmail ? null : _setEmail,
              activeThumbColor: LotlotColors.onAccent,
              activeTrackColor: LotlotColors.accent,
            ),
            if (_patchingEmail)
              const LinearProgressIndicator(
                color: LotlotColors.accent,
                minHeight: 2,
              ),
            const SizedBox(height: 16),
          ] else ...[
            const Text(
              'Yasal belgeler ve hesap işlemleri için giriş yapabilirsiniz.',
              style: TextStyle(
                color: LotlotColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
          ],
          Text(
            'Yasal',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gizlilik / KVKK'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openLegal(LegalUrls.gizlilik),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openLegal(LegalUrls.privacy),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kullanım koşulları'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openLegal(LegalUrls.terms),
          ),
          if (auth) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _logout,
              child: const Text('Çıkış yap'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _deleteAccount,
              style: TextButton.styleFrom(foregroundColor: LotlotColors.danger),
              child: const Text('Hesabı sil'),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Yatırım tavsiyesi değildir. Veri analizidir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LotlotColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
