import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/brand/brand_assets.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/deep_link_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';
import '../ai_commentary_session.dart';

/// Web `AI_LOADER_STAGES` — görsel tempo; gerçek backend fazına bağlı değil.
const aiLoaderStages = <({int atMs, String title})>[
  (atMs: 0, title: 'Yapay Zeka Ajanları veri topluyor'),
  (atMs: 20000, title: 'Haberler inceleniyor'),
  (atMs: 30000, title: 'Formasyon tespiti ve görsel doğrulaması yapılıyor'),
  (atMs: 40000, title: 'Adil değer ve KAP verileri inceleniyor'),
  (atMs: 50000, title: 'Hisse Analizi Hazırlanıyor'),
];

const aiCommentaryTitle = 'lotlot.net Yapay Zeka Yorumu';

/// Expected wait for elapsed progress bar (not true LLM %).
const aiLoaderProgressBudget = Duration(seconds: 100);

/// Pro gate + loader overlay + sonuç; iş [AiCommentarySession] içinde.
Future<void> runAiCommentaryFlow(
  BuildContext context, {
  required String symbol,
  int bars = 300,
}) async {
  final auth = context.read<SessionController>();
  if (auth.status != AuthStatus.authenticated) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(popOnSuccess: true),
      ),
    );
    return;
  }
  if (!auth.isPro) {
    await showSoftGateSheet(context, kind: SoftGateKind.pro);
    return;
  }

  final commentary = context.read<AiCommentarySession>();

  unawaited(commentary.start(symbol, bars: bars));

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _AiLoaderHost(commentary: commentary),
  );

  if (!context.mounted) {
    _showResultIfNeeded(commentary);
    return;
  }

  await _presentTerminal(context, commentary);
}

void _showResultIfNeeded(AiCommentarySession commentary) {
  if (commentary.phase != AiCommentaryPhase.ready &&
      commentary.phase != AiCommentaryPhase.failed) {
    return;
  }
  final navCtx = appNavigatorKey.currentContext;
  if (navCtx == null) return;
  unawaited(_presentTerminal(navCtx, commentary));
}

Future<void> _presentTerminal(
  BuildContext context,
  AiCommentarySession commentary,
) async {
  if (commentary.phase == AiCommentaryPhase.ready) {
    final text = commentary.text ?? '';
    final meta = commentary.metaLine ?? (commentary.symbol ?? '');
    commentary.acknowledge();
    if (!context.mounted) return;
    await _showResult(context, text: text, meta: meta, isError: false);
    return;
  }
  if (commentary.phase == AiCommentaryPhase.failed) {
    final err = commentary.errorMessage ?? 'Yorum alınamadı.';
    final meta = commentary.symbol ?? '';
    final status = commentary.lastErrorStatus;
    if (status == 403) {
      commentary.acknowledge();
      if (!context.mounted) return;
      await showSoftGateSheet(context, kind: SoftGateKind.pro);
      return;
    }
    commentary.acknowledge();
    if (!context.mounted) return;
    await _showResult(context, text: err, meta: meta, isError: true);
  }
}

Future<void> _showResult(
  BuildContext context, {
  required String text,
  required String meta,
  required bool isError,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LotlotColors.surface,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            BrandAssets.llmIcon,
            width: 28,
            height: 28,
            errorBuilder: (_, _, _) => const Icon(
              Icons.psychology,
              color: LotlotColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  aiCommentaryTitle,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: const TextStyle(
                      color: LotlotColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(
            text,
            style: TextStyle(
              height: 1.45,
              color: isError ? LotlotColors.danger : LotlotColors.textPrimary,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

/// Listens to [AiCommentarySession] and pops when ready/failed.
class _AiLoaderHost extends StatefulWidget {
  const _AiLoaderHost({required this.commentary});

  final AiCommentarySession commentary;

  @override
  State<_AiLoaderHost> createState() => _AiLoaderHostState();
}

class _AiLoaderHostState extends State<_AiLoaderHost> {
  @override
  void initState() {
    super.initState();
    widget.commentary.addListener(_onCommentary);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onCommentary();
    });
  }

  @override
  void dispose() {
    widget.commentary.removeListener(_onCommentary);
    super.dispose();
  }

  void _onCommentary() {
    final p = widget.commentary.phase;
    if (p == AiCommentaryPhase.ready || p == AiCommentaryPhase.failed) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _AiLoaderDialog();
  }
}

class _AiLoaderDialog extends StatefulWidget {
  const _AiLoaderDialog();

  @override
  State<_AiLoaderDialog> createState() => _AiLoaderDialogState();
}

class _AiLoaderDialogState extends State<_AiLoaderDialog>
    with SingleTickerProviderStateMixin {
  String _title = aiLoaderStages.first.title;
  final _timers = <Timer>[];
  late final AnimationController _progress;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _progress = AnimationController(
      vsync: this,
      duration: aiLoaderProgressBudget,
    )..forward();
    _progress.addListener(() {
      if (mounted) setState(() {});
    });
    for (final stage in aiLoaderStages) {
      if (stage.atMs <= 0) {
        _title = stage.title;
      } else {
        _timers.add(
          Timer(Duration(milliseconds: stage.atMs), () {
            if (!mounted) return;
            setState(() => _title = stage.title);
          }),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _progress.dispose();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _progress.value.clamp(0.0, 1.0);
    final overtime = _progress.status == AnimationStatus.completed;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: LotlotColors.surfaceElevated,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    '${ApiConfig.baseUrl}/static/animasyon.webp',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: LotlotColors.surface,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: LotlotColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: overtime ? null : value,
                  minHeight: 6,
                  backgroundColor: LotlotColors.border,
                  color: LotlotColors.accent,
                ),
              ),
              if (overtime) ...[
                const SizedBox(height: 8),
                const Text(
                  'Hâlâ hazırlanıyor…',
                  style: TextStyle(
                    color: LotlotColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Son güncel veriye dayanarak yapılan analiz birkaç dakika '
                'sürebilir. Lütfen uygulamadan çıkmayın / ekranı kapatmayın.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
