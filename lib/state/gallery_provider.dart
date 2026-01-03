import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_provider.dart';

class MirrorVideo {
  final String id;
  final String url;
  final int size;

  MirrorVideo({
    required this.id,
    required this.url,
    required this.size,
  });

  // factory MirrorVideo.fromJson(Map<String, dynamic> j) {
  //   return MirrorVideo(
  //     id: j["id"],
  //     url: j["file"],     // full URL returned by Django
  //     size: j["size_bytes"] ?? 0,
  //   );
  // }
  factory MirrorVideo.fromJson(Map<String, dynamic> j) {
    final file = j["file"] as String;

    return MirrorVideo(
      id: j["id"],
      url: file.startsWith("http")
          ? file
          : "http://192.168.1.8:8000$file",
      size: j["size_bytes"] ?? 0,
    );
  }
}

class GalleryNotifier extends StateNotifier<List<MirrorVideo>> {
  final Ref ref;
  GalleryNotifier(this.ref) : super([]);

  Future<void> loadVideos(String sessionId) async {
    final api = ref.read(apiClientProvider);

    final res = await api.get("/videos/list?session_id=$sessionId");
    if (!res.ok) return;

    final list = (res.data as List)
        .map((v) => MirrorVideo.fromJson(v))
        .toList();

    state = list;
  }

  Future<void> deleteVideo(String id) async {
    final api = ref.read(apiClientProvider);
    final res = await api.post("/videos/delete", body: {"id": id});

    if (res.ok) {
      state = state.where((v) => v.id != id).toList();
    }
  }
}

final galleryProvider =
    StateNotifierProvider<GalleryNotifier, List<MirrorVideo>>(
  (ref) => GalleryNotifier(ref),
);
