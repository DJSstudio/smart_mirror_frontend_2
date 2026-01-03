import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client_provider.dart';
import '../api/endpoints.dart';
import '../api/models/video.dart';

class VideoService {
  final Ref ref;
  VideoService(this.ref);

  Dio get dio => ref.read(apiClientProvider).dio;

  // Upload video file to Django backend
  Future<bool> uploadVideo(String sessionId, String filePath) async {
    try {
      final form = FormData.fromMap({
        "session_id": sessionId,
        "file": await MultipartFile.fromFile(filePath),
      });

      await dio.post(ApiEndpoints.videoUpload, data: form);
      return true;
    } catch (e) {
      print("Upload failed: $e");
      return false;
    }
  }

  // Fetch video list for a session
  Future<List<VideoModel>> fetchVideos(String sessionId) async {
    try {
      final res = await dio.get(
        ApiEndpoints.videoList,
        queryParameters: {"session_id": sessionId},
      );

      final List data = res.data;
      return data.map((v) => VideoModel.fromJson(v)).toList();
    } catch (e) {
      print("Failed to load videos: $e");
      return [];
    }
  }
}
