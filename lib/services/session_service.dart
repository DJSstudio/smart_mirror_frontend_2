import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client_provider.dart';
import '../api/endpoints.dart';
import '../api/models/session.dart';

class SessionService {
  final Ref ref;
  SessionService(this.ref);

  Dio get dio => ref.read(apiClientProvider).dio;

  Future<SessionModel?> startSession(Map<String, dynamic> meta) async {
    try {
      final response = await dio.post(
        ApiEndpoints.sessionStart,
        data: jsonEncode({
          "user_meta": meta,
          "expiry_seconds": 3600,
        }),
      );

      return SessionModel.fromJson(response.data);
    } catch (err) {
      print("Session start failed: $err");
      return null;
    }
  }

  Future<bool> endSession(String sessionId) async {
    try {
      await dio.post(
        ApiEndpoints.sessionEnd,
        data: {"session_id": sessionId},
      );
      return true;
    } catch (err) {
      print("Session end failed: $err");
      return false;
    }
  }
}
