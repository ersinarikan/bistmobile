import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/brand/brand_assets.dart';
import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';

/// Web `AI_LOADER_STAGES` — görsel tempo; gerçek backend fazına bağlı değil.
const aiLoaderStages = <({int atMs, String title})>[
  (atMs: 0, title: 'Yapay Zeka Ajanları veri topluyor'),
  (atMs: 20000, title: 'Haberler inceleniyor'),
  (atMs: 30000, title: 'Formasyon tespiti ve görsel doğrulaması yapılıyor'),
  (atMs: 40000, title: 'Adil değer ve KAP verileri inceleniyor'),
  (atMs: 50000, title: 'Hisse Analizi Hazırlanıyor'),
];

const aiCommentaryTitle = 'lotlot.net Yapay Zeka Yorumu';

/// Marka etiketi — API’deki ham Ollama adı (qwen3…) gösterilmez; web SoT gibi sabit.
const aiCommentaryModelLabel = 'lotlotLLMv17';

/// Web popup meta: `SYM • lotlotLLMv17 • …` (model alanı marka; ham `model` yok).
String aiCommentaryMetaFromResponse(
  String symbol,
  Map<String, dynamic> data,
) {
  final parts = <String>[
    symbol.toUpperCase(),
    aiCommentaryModelLabel,
  ];
  final variant = data['prompt_variant']?.toString();
  if (variant != null &&
      variant.isNotEmpty &&
      variant.toLowerCase() != 'short') {
    parts.add(variant);
  }
  if (data['cached'] == true) parts.add('cache');
  final dur = data['duration_s'];
  if (dur is num) parts.add('${dur.toStringAsFixed(2)}s');
  return parts.join(' • ');
}

/// Pro gate + loader overlay + sonuç diyaloğu (büyük grafik / Keşfet ortak).
Future<void> runAiCommentaryFlow(
  BuildContext context, {
  required String symbol,
  int bars = 300,
}) async {
  final session = context.read<SessionController>();
  if (session.status != AuthStatus.authenticated) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(popOnSuccess: true),
      ),
    );
    return;
  }
  if (!session.isPro) {
    await showSoftGateSheet(context, kind: SoftGateKind.pro);
    return;
  }

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const _AiLoaderDialog(),
    ),
  );

  Map<String, dynamic>? data;
  Object? err;
  try {
    data = await context.read<ApiClient>().fetchAiCommentary(
          symbol: symbol,
          bars: bars,
        );
  } catch (e) {
    err = e;
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  if (!context.mounted) return;

  if (err is ApiException) {
    if (err.statusCode == 403 && tryShowSoftGateForApiError(context, err)) {
      return;
    }
    await _showResult(
      context,
      text: _friendlyApi(err),
      meta: symbol.toUpperCase(),
      isError: true,
    );
    return;
  }
  if (err != null || data == null) {
    await _showResult(
      context,
      text: 'Yorum alınamadı; tekrar deneyin.',
      meta: symbol.toUpperCase(),
      isError: true,
    );
    return;
  }

  final status = data['status']?.toString() ?? '';
  final text = data['text']?.toString();
  if (status == 'success' && text != null && text.isNotEmpty) {
    await _showResult(
      context,
      text: text,
      meta: aiCommentaryMetaFromResponse(symbol, data),
      isError: false,
    );
    return;
  }
  if (status == 'busy') {
    await _showResult(
      context,
      text: data['message']?.toString() ??
          'Model meşgul; biraz sonra tekrar deneyin.',
      meta: symbol.toUpperCase(),
      isError: true,
    );
    return;
  }
  await _showResult(
    context,
    text: data['message']?.toString() ?? 'Yorum alınamadı.',
    meta: symbol.toUpperCase(),
    isError: true,
  );
}

String _friendlyApi(ApiException e) {
  final code = (e.errorCode ?? '').toLowerCase();
  final status = e.body?['status']?.toString().toLowerCase();
  if (code == 'busy' || status == 'busy' || e.statusCode == 429) {
    if (status == 'busy' || code == 'busy') {
      return e.message.isNotEmpty
          ? e.message
          : 'Model meşgul; biraz sonra tekrar deneyin.';
    }
    return e.message.isNotEmpty
        ? e.message
        : 'Çok sık istek; lütfen biraz bekleyin.';
  }
  if (e.statusCode == 502 || e.statusCode == 500) {
    return e.message.isNotEmpty
        ? e.message
        : 'Yorum üretilemedi; tekrar deneyin.';
  }
  return e.message.isNotEmpty ? e.message : 'Yorum alınamadı.';
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

class _AiLoaderDialog extends StatefulWidget {
  const _AiLoaderDialog();

  @override
  State<_AiLoaderDialog> createState() => _AiLoaderDialogState();
}

class _AiLoaderDialogState extends State<_AiLoaderDialog> {
  String _title = aiLoaderStages.first.title;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 8),
              const Text(
                'Son güncel veriye dayanarak yapılan analiz birkaç dakika sürebilir.',
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
