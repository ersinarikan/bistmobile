import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/navigation/deep_link_router.dart';
import 'core/push/app_badge.dart';
import 'core/push/push_service.dart';
import 'core/push/socket_alerts.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session_controller.dart';
import 'features/billing/billing_controller.dart';
import 'features/browse/browse_controller.dart';
import 'features/notifications/inbox_controller.dart';
import 'features/splash/splash_screen.dart';
import 'features/stock/ai_commentary_session.dart';
import 'features/stocks/stocks_catalog_controller.dart';
import 'features/watchlist/watchlist_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }
  runApp(LotlotApp(firebaseReady: firebaseReady));
}

class LotlotApp extends StatefulWidget {
  const LotlotApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<LotlotApp> createState() => _LotlotAppState();
}

class _LotlotAppState extends State<LotlotApp> with WidgetsBindingObserver {
  late final TokenStorage _tokens;
  late final ApiClient _api;
  late final SessionController _session;
  late final PushService _push;
  late final SocketAlertsClient _socket;
  late final AiCommentarySession _commentary;
  late final InboxController _inbox;
  StreamSubscription<Uri>? _appLinkSub;

  AuthStatus? _lastAuth;
  bool? _lastPushOn;
  bool? _lastPremium;
  bool _sessionBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tokens = TokenStorage();
    _api = ApiClient(tokenStorage: _tokens);
    _session = SessionController(tokenStorage: _tokens, apiClient: _api);
    _push = PushService(apiClient: _api)
      ..firebaseReady = widget.firebaseReady
      ..statusMessage = widget.firebaseReady
          ? null
          : 'Firebase yapılandırması eksik (GoogleService-Info.plist).';
    if (!widget.firebaseReady) {
      debugPrint(
        'Firebase init skipped earlier; push registration unavailable '
        '(google-services / GoogleService-Info).',
      );
    }
    if (widget.firebaseReady) {
      _push.attachMessagingHandlers();
      _push.addListener(_onPushTokenRefresh);
    }
    _socket = SocketAlertsClient()
      ..onAlert = showActionableAlertSnack;
    _commentary = AiCommentarySession(apiClient: _api);
    _inbox = InboxController(apiClient: _api);
    // Unregister FCM while access token is still valid (api.logout clears storage).
    _session.beforeLogout = () async {
      await _push.unregisterQuiet(clearAll: true);
      await AppBadge.clear();
      _inbox.resetLocal();
    };
    _session.addListener(_onSession);

    if (widget.firebaseReady) {
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        unawaited(AppBadge.clear());
        openDeepLink(msg.data['deep_link']?.toString());
      });
      FirebaseMessaging.instance.getInitialMessage().then((msg) {
        if (msg != null) {
          unawaited(AppBadge.clear());
          openDeepLink(msg.data['deep_link']?.toString());
        }
      });
    }

    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) openDeepLink(uri.toString());
    });
    _appLinkSub = appLinks.uriLinkStream.listen((uri) {
      openDeepLink(uri.toString());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppBadge.clear());
      flushPendingDeepLink();
      unawaited(_syncInboxBadge());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppBadge.clear());
      unawaited(_syncInboxBadge());
    }
  }

  Future<void> _syncInboxBadge() async {
    if (_session.status != AuthStatus.authenticated) return;
    if (!_session.isPremium || !_session.pushNotificationsOn) {
      await AppBadge.clear();
      return;
    }
    await _inbox.refreshSummary();
  }

  void _onPushTokenRefresh() {
    if (_session.status != AuthStatus.authenticated) return;
    if (!_session.isPremium || !_session.pushNotificationsOn) return;
    _push.syncRegistration(
      isPremium: true,
      pushOn: true,
    );
  }

  Future<void> _onSession() async {
    if (_sessionBusy) return;
    _sessionBusy = true;
    try {
      final status = _session.status;
      if (status != AuthStatus.authenticated) {
        if (_lastAuth == AuthStatus.authenticated) {
          // Prefer SessionController.beforeLogout (authed unregister). Fallback only.
          await _push.unregisterQuiet(clearAll: true);
          _socket.disconnect();
          _commentary.clear();
          _inbox.resetLocal();
          await AppBadge.clear();
        }
        _lastAuth = status;
        _lastPushOn = null;
        _lastPremium = null;
        return;
      }

      final pushOn = _session.pushNotificationsOn;
      final premium = _session.isPremium;
      final authChanged = status != _lastAuth;
      final prefsChanged =
          pushOn != _lastPushOn || premium != _lastPremium;
      _lastAuth = status;
      _lastPushOn = pushOn;
      _lastPremium = premium;

      if (!authChanged && !prefsChanged) return;

      await _push.syncRegistration(isPremium: premium, pushOn: pushOn);
      final access = await _tokens.readAccessToken();
      final uid = _session.userId;
      if (access != null && uid != null && premium && pushOn) {
        _socket.connect(accessToken: access, userId: uid);
        await _inbox.refreshSummary(force: true);
      } else {
        _socket.disconnect();
        await AppBadge.clear();
      }
    } finally {
      _sessionBusy = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appLinkSub?.cancel();
    _push.removeListener(_onPushTokenRefresh);
    _session.removeListener(_onSession);
    _socket.disconnect();
    _session.dispose();
    _commentary.dispose();
    _inbox.dispose();
    _push.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokens),
        Provider<ApiClient>.value(value: _api),
        ChangeNotifierProvider<PushService>.value(value: _push),
        Provider<SocketAlertsClient>.value(value: _socket),
        ChangeNotifierProvider<SessionController>.value(value: _session),
        ChangeNotifierProvider<AiCommentarySession>.value(value: _commentary),
        ChangeNotifierProvider<InboxController>.value(value: _inbox),
        ChangeNotifierProvider(
          create: (ctx) => BillingController(
            apiClient: ctx.read<ApiClient>(),
            session: ctx.read<SessionController>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BrowseController(apiClient: _api),
        ),
        ChangeNotifierProvider(
          create: (_) => StocksCatalogController(apiClient: _api),
        ),
        ChangeNotifierProvider(
          create: (_) => WatchlistController(apiClient: _api),
        ),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'LOTLOT.NET',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const SplashScreen(),
      ),
    );
  }
}
