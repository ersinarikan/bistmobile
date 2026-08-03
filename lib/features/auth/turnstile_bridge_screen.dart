import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';

/// Cloudflare Turnstile köprüsü — §8.6.
/// Prod URL zorunlu; token [Navigator.pop] ile `String` olarak döner.
class TurnstileBridgeScreen extends StatefulWidget {
  const TurnstileBridgeScreen({super.key});

  /// Köprüyü açar; geçerli token veya `null` (iptal) döner.
  static Future<String?> open(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const TurnstileBridgeScreen(),
      ),
    );
  }

  @override
  State<TurnstileBridgeScreen> createState() => _TurnstileBridgeScreenState();
}

class _TurnstileBridgeScreenState extends State<TurnstileBridgeScreen> {
  late final WebViewController _controller;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(LotlotColors.background)
      ..addJavaScriptChannel(
        'turnstileBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (_) async {
            await _injectMessageForwarder();
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = 'Doğrulama sayfası yüklenemedi.';
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(ApiConfig.turnstileBridgeUrl));
  }

  /// Sayfa `postMessage` / parent mesajlarını Flutter kanalına iletir.
  Future<void> _injectMessageForwarder() async {
    await _controller.runJavaScript('''
(function() {
  if (window.__lotlotTurnstileHooked) return;
  window.__lotlotTurnstileHooked = true;
  function forward(raw) {
    try {
      var s = (typeof raw === 'string') ? raw : JSON.stringify(raw);
      if (window.turnstileBridge && window.turnstileBridge.postMessage) {
        window.turnstileBridge.postMessage(s);
      }
    } catch (e) {}
  }
  window.addEventListener('message', function(ev) { forward(ev.data); });
})();
''');
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    final raw = message.message.trim();
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final token = decoded['turnstile_token']?.toString() ?? '';
      if (token.isEmpty) return; // süre dolumu — yok say (§8.6)
      if (!mounted) return;
      Navigator.of(context).pop(token);
    } catch (_) {
      // Geçersiz JSON yok say
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvenlik doğrulaması'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: LotlotColors.accent),
            ),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: LotlotColors.danger),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _loading = true;
                        });
                        _controller.loadRequest(
                          Uri.parse(ApiConfig.turnstileBridgeUrl),
                        );
                      },
                      child: const Text('Yeniden dene'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
