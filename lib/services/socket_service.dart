import 'dart:async';
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

  io.Socket? _socket;
  Map<String, dynamic>? _pendingJoinPayload;
  List<ProductModel> _roomOptions = const [];

  Stream<SocialRoomState> get roomStateStream => _roomStateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }

    final socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          // Let socket_io_client try polling first, then upgrade to websocket.
          // This avoids Engine.IO handshake issues in some environments.
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      final pendingJoinPayload = _pendingJoinPayload;
      if (pendingJoinPayload != null) {
        socket.emit('join_room', pendingJoinPayload);
      }
    });

    socket.on('room_state', (payload) {
      if (payload is Map) {
        _roomStateController.add(
          SocialRoomState.fromJson(
            Map<String, dynamic>.from(payload),
            _roomOptions,
          ),
        );
      }
    });

    socket.on('vote_updated', (payload) {
      if (payload is Map) {
        _roomStateController.add(
          SocialRoomState.fromJson(
            Map<String, dynamic>.from(payload),
            _roomOptions,
          ),
        );
      }
    });

    socket.on('socket_error', (payload) {
      _errorController.add(payload?.toString() ?? 'Socket error');
    });

    socket.onConnectError((error) {
      _errorController.add('Connection failed: $error');
    });

    socket.onError((error) {
      _errorController.add(error?.toString() ?? 'Unknown socket error');
    });

    socket.connect();
  }

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
    required List<ProductModel> options,
  }) async {
    _roomOptions = options;
    _pendingJoinPayload = {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
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
    required String userId,
    required String userName,
  }) {
    _socket?.emit('send_vote', {
      'roomId': roomId,
      'optionId': optionId,
      'userId': userId,
      'userName': userName,
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _roomStateController.close();
    _errorController.close();
  }
}
