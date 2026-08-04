import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';
import 'ai_commentary_flow.dart';

/// Pro AI commentary — CTA → loader overlay + sonuç diyaloğu (web parity).
class AiCommentarySection extends StatefulWidget {
  const AiCommentarySection({super.key, required this.symbol});

  final String symbol;

  @override
  State<AiCommentarySection> createState() => _AiCommentarySectionState();
}

class _AiCommentarySectionState extends State<AiCommentarySection> {
  bool _loading = false;
  bool _doneOnce = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    await runAiCommentaryFlow(context, symbol: widget.symbol);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _doneOnce = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final auth = session.status == AuthStatus.authenticated;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            aiCommentaryTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LotlotColors.surface,
              borderRadius: BorderRadius.circular(LotlotColors.radiusMd),
              border: Border.all(color: LotlotColors.border),
            ),
            child: _body(auth, session),
          ),
        ],
      ),
    );
  }

  Widget _body(bool auth, SessionController session) {
    if (!auth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kısa teknik yorum için giriş yapın.',
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginScreen(popOnSuccess: true),
                ),
              );
            },
            child: const Text('Giriş yap'),
          ),
        ],
      );
    }

    if (!session.isPro) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Yapay zeka yorumu Pro planda açılır.',
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () =>
                showSoftGateSheet(context, kind: SoftGateKind.pro),
            child: const Text('Planları gör'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _loading ? null : _run,
          icon: const Icon(Icons.psychology, size: 20),
          label: Text(
            _doneOnce ? 'Yorumu yenile' : 'lotlot.net Yorumu',
          ),
        ),
        if (!_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Sunucu kısa Türkçe teknik yorum üretir. '
              'Analiz birkaç dakika sürebilir.',
              style: TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}
