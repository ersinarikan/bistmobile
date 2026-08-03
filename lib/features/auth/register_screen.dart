import 'package:flutter/material.dart';

import 'auth_screen.dart';

/// Geriye uyum — web parity için [AuthScreen] kullanır.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(initialMode: AuthMode.register);
  }
}
