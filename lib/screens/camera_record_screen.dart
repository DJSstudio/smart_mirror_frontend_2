import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    setState(() => _statusText = buffer.toString());
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

    final recorder = ref.read(recordingProvider.notifier);
    _startStatusPolling();

    try {
      await RecordResumeService.markPending(_sessionId!);
      await recorder.start(_sessionId!);
      final path = await NativeAgent.captureUsbVideo(autoStart: true);

      if (path == null || path.isEmpty) {
        recorder.reset();
        setState(() => _errorText = "USB capture canceled.");
        return;
      }

      await recorder.stop(_sessionId!, path);
      if (!mounted) return;
      Navigator.pop(context);
    } on PlatformException catch (e) {
      final msg = "USB error: ${e.code}${e.message != null ? " - ${e.message}" : ""}";
      if (mounted) {
        setState(() => _errorText = msg);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      final msg = "USB error: $e";
      if (mounted) {
        setState(() => _errorText = msg);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      await RecordResumeService.clear();
      _stopStatusPolling();
      await _loadUsbStatus();
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
      onTap: _isCapturing ? null : _startUsbCapture,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusText(),
                const SizedBox(height: 24),
                _buildRecordButton(),
              ],
            ),
          ),
          _buildHeader(),
        ],
      ),
    );
  }
}
