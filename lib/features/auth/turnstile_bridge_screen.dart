import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';
import 'auth_helpers.dart';

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
  var _completed = false;

  /// Prod bridge sitekey (public; HTML ile aynı). Render’ı Flutter’dan
  /// yeniden bağlarız çünkü sayfa `postMessage(object)` yolluyor ve
  /// top-level WKWebView’da `parent !== window` false — token kayboluyordu.
  static const _siteKey = '0x4AAAAAADFC6pJ_itsqf9ND';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(LotlotColors.background)
      // SECURITY: Channel only accepts Turnstile token JSON from allowlisted
      // origins (see onNavigationRequest). No app secrets are exposed to JS.
      ..addJavaScriptChannel(
        'turnstileBridge', // NOSONAR — §8.6 bridge; token-only, allowlisted nav
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (isAllowedTurnstileNavigation(request.url)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (_) async {
            await _installFlutterBridge();
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            // Android WebView sıkça favicon/CF alt kaynağı için de hata basar;
            // ana sayfa + Turnstile yine çalışır. Yalnız main-frame göster.
            if (err.isForMainFrame != true) return;
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

  /// String kanal + Turnstile’ı `appearance: always` ile yeniden mount.
  Future<void> _installFlutterBridge() async {
    await _controller.runJavaScript('''
(function() {
  function deliver(token) {
    try {
      if (!token) return;
      var payload = JSON.stringify({ turnstile_token: String(token) });
      if (window.turnstileBridge && window.turnstileBridge.postMessage) {
        window.turnstileBridge.postMessage(payload);
      }
    } catch (e) {}
  }
  window.__lotlotDeliverTurnstile = deliver;

  // Obje postMessage → JSON string (native handler kırılmasın)
  try {
    var h = window.webkit && window.webkit.messageHandlers &&
      window.webkit.messageHandlers.turnstileBridge;
    if (h && !h.__lotlotPatched) {
      var orig = h.postMessage.bind(h);
      h.postMessage = function(msg) {
        if (typeof msg !== 'string') {
          try { msg = JSON.stringify(msg); } catch (e) { return; }
        }
        orig(msg);
      };
      h.__lotlotPatched = true;
    }
  } catch (e) {}

  function remount() {
    if (!window.turnstile) return false;
    var el = document.getElementById('turnstile-mount');
    if (!el) return false;
    try { el.innerHTML = ''; } catch (e) {}
    try {
      window.turnstile.render('#turnstile-mount', {
        sitekey: '$_siteKey',
        appearance: 'always',
        callback: deliver,
        'expired-callback': function () { deliver(''); },
        'error-callback': function () { deliver(''); }
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  if (remount()) return;
  var n = 0;
  var iv = setInterval(function () {
    n++;
    if (remount() || n > 40) clearInterval(iv);
  }, 150);
})();
''');
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    if (_completed) return;
    final raw = message.message.trim();
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final token = decoded['turnstile_token']?.toString() ?? '';
      if (token.isEmpty) return;
      _completed = true;
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
                          _completed = false;
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
          if (!_loading && _error == null)
            const Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Text(
                'Kutuyu işaretleyin; doğrulama bitince kayıt devam eder.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LotlotColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
