import '../models/api_exception.dart';

String friendlyErrorMessage(dynamic error) {
  if (error is ApiException) return error.message;
  final message = error.toString();
  if (message.contains('SocketException') ||
      message.contains('HandshakeException')) {
    return 'Unable to connect. Please check your internet connection.';
  }
  if (message.contains('TimeoutException')) {
    return 'Request timed out. Please try again.';
  }
  if (message.contains('Unauthorized') ||
      message.contains('Forbidden') ||
      message.contains('401')) {
    return 'You are no longer signed in. Please sign in again.';
  }
  return 'Something went wrong. Please try again.';
}
