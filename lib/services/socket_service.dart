import 'dart:async';
import 'dart:math' show min;

import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/social_room_state.dart';
import 'api_service.dart';

class SocketService {
  SocketService({String? baseUrl})
    : _baseUrl = baseUrl ?? ApiService.socketBaseUrl;

  final String _baseUrl;
  final _roomStateController = StreamController<SocialRoomState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  io.Socket? _socket;
  Map<String, dynamic>? _pendingJoinPayload;
  List<ProductModel> _roomOptions = const [];

  // Reconnection state
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);
  bool _intentionalDisconnect = false;

  Stream<SocialRoomState> get roomStateStream => _roomStateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get connectionStateStream => _connectionController.stream;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    // Dead/stale socket path: tear down and rebuild with a fresh token if an
    // existing socket is not connected (socket_io_client goes idle forever once
    // its reconnect budget is exhausted, so the app would stay dead after a
    // backend restart until a full page reload).
    if (_socket != null) {
      _teardownCurrentSocket();
    }

    _intentionalDisconnect = false;

    final idToken = await _getIdToken();

    final socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setAuth({'token': idToken})
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      _reconnectAttempts = 0;
      if (!_connectionController.isClosed) {
        _connectionController.add(true);
      }
      final pendingJoinPayload = _pendingJoinPayload;
      if (pendingJoinPayload != null) {
        socket.emit('join_room', pendingJoinPayload);
      }
    });

    socket.onDisconnect((_) {
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
      if (!_intentionalDisconnect) {
        _scheduleReconnect();
      }
    });

    socket.on('room_state', (payload) {
      if (payload is Map && !_roomStateController.isClosed) {
        _roomStateController.add(
          SocialRoomState.fromJson(
            Map<String, dynamic>.from(payload),
            _roomOptions,
          ),
        );
      }
    });

    socket.on('vote_updated', (payload) {
      if (payload is Map && !_roomStateController.isClosed) {
        _roomStateController.add(
          SocialRoomState.fromJson(
            Map<String, dynamic>.from(payload),
            _roomOptions,
          ),
        );
      }
    });

    socket.on('socket_error', (payload) {
      if (!_errorController.isClosed) {
        _errorController.add(payload?.toString() ?? 'Socket error');
      }
    });

    socket.onConnectError((error) {
      if (!_errorController.isClosed) {
        _errorController.add('Connection failed: $error');
      }
    });

    socket.onError((error) {
      if (!_errorController.isClosed) {
        _errorController.add(error?.toString() ?? 'Unknown socket error');
      }
    });

    socket.connect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true) return;

    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnectAttempts) {
      if (!_errorController.isClosed) {
        _errorController.add('Connection lost. Please check your network and try again.');
      }
      return;
    }

    final delayMs = min(
      _baseDelay.inMilliseconds * (1 << (_reconnectAttempts - 1)),
      _maxDelay.inMilliseconds,
    );

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_intentionalDisconnect || _socket?.connected == true) return;

      final freshToken = await _getIdToken();
      if (freshToken == null) {
        if (!_errorController.isClosed) {
          _errorController.add(
            'Couldn\'t refresh your session. Please sign in again.',
          );
        }
        return;
      }
      _socket?.auth = {'token': freshToken};

      try {
        _socket?.connect();
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
    } catch (_) {}
    return null;
  }

  Future<void> joinRoom({
    required String roomId,
    required List<ProductModel> options,
  }) async {
    _roomOptions = options;
    _pendingJoinPayload = {
      'roomId': roomId,
      'options': [
        for (final option in options) {'id': option.id, 'title': option.name},
      ],
    };

    await connect();
    if (isConnected) {
      _socket?.emit('join_room', _pendingJoinPayload);
    }
  }

  void sendVote({
    required String roomId,
    required String optionId,
  }) {
    _socket?.emit('send_vote', {
      'roomId': roomId,
      'optionId': optionId,
    });
  }

  void _teardownCurrentSocket() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _socket?.dispose();
    _socket = null;
  }

  void disconnect() {
    _teardownCurrentSocket();
  }

  void dispose() {
    disconnect();
    _roomStateController.close();
    _errorController.close();
    _connectionController.close();
  }
}
