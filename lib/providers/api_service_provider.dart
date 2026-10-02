import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenzy/services/environment_config.dart';
import 'package:trenzy/services/mock_api_service.dart';
import '../services/api_service.dart';
import '../services/api_service_base.dart';

final apiServiceProvider = Provider.autoDispose<ApiServiceBase>((ref) {
  if (EnvConfig.useMockApi) {
    return MockApiService();
  }
  return ApiService(firebaseAuth: FirebaseAuth.instance);
});