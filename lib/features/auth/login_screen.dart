import 'package:flutter/material.dart';

import 'auth_screen.dart';

/// Geriye uyum — web parity için [AuthScreen] kullanır.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.popOnSuccess = false,
  });

  final bool popOnSuccess;

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      initialMode: AuthMode.login,
      popOnSuccess: popOnSuccess,
    );
  }
}
