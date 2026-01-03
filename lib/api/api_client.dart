// lib/api/api_client.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/env.dart';
import 'api_response.dart';

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,   // Example: http://192.168.1.5:8000/api
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        headers: {"Content-Type": "application/json"},
      ),
    );
  }

  // Basic GET wrapper
  Future<ApiResponse> get(String path) async {
    try {
      final r = await dio.get(path);
      return ApiResponse.success(r.data, r.statusCode ?? 200);
    } catch (e) {
      return ApiResponse.error("$e", 500);
    }
  }

  // Basic POST wrapper
  Future<ApiResponse> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final r = await dio.post(path, data: body ?? {});
      return ApiResponse.success(r.data, r.statusCode ?? 200);
    } catch (e) {
      return ApiResponse.error("$e", 500);
    }
  }

  // Update URL dynamically
  void updateBaseUrl(String url) {
    Env.updateBaseUrl(url);
    dio.options.baseUrl = url;
  }
}

// =============================================================
// EXTENSIONS MUST BE AT BOTTOM OF FILE, AFTER ApiClient CLASS!
// =============================================================

// ---------------------- Recording API ------------------------
extension RecordingApi on ApiClient {
  Future<ApiResponse> startRecording(String sessionId) async {
    return await post("/record/start", body: {"session_id": sessionId});
  }

  Future<ApiResponse> stopRecording(String sessionId, String filePath) async {
    try {
      final form = FormData.fromMap({
        "session_id": sessionId,
        "file": await MultipartFile.fromFile(
          filePath,
          filename: "recording_${DateTime.now().millisecondsSinceEpoch}.mp4",
        ),
      });

      final r = await dio.post("/record/stop", data: form);

      return ApiResponse.success(r.data, r.statusCode ?? 200);
    } catch (e) {
      return ApiResponse.error("$e", 500);
    }
  }
}


// ---------------------- Videos API ---------------------------
extension VideoApi on ApiClient {
  Future<ApiResponse> listVideos(String sessionId) async {
    return await get("/videos/list?session_id=$sessionId");
  }

  Future<ApiResponse> deleteVideo(String videoId) async {
    return await post("/videos/delete", body: {"id": videoId});
  }
}
