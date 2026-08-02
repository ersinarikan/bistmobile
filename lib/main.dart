import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session_controller.dart';
import 'features/splash/splash_screen.dart';

/// F0 shell: web teması + session bootstrap (splash → home|login).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LotlotApp());
}

class LotlotApp extends StatelessWidget {
  const LotlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = TokenStorage();
    final api = ApiClient(tokenStorage: tokens);

    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: tokens),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider(
          create: (_) => SessionController(
            tokenStorage: tokens,
            apiClient: api,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'LOTLOT.NET',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const SplashScreen(),
      ),
    );
  }
}
