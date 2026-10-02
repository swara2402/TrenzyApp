import 'api_client.dart';

class PaymentApi {
  PaymentApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> createPaymentOrder({
    required int amountPaise,
  }) async {
    final data = await _client.post('/payments/order', body: {
      'amount_paise': amountPaise,
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final data = await _client.post('/payments/verify', body: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getPaymentOrderStatus({
    required String razorpayOrderId,
  }) async {
    final data = await _client.get('/payments/order/$razorpayOrderId');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }
}
