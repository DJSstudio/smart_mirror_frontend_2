import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

import '../native/native_agent.dart';
import '../state/recording_provider.dart';
import '../state/session_provider.dart';
import '../services/record_resume_service.dart';

class CameraRecordScreen extends ConsumerStatefulWidget {
  const CameraRecordScreen({super.key});

  @override
  ConsumerState<CameraRecordScreen> createState() =>
      _CameraRecordScreenState();
}

class _CameraRecordScreenState extends ConsumerState<CameraRecordScreen>
    with WidgetsBindingObserver {
  String? _sessionId;
  bool _isCapturing = false;
  bool _usbChecked = false;
  bool? _usbDetected;
  String? _statusText;
  String? _errorText;
  Timer? _statusTimer;
  String? _previewPath;
  VideoPlayerController? _previewController;
  bool _saving = false;
  final List<String> _failureLogs = [];
  List<String> _nativeLogs = const [];
  String? _lastStatusSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionId = ref.read(sessionProvider)?.id;
    Future.microtask(() async {
      await _checkUsbCamera();
      await _loadUsbStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _previewController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUsbStatus();
    }
  }

  Future<void> _checkUsbCamera() async {
    if (!Platform.isAndroid) {
      if (!mounted) return;
      setState(() {
        _usbChecked = true;
        _usbDetected = false;
        _errorText = "USB camera capture is Android-only.";
      });
      return;
    }

    try {
      final detected = await NativeAgent.hasExternalCamera();
      if (!mounted) return;
      setState(() {
        _usbChecked = true;
        _usbDetected = detected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usbChecked = true;
        _usbDetected = null;
        _errorText = "USB camera check failed: $e";
      });
    }
  }

  Future<void> _loadUsbStatus() async {
    final status = await NativeAgent.getLastUsbCaptureStatus();
    if (!mounted) return;
    final rawStatus = status["status"]?.toString();
    final error = status["error"]?.toString();
    final path = status["path"]?.toString();
    final timeMs = status["time_ms"] is int ? status["time_ms"] as int : 0;
    final time = timeMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(timeMs)
        : null;

    if (rawStatus == null && error == null && path == null) {
      setState(() => _statusText = null);
      return;
    }

    final signature = "$rawStatus|$error|$path|$timeMs";
    final buffer = StringBuffer("USB status: $rawStatus");
    if (error != null && error.isNotEmpty) {
      buffer.write(" ($error)");
    }
    if (path != null && path.isNotEmpty) {
      buffer.write("\n$path");
    }
    if (time != null) {
      buffer.write(" @ ${time.toIso8601String()}");
    }
    if (_lastStatusSignature != signature) {
      _lastStatusSignature = signature;
      _appendLog(buffer.toString());
    }

    final logs = await NativeAgent.getUsbCaptureLogs();
    final parsedLogs = logs
        .map(_formatNativeLogLine)
        .where((e) => e.isNotEmpty)
        .toList();
    if (!mounted) return;
    setState(() {
      _statusText = buffer.toString();
      _nativeLogs = parsedLogs;
    });
  }

  String _formatNativeLogLine(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "";
    final parts = trimmed.split(" | ");
    if (parts.isEmpty) return trimmed;
    final ts = int.tryParse(parts.first);
    if (ts == null) return trimmed;
    final at = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
    if (parts.length == 1) return at;
    return "$at | ${parts.sublist(1).join(" | ")}";
  }

  void _appendLog(String line) {
    final ts = DateTime.now().toIso8601String();
    _failureLogs.add("[$ts] $line");
    if (_failureLogs.length > 40) {
      _failureLogs.removeAt(0);
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _loadUsbStatus();
    });
  }

  void _stopStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> _startUsbCapture() async {
    if (_isCapturing) return;
    if (_previewPath != null) return;
    if (_sessionId == null || _sessionId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No active session.")),
        );
      }
      return;
    }

    setState(() {
      _isCapturing = true;
      _errorText = null;
    });
    _appendLog("capture_requested");
    await NativeAgent.clearLastUsbCaptureStatus();
    _lastStatusSignature = null;
    if (mounted) {
      setState(() {
        _nativeLogs = const [];
      });
    }

    final recorder = ref.read(recordingProvider.notifier);
    _startStatusPolling();

    try {
      await RecordResumeService.markPending(_sessionId!);
      await recorder.start(_sessionId!);
      final path = await NativeAgent.captureUsbVideo(autoStart: true);

      if (path == null || path.isEmpty) {
        recorder.reset();
        _appendLog("capture_canceled");
        setState(() => _errorText = "USB capture canceled.");
        return;
      }

      await _showPreview(path);
    } on PlatformException catch (e) {
      final msg = "USB error: ${e.code}${e.message != null ? " - ${e.message}" : ""}";
      _appendLog(msg);
      if (mounted) {
        setState(() => _errorText = msg);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      final msg = "USB error: $e";
      _appendLog(msg);
      if (mounted) {
        setState(() => _errorText = msg);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      await RecordResumeService.clear();
      _stopStatusPolling();
      await _loadUsbStatus();
      await NativeAgent.showMirrorIdle();
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _showPreview(String path) async {
    await _previewController?.dispose();
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _previewController = controller;
      _previewPath = path;
    });
  }

  Future<void> _discardPreview() async {
    final path = _previewPath;
    await _previewController?.dispose();
    _previewController = null;
    _previewPath = null;
    _errorText = null;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _savePreview() async {
    if (_saving) return;
    final path = _previewPath;
    if (_sessionId == null || _sessionId!.isEmpty || path == null) {
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    final recorder = ref.read(recordingProvider.notifier);
    try {
      await recorder.stop(_sessionId!, path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video saved.")),
      );
      await _discardPreview();
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = "Failed to save video: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _guideOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GuideLinesPainter(
          verticalFracs: const [0.25, 0.75],
          horizontalFracs: const [0.15, 0.85],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    final lines = <Widget>[];

    if (_usbChecked) {
      final label = _usbDetected == true
          ? "USB camera detected"
          : (_usbDetected == false
              ? "USB camera not detected"
              : "USB camera check failed");
      lines.add(Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ));
    } else {
      lines.add(const CircularProgressIndicator(color: Colors.white));
      lines.add(const SizedBox(height: 8));
      lines.add(const Text(
        "Checking USB camera...",
        style: TextStyle(color: Colors.white70),
      ));
    }

    if (_statusText != null) {
      lines.add(const SizedBox(height: 8));
      lines.add(Text(
        _statusText!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ));
    }

    if (_errorText != null) {
      lines.add(const SizedBox(height: 8));
      lines.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          _errorText!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ));
      if (_failureLogs.isNotEmpty) {
        lines.add(const SizedBox(height: 10));
        lines.add(Container(
          width: 520,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Failure Log",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                _failureLogs.reversed.take(12).toList().reversed.join("\n"),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ));
      }

      if (_nativeLogs.isNotEmpty) {
        lines.add(const SizedBox(height: 10));
        lines.add(Container(
          width: 760,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              _nativeLogs.reversed.take(28).toList().reversed.join("\n"),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ),
        ));
      }
    }

    if (_isCapturing) {
      lines.add(const SizedBox(height: 16));
      lines.add(const CircularProgressIndicator(color: Colors.white));
      lines.add(const SizedBox(height: 8));
      lines.add(const Text(
        "Opening USB camera...",
        style: TextStyle(color: Colors.white54),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: lines,
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _isCapturing || _previewPath != null ? null : _startUsbCapture,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isCapturing ? Colors.white54 : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 3,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _previewController;
    if (_previewPath == null || controller == null) {
      return const SizedBox.shrink();
    }

    final video = controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          )
        : const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 420,
            height: 240,
            child: Center(child: video),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _saving ? null : _discardPreview,
              child: const Text("Record Again"),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _saving ? null : _savePreview,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Save Video"),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2ECE7),
      body: SafeArea(
        top: false,
        child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF2ECE7),
                  Color(0xFFE6DED8),
                  Color(0xFFF4EEEA),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Record Your Look",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B6661),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusText(),
                const SizedBox(height: 24),
                if (_previewPath == null) _buildRecordButton(),
                if (_previewPath != null) _buildPreview(),
              ],
            ),
          ),
          _guideOverlay(),
          _buildHeader(),
        ],
      ),
      ),
    );
  }
}

class _GuideLinesPainter extends CustomPainter {
  final List<double> verticalFracs;
  final List<double> horizontalFracs;

  _GuideLinesPainter({
    required this.verticalFracs,
    required this.horizontalFracs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dash = 10.0;
    const gap = 8.0;

    for (final frac in verticalFracs) {
      final x = size.width * frac;
      double y = 0;
      while (y < size.height) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dash), paint);
        y += dash + gap;
      }
    }

    for (final frac in horizontalFracs) {
      final y = size.height * frac;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
        x += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
