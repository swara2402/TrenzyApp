import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/api_service.dart';

final apiServiceProvider = Provider.autoDispose<ApiService>((ref) {
  return ApiService(firebaseAuth: FirebaseAuth.instance);
});
