import 'dart:async';
import 'dart:math' show min;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/blend_model.dart';
import '../models/group_message.dart';
import 'api_service.dart';
import 'dev_auth.dart';
import 'feature_flags.dart';

class BlendSocketService {
  BlendSocketService._();
  static BlendSocketService? _instance;
  static BlendSocketService get instance {
    _instance ??= BlendSocketService._();
    return _instance!;
  }

  String swipeTypeToApi(SwipeType type) {
    switch (type) {
      case SwipeType.like:
        return 'like';
      case SwipeType.dislike:
        return 'dislike';
      case SwipeType.love:
        return 'love';
      case SwipeType.pass:
        return 'pass';
      case SwipeType.superLike:
        return 'superlike';
    }
  }

  factory BlendSocketService() => instance;

  String get _baseUrl => ApiService.socketBaseUrl;
  final _stateController = StreamController<BlendLiveState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  final _messageController = StreamController<GroupMessage>.broadcast();
  final _swipeAppliedController =
      StreamController<Map<String, dynamic>>.broadcast();

  io.Socket? _socket;
  Map<String, dynamic>? _pendingJoin;

  // Reconnection state
  Timer? _reconnectTimer;
  Timer? _tokenRefreshTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);
  bool _intentionalDisconnect = false;

  Stream<BlendLiveState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<GroupMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStateStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get swipeAppliedStream =>
      _swipeAppliedController.stream;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    // Dead/stale socket path: if a socket exists but is not connected it may
    // be past its reconnect budget — socket_io_client's engine goes idle after
    // its reconnect attempts are exhausted and later `.connect()` calls become
    // silent no-ops. That left the app with a permanently dead socket after a
    // backend restart until a full page reload. Tear down and rebuild with a
    // fresh, current auth token so the demo self-heals.
    if (_socket != null) {
      _teardownCurrentSocket();
    }

    _intentionalDisconnect = false;

    final idToken = await _getIdToken();
    if (idToken == null) {
      if (!_errorController.isClosed) {
        _errorController.add(
          'Couldn\'t get an auth token. Please sign in again.',
        );
      }
      return;
    }

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
    _wireListeners(socket);
    socket.connect();
  }

  void _wireListeners(io.Socket socket) {
    socket.onConnect((_) {
      _reconnectAttempts = 0;
      if (!_connectionController.isClosed) {
        _connectionController.add(true);
      }
      final pending = _pendingJoin;
      if (pending != null) socket.emit('join_blend', pending);
      _tokenRefreshTimer?.cancel();
      _tokenRefreshTimer = Timer.periodic(
        const Duration(minutes: 45),
        (_) => refreshAuth(),
      );
    });

    socket.onDisconnect((_) {
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
      if (!_intentionalDisconnect) {
        _scheduleReconnect();
      }
    });

    socket.on('blend_state', (payload) {
      if (payload is Map && !_stateController.isClosed) {
        _stateController.add(
          BlendLiveState.fromJson(Map<String, dynamic>.from(payload)),
        );
      }
    });

    // P1 OPTIMIZATION: Listen for lightweight swipe_applied events
    // These are emitted after every swipe instead of full blend_state recomputes.
    // The client can use these for immediate UI feedback (next product transition)
    // and call get_blend_state() explicitly when it needs full state (e.g., after reconnect).
    socket.on('swipe_applied', (payload) {
      if (payload is Map && !_swipeAppliedController.isClosed) {
        _swipeAppliedController.add(Map<String, dynamic>.from(payload));
      }
    });

    socket.on('swipe_confirmed', (payload) {
      if (payload is Map && !_errorController.isClosed) {
        // Confirmation that this client's swipe was received
      }
    });

    socket.on('message_created', (payload) {
      if (payload is Map && !_messageController.isClosed) {
        _messageController.add(
          GroupMessage.fromJson(Map<String, dynamic>.from(payload)),
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
  }

  Future<void> getBlendState(String groupId) async {
    /// P1 RESYNC: Request full blend state from server after reconnect
    /// This triggers a fresh compute_blend_results() on the backend
    if (isConnected) {
      _socket?.emit('get_blend_state', {'groupId': groupId});
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true) return;

    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnectAttempts) {
      if (!_errorController.isClosed) {
        _errorController.add(
          'Connection lost. Please check your network and try again.',
        );
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
        if (_reconnectAttempts <= _maxReconnectAttempts) {
          _scheduleReconnect();
        }
      }
    });
  }

  Future<String?> _getIdToken() async {
    // Dev auth bypass MUST use the dev token here too — otherwise the demo
    // frontend presents a real Firebase ID token that the dev-mode backend
    // cannot verify, and no socket connection (chat/swipes) would ever work.
    if (FeatureFlags.devAuthBypass) {
      return DevAuth.devToken();
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
    } catch (_) {}
    return null;
  }

  Future<void> joinBlend({
    required String groupId,
    required String userId,
    required String userName,
  }) async {
    // P2: Server ignores userId/userName (uses verified uid from token instead).
    // Still accepting these parameters for backward compatibility with callers,
    // but not including them in the payload.
    _pendingJoin = {'groupId': groupId};

    await connect();
    if (isConnected) {
      _socket?.emit('join_blend', _pendingJoin);
      // P1 RESYNC: After joining, request full blend state to ensure UI has complete,
      // up-to-date data (compatibility scores, all members, swipe counts, etc.)
      // This is critical for initial connect; reconnects are handled by connectionStateStream listener
      await Future.delayed(Duration(milliseconds: 100));
      getBlendState(groupId);
    }
  }

  void leaveBlend({required String groupId}) {
    _socket?.emit('leave_blend', {'groupId': groupId});
    _pendingJoin = null;
  }

  Future<void> refreshAuth() async {
    final idToken = await _getIdToken();
    if (idToken != null && isConnected) {
      _socket?.emit('refresh_auth', {'token': idToken});
    }
  }

  void sendSwipe({
    required String groupId,
    required String productId,
    required String userId,
    required String userName,
    required SwipeType swipeType,
  }) {
    // P2: Server ignores userId/userName (uses verified uid from token instead).
    // Still accepting these parameters for backward compatibility with callers,
    // but not including them in the payload.
    _socket?.emit('blend_swipe', {
      'groupId': groupId,
      'productId': productId,
      'swipeType': swipeTypeToApi(swipeType),
    });
  }

  Future<void> sendMessage({
    required String groupId,
    required String userId,
    required String userName,
    required String message,
    String? attachedProductId,
    String? attachedProductTitle,
    String? attachedProductImage,
    String? attachedProductPrice,
  }) async {
    // P2: Server ignores userId/userName (uses verified uid from token instead).
    // Still accepting these parameters for backward compatibility with callers,
    // but not including them in the payload.
    // Reliability fix: make sure we're connected AND joined to this blend
    // before emitting. Previously this was a blind emit that silently dropped
    // messages when the socket was disconnected (or had only just connected).
    await connect();
    if (!isConnected) {
      if (!_errorController.isClosed) {
        _errorController.add(
          'You\'re offline. Message couldn\'t be sent — try again when connected.',
        );
      }
      return;
    }
    if (_pendingJoin?['groupId'] != groupId) {
      _pendingJoin = {'groupId': groupId};
      _socket?.emit('join_blend', _pendingJoin);
      // Give the server a beat to register the membership before sending.
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _socket?.emit('send_message', {
      'groupId': groupId,
      'message': message,
      'attachedProductId': attachedProductId,
      'attachedProductTitle': attachedProductTitle,
      'attachedProductImage': attachedProductImage,
      'attachedProductPrice': attachedProductPrice,
    });
  }

  void _teardownCurrentSocket() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    _reconnectAttempts = 0;
    _socket?.dispose();
    _socket = null;
  }

  void disconnect() {
    _teardownCurrentSocket();
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _errorController.close();
    _messageController.close();
    _connectionController.close();
    _swipeAppliedController.close();
    _instance = null;
  }
}