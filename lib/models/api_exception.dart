class ApiException implements Exception {
  final int? statusCode; final String message; final dynamic details;
  const ApiException(this.message,{this.statusCode,this.details});
  @override String toString()=>message;
}