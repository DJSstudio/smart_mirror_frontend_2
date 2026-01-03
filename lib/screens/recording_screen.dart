import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_state.dart';
import '../state/video_state.dart';
import '../state/native_agent_state.dart';
import '../native/native_agent.dart';

class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final lastPath = ref.watch(lastRecordedPathProvider);


    if (session == null) {
      return const Scaffold(
        body: Center(
          child: Text("No session active"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Recording")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: session == null ? null : () async {
                // generate filename
                final fname = "session_${session.id}_${DateTime.now().millisecondsSinceEpoch}.mp4";
                final ok = await NativeAgent.startRecording(filename: fname);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recording started")));
                }
              },
              child: const Text("Start Recording (Native)"),
            ),
            ElevatedButton(
              onPressed: session == null ? null : () async {
                final path = await NativeAgent.stopRecording();
                if (path != null) {
                  ref.read(lastRecordedPathProvider.notifier).state = path;
                  // Optionally upload automatically
                  final uploaded = await ref.read(videoProvider.notifier).upload(session.id, path);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uploaded ? "Uploaded" : "Upload failed")));
                }
              },
              child: const Text("Stop Recording & Upload"),
            ),
            ElevatedButton(
              onPressed: () async {
                final path = await NativeAgent.getLastRecorded();
                if (path != null) {
                  await NativeAgent.playOnMirror(path);
                }
              },
              child: const Text("Play Last Recorded on Mirror (Native)"),
            ),
            const SizedBox(height: 12),
            Text("Last recorded: ${lastPath ?? 'none'}"),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, "/gallery");
              },
              child: const Text("Open Gallery"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadButton(
      BuildContext context, WidgetRef ref, String sessionId) {
    return ElevatedButton(
      onPressed: () async {
        final result = await FilePicker.platform.pickFiles();

        if (result != null && result.files.single.path != null) {
          final path = result.files.single.path!;
          await ref.read(videoProvider.notifier).upload(sessionId, path);
        }
      },
      child: const Text("Upload Video"),
    );
  }

  Widget _loadVideosButton(
      BuildContext context, WidgetRef ref, String sessionId) {
    return ElevatedButton(
      onPressed: () async {
        await ref.read(videoProvider.notifier).load(sessionId);
        Navigator.pushNamed(context, "/gallery");
      },
      child: const Text("View Gallery"),
    );
  }
}
