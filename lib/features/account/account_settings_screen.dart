import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/legal_urls.dart';
import '../../core/push/push_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/unread_count_badge.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/session_controller.dart';
import '../billing/billing_controller.dart';
import '../billing/paywall_screen.dart';
import '../chart_alerts/chart_alerts_screen.dart';
import '../landing/landing_screen.dart';
import '../notifications/inbox_controller.dart';
import '../notifications/inbox_screen.dart';
import '../pro/soft_gate_sheet.dart';
import '../watchlist/watchlist_controller.dart';
import '../wizard/wizard_screen.dart';

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
  AuthStatus? _lastAuth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionController>();
    final status = session.status;
    if (_lastAuth == null) {
      _lastAuth = status;
      if (status == AuthStatus.authenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMe());
      }
      return;
    }
    if (status != _lastAuth) {
      final wasAuth = _lastAuth == AuthStatus.authenticated;
      _lastAuth = status;
      if (status == AuthStatus.authenticated && !wasAuth) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMe());
      }
    }
  }

  Future<void> _refreshMe() async {
    final session = context.read<SessionController>();
    if (session.status != AuthStatus.authenticated) return;
    setState(() => _refreshing = true);
    await session.refreshMe();
    if (!mounted) return;
    await context.read<InboxController>().refreshSummary(force: true);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sayfa açılamadı')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sayfa açılamadı')),
      );
    }
  }

  Future<void> _setPush(bool value) async {
    final session = context.read<SessionController>();
    if (value && !session.isPremium) {
      await showSoftGateSheet(context, kind: SoftGateKind.premium);
      return;
    }
    setState(() => _patchingPush = true);
    final ok = await session.updateNotificationPrefs(pushNotifications: value);
    if (!mounted) return;
    setState(() => _patchingPush = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastError ?? 'Güncellenemedi')),
      );
      return;
    }
    // Prefs PATCH sonrası FCM kaydını zorla (APNs gecikmesi / ilk izin).
    final push = context.read<PushService>();
    await push.syncRegistration(
      isPremium: session.isPremium,
      pushOn: value,
    );
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
      (_) => false,
    );
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
        (_) => false,
      );
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
    final prefsReady = !_refreshing || user != null;
    final pushOn = user?['push_notifications'] == true;
    final emailOn = user?['email_notifications'] == true;
    final unread =
        auth ? context.watch<InboxController>().unreadCount : 0;

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
            _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    )
                  else if (_refreshing)
                    const Text(
                      'Plan yükleniyor…',
                      style: TextStyle(
                        color: LotlotColors.textSecondary,
                        fontSize: 14,
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Abonelik',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Planları yönet'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PaywallScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restore),
                    title: const Text('Aboneliği geri yükle'),
                    onTap: () async {
                      final billing = context.read<BillingController>();
                      await billing.load();
                      if (!context.mounted) return;
                      final ok = await billing.restorePurchases();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Abonelik geri yüklendi'
                                : (billing.error ?? 'Geri yükleme başarısız'),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bildirim tercihleri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Premium’da cihaz bildirimleri açılabilir. Sistem izni gerekir.',
                    style: TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (context.watch<PushService>().statusMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.watch<PushService>().statusMessage!,
                      style: const TextStyle(
                        color: LotlotColors.warning,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Push bildirimleri'),
                    subtitle: session.isPremium
                        ? null
                        : const Text(
                            'Premium gerekir',
                            style: TextStyle(
                              color: LotlotColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                    value: pushOn,
                    onChanged: (!prefsReady || _patchingPush) ? null : _setPush,
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
                    onChanged:
                        (!prefsReady || _patchingEmail) ? null : _setEmail,
                    activeThumbColor: LotlotColors.onAccent,
                    activeTrackColor: LotlotColors.accent,
                  ),
                  if (_patchingEmail)
                    const LinearProgressIndicator(
                      color: LotlotColors.accent,
                      minHeight: 2,
                    ),
                  const Divider(height: 16, color: LotlotColors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UnreadCountBadge(
                      count: unread,
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    title: const Text('Gelen bildirimler'),
                    subtitle: Text(
                      unread > 0
                          ? '$unread okunmamış · Push geçmişi'
                          : 'Push geçmişi — okundu / sil',
                      style: const TextStyle(
                        color: LotlotColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const InboxScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Yasal belgeler ve hesap işlemleri için giriş yapın '
                    'veya ücretsiz hesap oluşturun.',
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
                          builder: (_) =>
                              const LoginScreen(popOnSuccess: true),
                        ),
                      );
                    },
                    child: const Text('Giriş yap'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('Ücretsiz başla'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Yasal',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _SurfaceCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gizlilik / KVKK'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openLegal(LegalUrls.gizlilik),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gizlilik (EN)'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openLegal(LegalUrls.privacy),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kullanım koşulları'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openLegal(LegalUrls.terms),
                ),
              ],
            ),
          ),
          if (auth) ...[
            const SizedBox(height: 16),
            Text(
              'Pro özellikler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            _SurfaceCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_alert_outlined),
                    title: const Text('Grafik uyarıları'),
                    subtitle: const Text(
                      'Pro+ teknik koşul uyarıları',
                      style: TextStyle(
                        color: LotlotColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChartAlertsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: LotlotColors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hisse Sihirbazı'),
                    subtitle: const Text(
                      'Premium öneri taraması',
                      style: TextStyle(
                        color: LotlotColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WizardScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LotlotColors.surface,
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
        border: Border.all(color: LotlotColors.border),
      ),
      child: child,
    );
  }
}
