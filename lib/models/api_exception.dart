class ApiException implements Exception {
  const ApiException(this.message, {this.details, this.statusCode});

  final String message;
  final Object? details;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message';
}
