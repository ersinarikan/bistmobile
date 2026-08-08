import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/oauth_brand_icons.dart';
import '../shell/main_shell.dart';
import '../watchlist/watchlist_controller.dart';
import 'auth_helpers.dart';
import 'oauth_sign_in.dart';
import 'session_controller.dart';
import 'turnstile_bridge_screen.dart';
import 'verify_email_pending_screen.dart';

enum AuthMode { login, register }

/// Web `brand-auth-panel` parity — giriş + kayıt tek ekran (sekme/mod).
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialMode = AuthMode.login,
    this.initialEmail,
    this.popOnSuccess = false,
    this.passwordResetHandoff = false,
  });

  final AuthMode initialMode;
  final String? initialEmail;
  final bool popOnSuccess;

  /// `lotlot://auth/login?…&password_reset=1` — şifre web’de güncellendi.
  final bool passwordResetHandoff;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _mode;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  var _loading = false;
  var _obscure = true;
  var _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final seed = widget.initialEmail?.trim();
    if (seed != null && seed.isNotEmpty) {
      _email.text = seed;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionController>().setError(null);
      if (widget.passwordResetHandoff && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AuthCopy.passwordResetDone)),
        );
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _setMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      context.read<SessionController>().setError(null);
    });
  }

  Future<void> _goShellIfOk(LoginResult result) async {
    if (!mounted) return;
    if (result != LoginResult.success) return;
    context.read<WatchlistController>().refresh();
    if (widget.popOnSuccess && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  Future<void> _submitLogin() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AuthCopy.turnstileRequired)),
        );
        return;
      }
      result = await session.loginWithEmail(
        email: _email.text.trim(),
        password: _password.text,
        turnstileToken: token,
      );
      if (result == LoginResult.needsTurnstile) {
        session.setError(AuthCopy.turnstileRetry);
        result = LoginResult.failed;
      }
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
          builder: (_) => VerifyEmailPendingScreen(email: _email.text.trim()),
        ),
      );
      return;
    }
    if (result == LoginResult.failed && session.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastError!)),
      );
    }
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final session = context.read<SessionController>();

    var result = await session.register(
      email: _email.text.trim(),
      password: _password.text,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
    );

    if (result == RegisterResult.needsTurnstile && mounted) {
      final token = await TurnstileBridgeScreen.open(context);
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AuthCopy.turnstileRequired)),
        );
        return;
      }
      result = await session.register(
        email: _email.text.trim(),
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        turnstileToken: token,
      );
      if (result == RegisterResult.needsTurnstile) {
        session.setError(AuthCopy.turnstileRetry);
        result = RegisterResult.failed;
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (result == RegisterResult.pendingVerification) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VerifyEmailPendingScreen(
            email: _email.text.trim(),
            verificationEmailSent: session.lastVerificationEmailSent ?? true,
          ),
        ),
      );
      return;
    }

    if (result == RegisterResult.failed && session.lastError != null) {
      final already = _isAlreadyRegistered(session.lastErrorCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.lastError!),
          action: already
              ? SnackBarAction(
                  label: 'Giriş',
                  onPressed: () => _setMode(AuthMode.login),
                )
              : null,
        ),
      );
    }
  }

  bool _isAlreadyRegistered(String? code) {
    return code == 'email_already_registered' ||
        code == 'email_exists' ||
        code == 'already_registered';
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    try {
      final idToken = await OauthSignIn.googleIdToken();
      final result = await session.loginWithGoogleIdTokenLazy(
        idToken,
        obtainTurnstile: () async {
          if (!mounted) return null;
          return TurnstileBridgeScreen.open(context);
        },
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (result == LoginResult.failed && session.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(session.lastError!)),
        );
        return;
      }
      await _goShellIfOk(result);
    } on OauthSignInException catch (e) {
      session.setError(e.message);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      session.setError(e.toString());
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
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

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();
    final go = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LotlotColors.surfaceElevated,
        title: const Text(
          'Şifre sıfırlama',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'E-posta adresinize sıfırlama bağlantısı gönderilir. '
                'Yeni şifreyi lotlot.net formunda belirlersiniz.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-posta'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty || !t.contains('@')) {
                    return 'Geçerli bir e-posta girin';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, emailCtrl.text.trim());
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
    if (go == null || go.isEmpty || !mounted) return;
    await _sendPasswordReset(go);
  }

  Future<void> _sendPasswordReset(String email) async {
    setState(() => _loading = true);
    final session = context.read<SessionController>();
    var result = await session.requestPasswordReset(email: email);

    if (result == PasswordResetResult.needsTurnstile && mounted) {
      result = await _passwordResetWithTurnstile(session, email);
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _email.text = email;

    if (result == PasswordResetResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AuthCopy.passwordResetSent),
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }
    if (session.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.lastError!)),
      );
    }
  }

  Future<PasswordResetResult> _passwordResetWithTurnstile(
    SessionController session,
    String email,
  ) async {
    final token = await TurnstileBridgeScreen.open(context);
    if (!mounted) return PasswordResetResult.failed;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AuthCopy.turnstileRequired)),
      );
      return PasswordResetResult.failed;
    }
    final result = await session.requestPasswordReset(
      email: email,
      turnstileToken: token,
    );
    if (result == PasswordResetResult.needsTurnstile) {
      session.setError(AuthCopy.turnstileRetry);
      return PasswordResetResult.failed;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isLogin = _mode == AuthMode.login;

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
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Geri',
                  onPressed: _loading
                      ? null
                      : () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: BrandLogo(width: 64, height: 58),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'lotlot.net',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: LotlotColors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isLogin
                              ? 'Hesabınıza giriş yapın.'
                              : 'Yeni hesap oluşturun.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: LotlotColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!isLogin) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstName,
                                  textCapitalization: TextCapitalization.words,
                                  autofillHints: const [
                                    AutofillHints.givenName
                                  ],
                                  decoration:
                                      const InputDecoration(labelText: 'Ad'),
                                  validator: (v) => (v == null ||
                                          v.trim().isEmpty)
                                      ? 'Ad gerekli'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastName,
                                  textCapitalization: TextCapitalization.words,
                                  autofillHints: const [
                                    AutofillHints.familyName
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Soyad',
                                  ),
                                  validator: (v) => (v == null ||
                                          v.trim().isEmpty)
                                      ? 'Soyad gerekli'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'E-posta adresi',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'E-posta gerekli';
                            }
                            if (!v.contains('@')) {
                              return 'Geçerli bir e-posta girin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: [
                            isLogin
                                ? AutofillHints.password
                                : AutofillHints.newPassword,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            helperText: isLogin ? null : 'En az 8 karakter.',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Şifre gerekli';
                            if (!isLogin && v.length < 8) {
                              return 'En az 8 karakter';
                            }
                            return null;
                          },
                        ),
                        if (!isLogin) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordConfirm,
                            obscureText: _obscureConfirm,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Şifre Tekrar',
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v != _password.text) {
                                return 'Şifreler eşleşmiyor';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (session.lastError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            session.lastError!,
                            style: const TextStyle(color: LotlotColors.danger),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loading
                              ? null
                              : (isLogin ? _submitLogin : _submitRegister),
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: LotlotColors.onAccent,
                                  ),
                                )
                              : Text(isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
                        ),
                        if (isLogin) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: const Text('Şifrenizi mi unuttunuz?'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: LotlotColors.border)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'veya',
                                style: TextStyle(
                                  color: LotlotColors.textSecondary
                                      .withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: LotlotColors.border)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _apple,
                          icon: const AppleLogoMark(size: 20),
                          label: const Text('Apple ile Devam Et'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _google,
                          icon: const GoogleLogoMark(size: 20),
                          label: const Text('Google ile Devam Et'),
                        ),
                        const SizedBox(height: 12),
                        if (isLogin)
                          OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => _setMode(AuthMode.register),
                            child: const Text('E-posta ile Kayıt Ol'),
                          )
                        else
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => _setMode(AuthMode.login),
                            child: const Text('Zaten hesabım var — Giriş Yap'),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          'Yatırım tavsiyesi değildir. Veri analizidir.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: LotlotColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
