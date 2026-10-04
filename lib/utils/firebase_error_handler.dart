import '../models/api_exception.dart';

/// Converts any error into a user-friendly message suitable for display.
///
/// Handles:
/// - [FirebaseAuthException] — maps `.code` to a friendly message
/// - [ApiException] — returns `.message` directly
/// - Other exceptions — generic fallback message
String friendlyFirebaseError(Object error) {
  // Try pattern matching first (works with any error type)
  final errorStr = error is ApiException ? error.message : error.toString();
  final lowerError = errorStr.toLowerCase();

  // Firebase error codes to user-friendly messages
  // Order matters: more specific patterns should come first
  const errorMessages = <String, String>{
    // ── Signup errors ────────────────────────────────────────────────
    'email-already-in-use': 'This email is already registered. Try logging in instead.',
    'invalid-email': 'Please enter a valid email address.',
    'operation-not-allowed': 'Email/password sign up is currently disabled. Please contact support.',
    'weak-password': 'Password is too weak. Please use at least 6 characters.',

    // ── Login errors ─────────────────────────────────────────────────
    'user-not-found': 'No account found with this email.',
    'wrong-password': 'Incorrect email or password.',
    'invalid-credential': 'Incorrect email or password.',
    'invalid-login-credentials': 'Incorrect email or password.',
    'user-disabled': 'This account has been disabled. Please contact support.',
    'too-many-requests': 'Too many attempts. Please wait a moment and try again.',
    'rate-limit': 'Too many attempts. Please wait a moment and try again.',

    // ── Token / session errors ───────────────────────────────────────
    'user-token-expired': 'Your session has expired. Please sign in again.',
    'invalid-user-token': 'Your session is invalid. Please sign in again.',
    'requires-recent-login': 'This action requires recent authentication. Please sign in again.',

    // ── Network errors ───────────────────────────────────────────────
    'network-request-failed': 'Connection issue. Please check your internet and try again.',

    // ── reCAPTCHA / web auth errors ─────────────────────────────────
    'captcha-check-failed': 'Verification failed. Please try again.',
    'invalid-recaptcha-token': 'Verification failed. Please try again.',
    'recaptcha-not-verified': 'Verification failed. Please try again.',
    'missing-recaptcha-token': 'Verification failed. Please try again.',
    'quota-exceeded': 'Too many attempts. Please wait and try again later.',

    // ── API key / project errors ────────────────────────────────────
    'api-key-not-valid': 'Authentication is temporarily unavailable. Please try again later or contact support.',
    'invalid-api-key': 'Authentication is temporarily unavailable. Please try again later or contact support.',
    'admin-restricted-operation': 'This operation is not allowed. Please contact support.',
    'invalid-argument': 'The request was rejected. Please check your details and try again.',
    'internal-error': 'Something went wrong on our end. Please try again.',
  };

  // Check against known Firebase error codes in the error string
  for (final entry in errorMessages.entries) {
    if (lowerError.contains(entry.key)) {
      return entry.value;
    }
  }

  // Try to extract the error code from Firebase error response JSON patterns
  // e.g., {"error": {"message": "EMAIL_EXISTS"}}
  final emailExistsMatch = RegExp(r'email[_\- ]exists', caseSensitive: false).firstMatch(lowerError);
  if (emailExistsMatch != null) {
    return 'This email is already registered. Try logging in instead.';
  }

  final weakPasswordMatch = RegExp(r'weak[_\- ]password', caseSensitive: false).firstMatch(lowerError);
  if (weakPasswordMatch != null) {
    return 'Password is too weak. Please use at least 6 characters.';
  }

  final operationNotAllowedMatch = RegExp(r'operation[_\- ]not[_\- ]allowed', caseSensitive: false).firstMatch(lowerError);
  if (operationNotAllowedMatch != null) {
    return 'Email/password sign up is currently disabled. Please contact support.';
  }

  // Raw Firebase web messages, e.g. "API key is not valid. Please pass a valid API key."
  final apiKeyInvalidMatch = RegExp(r'api key is not valid|api key invalid', caseSensitive: false).firstMatch(lowerError);
  if (apiKeyInvalidMatch != null) {
    return 'Authentication is temporarily unavailable. Please try again later or contact support.';
  }

  // Network/connection errors
  if (lowerError.contains('network') || lowerError.contains('socket')) {
    return 'Connection issue. Please check your internet and try again.';
  }
  if (lowerError.contains('timeout')) {
    return 'Request timed out. Please check your connection.';
  }

  // Rate limiting
  if (lowerError.contains('too-many') || lowerError.contains('rate limit')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  return 'Something went wrong. Please try again.';
}

/// Returns true if the error is a network/connection related error.
bool isNetworkError(Object error) {
  final errorStr = error.toString().toLowerCase();
  return errorStr.contains('network') ||
      errorStr.contains('socket') ||
      errorStr.contains('timeout') ||
      errorStr.contains('connection refused');
}
