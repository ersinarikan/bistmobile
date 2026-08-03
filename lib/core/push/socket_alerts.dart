import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';

typedef ActionableAlertHandler = void Function(Map<String, dynamic> payload);

/// Foreground Socket.IO — Premium actionable_alert (§25).
class SocketAlertsClient {
  io.Socket? _socket;
  ActionableAlertHandler? onAlert;

  bool get connected => _socket?.connected == true;

  void connect({
    required String accessToken,
    required String userId,
  }) {
    disconnect();
    try {
      _socket = io.io(
        ApiConfig.baseUrl,
        io.OptionBuilder()
            .setPath('/socket.io')
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': accessToken})
            .enableAutoConnect()
            .build(),
      );
      _socket!
        ..onConnect((_) {
          _socket!.emit('join_user', {'user_id': userId});
        })
        ..on('actionable_alert', (data) {
          if (data is Map) {
            onAlert?.call(Map<String, dynamic>.from(data));
          } else if (data is Map<String, dynamic>) {
            onAlert?.call(data);
          }
        })
        ..onError((e) => debugPrint('SocketAlerts error: $e'));
    } catch (e) {
      debugPrint('SocketAlerts connect failed: $e');
    }
  }

  void disconnect() {
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }
}
