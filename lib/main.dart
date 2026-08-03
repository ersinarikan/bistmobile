import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/navigation/deep_link_router.dart';
import 'core/push/push_service.dart';
import 'core/push/socket_alerts.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session_controller.dart';
import 'features/browse/browse_controller.dart';
import 'features/splash/splash_screen.dart';
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

class _LotlotAppState extends State<LotlotApp> {
  late final TokenStorage _tokens;
  late final ApiClient _api;
  late final SessionController _session;
  late final PushService _push;
  late final SocketAlertsClient _socket;

  AuthStatus? _lastAuth;
  bool? _lastPushOn;
  bool? _lastPremium;
  bool _sessionBusy = false;

  @override
  void initState() {
    super.initState();
    _tokens = TokenStorage();
    _api = ApiClient(tokenStorage: _tokens);
    _session = SessionController(tokenStorage: _tokens, apiClient: _api);
    _push = PushService(apiClient: _api)
      ..firebaseReady = widget.firebaseReady
      ..statusMessage = widget.firebaseReady
          ? null
          : 'Firebase yapılandırılmadı (google-services / GoogleService-Info).';
    if (widget.firebaseReady) {
      _push.attachMessagingHandlers();
      _push.addListener(_onPushTokenRefresh);
    }
    _socket = SocketAlertsClient()
      ..onAlert = showActionableAlertSnack;
    _session.addListener(_onSession);

    if (widget.firebaseReady) {
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        openDeepLink(msg.data['deep_link']?.toString());
      });
      FirebaseMessaging.instance.getInitialMessage().then((msg) {
        if (msg != null) {
          openDeepLink(msg.data['deep_link']?.toString());
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      flushPendingDeepLink();
    });
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
          await _push.unregisterQuiet(clearAll: true);
          _socket.disconnect();
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
      } else {
        _socket.disconnect();
      }
    } finally {
      _sessionBusy = false;
    }
  }

  @override
  void dispose() {
    _push.removeListener(_onPushTokenRefresh);
    _session.removeListener(_onSession);
    _socket.disconnect();
    _session.dispose();
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
        ChangeNotifierProvider(
          create: (_) => BrowseController(apiClient: _api),
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
