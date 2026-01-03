import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_provider.dart';
import '../api/api_client.dart';
import 'gallery_provider.dart';

enum RecordingState { idle, recording, processing }

class RecordingNotifier extends StateNotifier<RecordingState> {
  final Ref ref;

  RecordingNotifier(this.ref) : super(RecordingState.idle);

  Future<void> start(String sessionId) async {
    if (state != RecordingState.idle) return;

    state = RecordingState.recording;

    final api = ref.read(apiClientProvider);
    final res = await api.startRecording(sessionId);
    // final res = await api.startRecord(sessionId);


    if (!res.ok) {
      state = RecordingState.idle;
    }
  }

  /// <-- IMPORTANT: Provider does NOT access Camera
  /// Camera screen passes the recorded file path
  Future<void> stop(String sessionId, String filePath) async {
    if (state != RecordingState.recording &&
        state != RecordingState.processing) return;

    state = RecordingState.processing;

    final api = ref.read(apiClientProvider);
    final res = await api.stopRecording(sessionId!, filePath);
    // final res = await api.stopRecord(sessionId, filePath);

    state = RecordingState.idle;

    // refresh gallery
    ref.read(galleryProvider.notifier).loadVideos(sessionId);
  }
}

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>(
  (ref) => RecordingNotifier(ref),
);
