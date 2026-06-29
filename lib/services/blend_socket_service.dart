import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/blend_model.dart';
import '../models/group_message.dart';
import 'api_service.dart';

class BlendSocketService {
  BlendSocketService._();
  static final BlendSocketService instance = BlendSocketService._();
  factory BlendSocketService() => instance;

  String get _baseUrl => ApiService.socketBaseUrl;
  final _stateController = StreamController<BlendLiveState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  final _messageController = StreamController<GroupMessage>.broadcast();

  io.Socket? _socket;
  Map<String, dynamic>? _pendingJoin;

  Stream<BlendLiveState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<GroupMessage> get messageStream => _messageController.stream;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }

    // SECURITY: Pass Firebase ID token in the auth payload so the backend
    // can verify identity on connect. Without this, every socket event
    // would be unauthenticated.
    String? idToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        idToken = await user.getIdToken();
      }
    } catch (_) {
      // Best-effort — proceed without token, backend will refuse the connection.
    }

    final socket = io.io(
      _baseUrl,
      io.OptionBuilder().enableForceNew().disableAutoConnect().setAuth({
        'token': idToken,
      }).build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      final pending = _pendingJoin;
      if (pending != null) socket.emit('join_blend', pending);
    });

    socket.on('blend_state', (payload) {
      if (payload is Map) {
        _stateController.add(
          BlendLiveState.fromJson(Map<String, dynamic>.from(payload)),
        );
      }
    });

    socket.on('message_created', (payload) {
      if (payload is Map) {
        _messageController.add(
          GroupMessage.fromJson(Map<String, dynamic>.from(payload)),
        );
      }
    });

    socket.on('socket_error', (payload) {
      _errorController.add(payload?.toString() ?? 'Socket error');
    });

    socket.onConnectError((error) {
      _errorController.add('Connection failed: $error');
    });

    socket.connect();
  }

  Future<void> joinBlend({
    required String groupId,
    required String userId,
    required String userName,
  }) async {
    _pendingJoin = {'groupId': groupId, 'userId': userId, 'userName': userName};

    await connect();
    if (isConnected) _socket?.emit('join_blend', _pendingJoin);
  }

  void sendSwipe({
    required String groupId,
    required String productId,
    required String userId,
    required String userName,
    required SwipeType swipeType,
  }) {
    _socket?.emit('blend_swipe', {
      'groupId': groupId,
      'productId': productId,
      'userId': userId,
      'userName': userName,
      'swipeType': swipeTypeToApi(swipeType),
    });
  }

  void sendMessage({
    required String groupId,
    required String userId,
    required String userName,
    required String message,
    String? attachedProductId,
    String? attachedProductTitle,
    String? attachedProductImage,
    String? attachedProductPrice,
  }) {
    _socket?.emit('send_message', {
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'message': message,
      'attachedProductId': attachedProductId,
      'attachedProductTitle': attachedProductTitle,
      'attachedProductImage': attachedProductImage,
      'attachedProductPrice': attachedProductPrice,
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _errorController.close();
    _messageController.close();
  }
}
