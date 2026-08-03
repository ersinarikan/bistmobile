import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import '../../auth/session_controller.dart';
import '../../pro/soft_gate_sheet.dart';

/// Pro AI commentary — CTA → POST /api/ai/commentary → `text`.
class AiCommentarySection extends StatefulWidget {
  const AiCommentarySection({super.key, required this.symbol});

  final String symbol;

  @override
  State<AiCommentarySection> createState() => _AiCommentarySectionState();
}

class _AiCommentarySectionState extends State<AiCommentarySection> {
  bool _loading = false;
  String? _text;
  String? _error;

  Future<void> _run() async {
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

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<ApiClient>().fetchAiCommentary(
            symbol: widget.symbol,
          );
      if (!mounted) return;
      final text = res['text']?.toString();
      if (res['status']?.toString() == 'success' &&
          text != null &&
          text.isNotEmpty) {
        setState(() {
          _text = text;
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message']?.toString() ?? 'Yorum alınamadı';
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403 && tryShowSoftGateForApiError(context, e)) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _friendly(ApiException e) {
    final code = (e.errorCode ?? '').toLowerCase();
    final status = e.body?['status']?.toString().toLowerCase();
    if (code == 'rate_limited' ||
        code == 'busy' ||
        status == 'busy' ||
        e.statusCode == 429) {
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
    return e.message;
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
            'AI yorum',
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
            'AI yorum Pro planda açılır.',
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () =>
                showSoftGateSheet(context, kind: SoftGateKind.pro),
            child: const Text('Detay'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_text != null) ...[
          Text(
            _text!,
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: LotlotColors.danger, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: _loading ? null : _run,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_text == null ? 'Yorum oluştur' : 'Yenile'),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Birkaç saniye sürebilir…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LotlotColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        if (_text == null && _error == null && !_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Sunucu kısa Türkçe teknik yorum üretir. '
              'İstek birkaç saniye sürebilir.',
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
