import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/navigation/deep_link_router.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_controller.dart';
import '../shell/main_shell.dart';

/// Splash: token → `/me` → MainShell. Ağ/5xx: Yeniden dene (P3).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  var _booting = true;
  String? _retryError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    setState(() {
      _booting = true;
      _retryError = null;
    });
    final session = context.read<SessionController>();
    await session.bootstrap();
    if (!mounted) return;

    // Token var ama /me geçici hata → shell’e guest düşme; retry (P3).
    if (session.status == AuthStatus.unknown && session.lastError != null) {
      setState(() {
        _booting = false;
        _retryError = session.lastError;
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      flushPendingDeepLink();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(width: 96, height: 88),
                const SizedBox(height: 20),
                Text(
                  'LOTLOT.NET',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: LotlotColors.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Yatırım tavsiyesi değildir. Veri analizidir.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LotlotColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_booting)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: LotlotColors.accent,
                    ),
                  )
                else if (_retryError != null) ...[
                  Text(
                    _retryError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: LotlotColors.danger),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _boot,
                    child: const Text('Yeniden dene'),
                  ),
                  TextButton(
                    onPressed: () {
                      context
                          .read<SessionController>()
                          .continueAsGuestKeepingTokens();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const MainShell(),
                        ),
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        flushPendingDeepLink();
                      });
                    },
                    child: const Text('Misafir devam et'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
