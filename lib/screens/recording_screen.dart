import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/session_state.dart';
import '../state/video_state.dart';
import '../state/native_agent_state.dart';
import '../native/native_agent.dart';
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isRecording = false;
  DateTime? _startTime;
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  Timer? _countdownTimer;
  int? _countdown;

  @override
  void initState() {
    super.initState();
    // listen to native events to reflect recording state even if started externally
    _eventSub = NativeAgent.events().listen((evt) {
      // debug: surface native events in logs
      // ignore: avoid_print
      print('NativeAgent.event => $evt');
      final ev = evt['event']?.toString() ?? '';
      if (ev == 'recording_started') {
        // native may send a start timestamp in ms or unix
        DateTime now = DateTime.now();
        if (evt.containsKey('start_ms')) {
          final ms = (evt['start_ms'] as num).toInt();
          _startTime = DateTime.fromMillisecondsSinceEpoch(ms);
        } else if (evt.containsKey('start_unix')) {
          final s = (evt['start_unix'] as num).toInt();
          _startTime = DateTime.fromMillisecondsSinceEpoch(s * 1000);
        } else {
          _startTime = now;
        }
        setState(() => _isRecording = true);
        _startTimer();
        ScaffoldMessenger.maybeOf(ref.context)?.showSnackBar(const SnackBar(content: Text('Native recording started')));
      } else if (ev == 'recording_stopped') {
        _stopTimer();
        setState(() {
          _isRecording = false;
          _elapsed = Duration.zero;
          _startTime = null;
        });
        ScaffoldMessenger.maybeOf(ref.context)?.showSnackBar(const SnackBar(content: Text('Native recording stopped')));
        if (evt.containsKey('path')) {
          final p = evt['path']?.toString();
          if (p != null) {
            ref.read(lastRecordedPathProvider.notifier).state = p;
          }
        }
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    // initialize elapsed based on startTime if available
    setState(() {
      if (_startTime != null) {
        _elapsed = DateTime.now().difference(_startTime!);
      } else {
        _elapsed = Duration.zero;
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_startTime != null) {
          _elapsed = DateTime.now().difference(_startTime!);
        } else {
          _elapsed += const Duration(seconds: 1);
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    _eventSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() => _countdown = null);
  }

  void _beginCountdown(String fname) {
    // start a 3..1 countdown, then start recording
    if (_countdownTimer != null) return;
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final next = (_countdown ?? 0) - 1;
      if (next <= 0) {
        t.cancel();
        _countdownTimer = null;
        setState(() => _countdown = null);
        await _doStartRecording(fname);
      } else {
        setState(() => _countdown = next);
      }
    });
  }

  Future<void> _doStartRecording(String fname) async {
    final ok = await NativeAgent.startRecording(filename: fname);
    if (ok) {
      setState(() {
        _isRecording = true;
        _startTime = DateTime.now();
      });
      _startTimer();
      ScaffoldMessenger.maybeOf(ref.context)?.showSnackBar(const SnackBar(content: Text("Recording started")));
    } else {
      ScaffoldMessenger.maybeOf(ref.context)?.showSnackBar(const SnackBar(content: Text("Failed to start recording")));
    }
  }

  String _formatElapsed(Duration d) => d.inSeconds.toString();

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        title: Text(_isRecording ? 'Recording • ${_formatElapsed(_elapsed)} s' : 'Recording'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: (session == null || _isRecording || _countdown != null)
                      ? null
                      : () {
                          // start countdown then record
                          final fname = "session_${session.id}_${DateTime.now().millisecondsSinceEpoch}.mp4";
                          _beginCountdown(fname);
                        },
                  child: const Text("Start Recording (Native)"),
                ),

                const SizedBox(height: 8),

                ElevatedButton(
                  onPressed: session == null
                      ? null
                      : () async {
                          final path = await NativeAgent.stopRecording();
                          // stop timer regardless
                          _stopTimer();
                          setState(() {
                            _isRecording = false;
                            _startTime = null;
                            _elapsed = Duration.zero;
                          });

                          if (path != null) {
                            ref.read(lastRecordedPathProvider.notifier).state = path;
                            // Optionally upload automatically
                            final uploaded = await ref.read(videoProvider.notifier).upload(session.id, path);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uploaded ? "Uploaded" : "Upload failed")));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No file saved")));
                          }
                        },
                  child: const Text("Stop Recording & Upload"),
                ),

                const SizedBox(height: 8),

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

                // Live elapsed time display
                if (_countdown != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      '${_countdown}',
                      style: const TextStyle(fontSize: 64, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Recording: ${_formatElapsed(_elapsed)} s',
                      style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                    ),
                  ),

                const SizedBox(height: 8),
                Text("Last recorded: ${lastPath ?? 'none'}"),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, "/gallery", arguments: {"session_id": session.id});
                  },
                  child: const Text("Open Gallery"),
                ),
              ],
            ),
          ),
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
        Navigator.pushNamed(context, "/gallery", arguments: {"session_id": sessionId});
      },
      child: const Text("View Gallery"),
    );
  }
}
