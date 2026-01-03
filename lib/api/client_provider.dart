import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

// Global API client provider (Singleton)
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
