/// Base class for Socket.IO services
/// 
/// This class consolidates common Socket.IO functionality used by both
/// SocketService (social rooms) and BlendSocketService (blend voting).
/// 
/// Provides:
/// - Connection/reconnection management with exponential backoff
/// - Firebase token-based authentication
/// - Automatic token refresh
/// - Event streaming
/// - Error handling and recovery
library;

import 'package:meta/meta.dart';
import 'dart:async';
import 'dart:math' show min;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';

/// Base configuration for Socket.IO connections
class SocketConfig {
  final String baseUrl;
  final Duration reconnectDelay;
  final Duration reconnectDelayMax;
  final int maxReconnectAttempts;
  final bool autoConnect;

  SocketConfig({
    String? baseUrl,
    this.reconnectDelay = const Duration(seconds: 1),
    this.reconnectDelayMax = const Duration(seconds: 30),
    this.maxReconnectAttempts = 10,
    this.autoConnect = false,
  }) : baseUrl = baseUrl ?? ApiService.socketBaseUrl;
}

/// Base Socket.IO service with common connection/reconnection logic
abstract class BaseSocketService {
  BaseSocketService({SocketConfig? config})
      : _config = config ?? SocketConfig();

  final SocketConfig _config;
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  io.Socket? _socket;

  // Reconnection state
  Timer? _reconnectTimer;
  Timer? _tokenRefreshTimer;
  int _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;

  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get connectionStateStream => _connectionController.stream;
  bool get isConnected => _socket?.connected ?? false;



  /// Override to handle incoming socket events
  void setupEventListeners(io.Socket socket) {
    socket.onConnect((_) => _handleConnect());
    socket.onDisconnect((_) => _handleDisconnect());
    socket.onConnectError((error) => _handleConnectError(error));
    socket.on('socket_error', (payload) => _handleSocketError(payload));
  }

  /// Override to emit pending data after reconnect
  void _resendPendingData() {}

  /// Connect to Socket.IO server
  /// Reuses existing connection if connected; tears down and rebuilds a stale
  /// one (socket_io_client's engine goes idle forever after its reconnect
  /// budget is exhausted, so a dead socket would otherwise require a page
  /// reload to recover).
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    if (_socket != null) {
      _teardownCurrentSocket();
    }

    _intentionalDisconnect = false;

    final idToken = await _getIdToken();
    if (idToken == null) {
      _emitError('Unable to get authentication token');
      return;
    }

    final socket = io.io(
      _config.baseUrl,
      io.OptionBuilder()
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(_config.maxReconnectAttempts)
          .setReconnectionDelay(_config.reconnectDelay.inMilliseconds)
          .setReconnectionDelayMax(_config.reconnectDelayMax.inMilliseconds)
          .setAuth({'token': idToken})
          .build(),
    );

    _socket = socket;
    setupEventListeners(socket);
    socket.connect();
  }

  /// Called when socket successfully connects
  void _handleConnect() {
    _reconnectAttempts = 0;
    _emitConnectionState(true);
    _resendPendingData();
    _startTokenRefreshTimer();
  }

  /// Called when socket disconnects
  void _handleDisconnect() {
    _emitConnectionState(false);
    _stopTokenRefreshTimer();
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  /// Called when connection error occurs
  void _handleConnectError(dynamic error) {
    _emitError('Connection failed: $error');
  }

  /// Called when socket server sends error
  void _handleSocketError(dynamic payload) {
    _emitError(payload?.toString() ?? 'Socket error');
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true) return;

    _reconnectAttempts++;
    if (_reconnectAttempts > _config.maxReconnectAttempts) {
      _emitError(
        'Connection lost after ${_config.maxReconnectAttempts} attempts. '
        'Please check your network and restart the app.',
      );
      return;
    }

    final delayMs = min(
      _config.reconnectDelay.inMilliseconds * (1 << (_reconnectAttempts - 1)),
      _config.reconnectDelayMax.inMilliseconds,
    );

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_intentionalDisconnect || _socket?.connected == true) return;

      final freshToken = await _getIdToken();
      if (freshToken == null) {
        _emitError(
          'Couldn\'t refresh your session. Please sign in again.',
        );
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

  /// Start periodic token refresh (every 45 minutes)
  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer();
    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 45),
      (_) => _refreshAuthToken(),
    );
  }

  /// Stop the token refresh timer
  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  /// Refresh authentication token with server
  /// Override for specific implementation
  Future<void> _refreshAuthToken() async {
    final idToken = await _getIdToken();
    if (idToken != null && isConnected) {
      _socket?.emit('refresh_auth', {'token': idToken});
    }
  }

  /// Get fresh Firebase ID token
  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
    } catch (_) {}
    return null;
  }

  /// Emit event to socket server
  void emit(String event, [dynamic data]) {
    if (isConnected) {
      _socket?.emit(event, data);
    } else {
      _emitError('Socket not connected. Event "$event" not sent.');
    }
  }

  /// Gracefully disconnect from socket
  void disconnect() {
    _teardownCurrentSocket();
  }

  void _teardownCurrentSocket() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopTokenRefreshTimer();
    _reconnectAttempts = 0;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Clean up resources
  void dispose() {
    disconnect();
    _socket = null;
    _errorController.close();
    _connectionController.close();
  }

  // Protected helpers for subclasses

  /// Emit error message to error stream
  @protected
  void emitError(String message) => _emitError(message);

  /// Emit connection state change
  @protected
  void emitConnectionState(bool connected) => _emitConnectionState(connected);

  void _emitError(String message) {
    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }

  void _emitConnectionState(bool connected) {
    if (!_connectionController.isClosed) {
      _connectionController.add(connected);
    }
  }

  /// Get current socket instance (for event listeners)
  @protected
  io.Socket? get socket => _socket;
}