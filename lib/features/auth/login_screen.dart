import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/theme/app_theme.dart';
import '../shell/main_shell.dart';
import '../watchlist/watchlist_controller.dart';
import 'oauth_sign_in.dart';
import 'register_screen.dart';
import 'session_controller.dart';
import 'turnstile_bridge_screen.dart';
import 'verify_email_pending_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _goShellIfOk(LoginResult result) async {
    if (!mounted) return;
    if (result == LoginResult.success) {
      context.read<WatchlistController>().refresh();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainShell()),
        (_) => false,
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    var result = await session.loginWithEmail(
      email: _email.text.trim(),
      password: _password.text,
    );

    if (result == LoginResult.needsTurnstile && mounted) {
      final token = await TurnstileBridgeScreen.open(context);
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      result = await session.loginWithEmail(
        email: _email.text.trim(),
        password: _password.text,
        turnstileToken: token,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == LoginResult.success) {
      await _goShellIfOk(result);
      return;
    }

    if (result == LoginResult.emailNotVerified) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerifyEmailPendingScreen(
            email: _email.text.trim(),
          ),
        ),
      );
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    try {
      final idToken = await OauthSignIn.googleIdToken();
      final result = await session.loginWithGoogleIdToken(idToken);
      if (!mounted) return;
      setState(() => _loading = false);
      await _goShellIfOk(result);
    } on OauthSignInException catch (e) {
      session.setError(e.message);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      session.setError(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apple() async {
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    try {
      final apple = await OauthSignIn.appleIdentity();
      final result = await session.loginWithAppleIdentity(
        identityToken: apple.identityToken,
        fullName: apple.fullName,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await _goShellIfOk(result);
    } on OauthSignInException catch (e) {
      session.setError(e.message);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      session.setError(e.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final showApple = !Platform.isAndroid;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -1.0),
            radius: 1.35,
            colors: [
              LotlotColors.backgroundMid,
              LotlotColors.background,
              LotlotColors.backgroundDeep,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Center(
                    child: BrandLogo(width: 80, height: 72),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LOTLOT.NET',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: LotlotColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Giriş Yap',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'E-posta gerekli';
                      }
                      if (!v.contains('@')) return 'Geçerli bir e-posta girin';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Şifre',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Şifre gerekli';
                      return null;
                    },
                  ),
                  if (session.lastError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      session.lastError!,
                      style: const TextStyle(color: LotlotColors.danger),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: LotlotColors.onAccent,
                            ),
                          )
                        : const Text('Giriş Yap'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                    child: const Text('Hesap oluştur'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (_) => const MainShell(),
                              ),
                              (_) => false,
                            );
                          },
                    child: const Text('Keşfet’e dön'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : _google,
                    child: const Text('Google ile devam et'),
                  ),
                  if (showApple) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _loading ? null : _apple,
                      child: const Text('Apple ile devam et'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Yatırım tavsiyesi değildir. Veri analizidir.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: LotlotColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
