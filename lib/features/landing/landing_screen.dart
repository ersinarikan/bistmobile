import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/theme/app_theme.dart';
import '../account/account_settings_screen.dart';
import '../auth/auth_screen.dart';
import '../auth/session_controller.dart';
import '../shell/main_shell.dart';
import '../stocks/stocks_search_screen.dart';

/// Web landing hero parity — her açılış (guest + auth).
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openMenu(BuildContext context, {required bool authenticated}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LotlotColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (authenticated)
                ListTile(
                  title: const Text('Uygulamaya Git'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const MainShell(),
                      ),
                    );
                  },
                )
              else ...[
                ListTile(
                  title: const Text('Ücretsiz Başla'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AuthScreen(
                          initialMode: AuthMode.register,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  title: const Text('Giriş Yap'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AuthScreen(
                          initialMode: AuthMode.login,
                        ),
                      ),
                    );
                  },
                ),
              ],
              ListTile(
                title: const Text('BIST Hisseleri'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StocksSearchScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('Bilgi / Yasal'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authenticated =
        context.watch<SessionController>().status == AuthStatus.authenticated;

    final outlineLogin = OutlinedButton.styleFrom(
      foregroundColor: LotlotColors.textPrimary,
      side: const BorderSide(color: LotlotColors.accent, width: 1.2),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    );
    final outlineBist = OutlinedButton.styleFrom(
      foregroundColor: LotlotColors.textPrimary,
      side: const BorderSide(color: LotlotColors.accent, width: 2.1),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _LandingBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Ana sayfa',
                        child: InkWell(
                          onTap: () {
                            // Already on landing — no-op / scroll top later
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: BrandWordmark(height: 30, maxWidth: 180),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Menü',
                        onPressed: () =>
                            _openMenu(context, authenticated: authenticated),
                        icon: const Icon(Icons.menu),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Piyasayı Sezmek Yetmez.\n',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: LotlotColors.textPrimary,
                                  ),
                            ),
                            TextSpan(
                              text: 'Veriye Dayalı Analiz Gerek.',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: LotlotColors.accent,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bireysel yatırımcının en büyük hatası sistemsiz işlem '
                        'yapmaktır. Günde en az 5 kez tüm hisseleri '
                        'değerlendiren yapay zeka altyapısı ile disiplini elden '
                        'bırakmayın.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: LotlotColors.textSecondary,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 28),
                      if (authenticated) ...[
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => const MainShell(),
                              ),
                            );
                          },
                          child: const Text('Uygulamaya Git'),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AuthScreen(
                                  initialMode: AuthMode.register,
                                ),
                              ),
                            );
                          },
                          child: const Text('Ücretsiz Başla'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: outlineLogin,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AuthScreen(
                                  initialMode: AuthMode.login,
                                ),
                              ),
                            );
                          },
                          child: const Text('Giriş Yap'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton(
                        style: outlineBist,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const StocksSearchScreen(),
                            ),
                          );
                        },
                        child: const Text('BIST Hisseleri'),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        'BIST hisselerini incele',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: LotlotColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tam katalogda sembol ve sektörle arayın. '
                        'İzleme listesi ve skorlu tarama için uygulamaya girin.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: LotlotColors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingBackdrop extends StatelessWidget {
  const _LandingBackdrop();

  static const _tickers = [
    'ARCLK',
    'ASTOR',
    'BIMAS',
    'THYAO',
    'GARAN',
    'ASELS',
    'EREGL',
    'FROTO',
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.85),
          radius: 1.3,
          colors: [
            LotlotColors.backgroundMid,
            LotlotColors.background,
            LotlotColors.backgroundDeep,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        child: Stack(
          children: [
            for (var i = 0; i < _tickers.length; i++)
              Positioned(
                left: 24.0 + (i % 3) * 110,
                top: 120.0 + (i ~/ 3) * 160 + (i.isOdd ? 40 : 0),
                child: Opacity(
                  opacity: 0.22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: LotlotColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: LotlotColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        _tickers[i],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LotlotColors.accent.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 36.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
