import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/models/video.dart';
import '../services/video_service.dart';

class VideoNotifier extends StateNotifier<AsyncValue<List<VideoModel>>> {
  final Ref ref;

  VideoNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> load(String sessionId) async {
    state = const AsyncValue.loading();

    final service = VideoService(ref);
    final videos = await service.fetchVideos(sessionId);

    state = AsyncValue.data(videos);
  }

  Future<bool> upload(String sessionId, String path) async {
    final service = VideoService(ref);
    final ok = await service.uploadVideo(sessionId, path);

    if (ok) await load(sessionId); // refresh list
    return ok;
  }
}

final videoProvider =
    StateNotifierProvider<VideoNotifier, AsyncValue<List<VideoModel>>>(
  (ref) => VideoNotifier(ref),
);
