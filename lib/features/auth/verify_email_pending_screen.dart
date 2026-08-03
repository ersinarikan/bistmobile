import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import 'session_controller.dart';

/// Kayıt sonrası e-posta doğrulama bekleme — JWT yok (§5).
class VerifyEmailPendingScreen extends StatefulWidget {
  const VerifyEmailPendingScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailPendingScreen> createState() =>
      _VerifyEmailPendingScreenState();
}

class _VerifyEmailPendingScreenState extends State<VerifyEmailPendingScreen> {
  var _resending = false;
  String? _banner;
  var _bannerOk = false;

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _banner = null;
    });
    final session = context.read<SessionController>();
    final ok = await session.resendVerification(email: widget.email);
    if (!mounted) return;
    setState(() {
      _resending = false;
      _bannerOk = ok;
      _banner = ok
          ? 'Doğrulama e-postası gönderildi.'
          : (session.lastError ?? 'Gönderilemedi');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-posta doğrulama'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 64,
              color: LotlotColors.accent,
            ),
            const SizedBox(height: 24),
            Text(
              'Hesabınızı doğrulayın',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.email} adresine bir doğrulama bağlantısı gönderdik. '
              'Bağlantıya tıkladıktan sonra giriş yapabilirsiniz.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (_banner != null) ...[
              const SizedBox(height: 16),
              Text(
                _banner!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _bannerOk ? LotlotColors.accent : LotlotColors.danger,
                ),
              ),
            ],
            const Spacer(),
            OutlinedButton(
              onPressed: _resending ? null : _resend,
              child: _resending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('E-postayı yeniden gönder'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Giriş ekranına dön'),
            ),
          ],
        ),
      ),
    );
  }
}
