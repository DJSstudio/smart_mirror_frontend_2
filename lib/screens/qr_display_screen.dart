import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state/session_provider.dart';
import '../native/native_agent.dart';
import '../utils/error_logger.dart';
import '../api/client_provider.dart';
import '../services/base_url_service.dart';
import '../services/session_transfer_service.dart';
import '../services/record_resume_service.dart';
import '../state/peers_state.dart';
import '../peers/peer_model.dart';

class QRDisplayScreen extends ConsumerStatefulWidget {
  const QRDisplayScreen({super.key});

  @override
  ConsumerState<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends ConsumerState<QRDisplayScreen> {
  bool _started = false;
  bool _qrScannedThisRuntime = false; // 🔴 ADD THIS
  bool _debugOpen = false;
  bool _crashShown = false;
  bool _flutterErrorShown = false;
  bool _discovering = false;
  String? _discoveryError;
  String? _discoveryDebug;
  bool _handlingActivation = false;

  Future<void> _showDisplayDebug() async {
    if (_debugOpen || !mounted) return;
    _debugOpen = true;
    final info = await NativeAgent.getDisplayInfo();
    if (!mounted) return;
    final displays = (info["displays"] as List?) ?? [];
    final currentId = info["currentDisplayId"];
    final presentationIds = (info["presentationIds"] as List?) ?? [];
    final lines = displays.map((d) {
      final map = Map<String, dynamic>.from(d as Map);
      final id = map["id"];
      final name = map["name"];
      final state = map["state"];
      final flags = map["flags"];
      final isPresentation = map["isPresentation"] == true ? " presentation" : "";
      final isDefault = map["isDefault"] == true ? " default" : "";
      return "id=$id$isDefault$isPresentation state=$state flags=$flags\n$name";
    }).join("\n\n");

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Display Debug"),
        content: SingleChildScrollView(
          child: Text(
            "currentDisplayId=$currentId\npresentationIds=$presentationIds\n\n$lines",
          ),
        ),
      ),
    );
    _debugOpen = false;
  }

  @override
  void initState() {
    super.initState();
    _qrScannedThisRuntime = false; // 🔴 ADD THIS
    Future.microtask(() async {
      if (_crashShown) return;
      final crash = await NativeAgent.getLastCrash();
      if (!mounted || crash == null || crash.isEmpty) return;
      _crashShown = true;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Last Crash"),
          content: SingleChildScrollView(
            child: Text(crash),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await NativeAgent.clearLastCrash();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Clear"),
            ),
          ],
        ),
      );
    });
    Future.microtask(() async {
      if (_flutterErrorShown) return;
      final crash = await ErrorLogger.get();
      if (!mounted || crash == null || crash.isEmpty) return;
      _flutterErrorShown = true;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Last Flutter Error"),
          content: SingleChildScrollView(
            child: Text(crash),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ErrorLogger.clear();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Clear"),
            ),
          ],
        ),
      );
    });

    // Start QR session ONCE (after base URL discovery)
    Future.microtask(() async {
      if (_started) return;
      _started = true;
      final pendingSession =
          await RecordResumeService.consumePending();
      if (pendingSession != null && pendingSession.isNotEmpty) {
        ref.read(sessionProvider.notifier).setActiveSession(pendingSession);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/record");
        return;
      }
      await _startSessionWithDiscovery();
    });
  }

  Future<void> _startSessionWithDiscovery() async {
    if (_discovering) return;
    setState(() {
      _discovering = true;
      _discoveryError = null;
      _discoveryDebug = null;
    });
    final apiClient = ref.read(apiClientProvider);
    BaseUrlService.clearLastDatagramDebug();
    final ok = await BaseUrlService.bootstrap(apiClient);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _discovering = false;
        _discoveryError = "No mirror found on LAN. Check Wi-Fi and backend.";
        _discoveryDebug = BaseUrlService.lastDatagramDebug();
      });
      return;
    }
    await ref.read(sessionProvider.notifier).startFreshQrSession();
    if (!mounted) return;
    setState(() {
      _discovering = false;
    });
  }

  Future<void> _handleActivatedSession(String sessionId) async {
    if (_handlingActivation) return;
    _handlingActivation = true;
    final transferred = await _attemptAutoTransfer(sessionId);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/menu");
    if (!transferred) {
      _handlingActivation = false;
    }
  }

  Future<bool> _attemptAutoTransfer(String newSessionId) async {
    final peers = await _waitForPeers(const Duration(seconds: 8));
    if (peers.isEmpty) {
      return false;
    }

    final apiClient = ref.read(apiClientProvider);
    final transferService = SessionTransferService(apiClient);
    final localSession = await transferService.getLocalActiveSession();
    final userId = localSession?["user_id"]?.toString() ??
        localSession?["device_id"]?.toString();
    if (userId == null || userId.isEmpty) {
      return false;
    }

    final entries = await transferService.fetchRemoteSessions(peers);
    final match = entries.where((e) {
      final remoteUserId = e.session["user_id"]?.toString() ??
          e.session["device_id"]?.toString();
      return remoteUserId == userId;
    }).toList();
    if (match.isEmpty) {
      return false;
    }

    final entry = match.first;
    String status = "Starting transfer...";
    StateSetter? setDialogState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            setDialogState = setStateDialog;
            return AlertDialog(
              title: const Text("Continuing Session"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(status, textAlign: TextAlign.center),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final transferredSessionId = await transferService.transferSession(
        entry,
        onStatus: (msg) {
          status = msg;
          if (setDialogState != null) {
            setDialogState!(() {});
          }
        },
      );

      if (!mounted) return true;
      Navigator.pop(context);

      if (transferredSessionId != newSessionId) {
        await apiClient.post("/session/end", body: {
          "session_id": newSessionId,
        });
      }

      ref.read(sessionProvider.notifier).setActiveSession(transferredSessionId);
      return true;
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Auto-transfer failed, continuing here. ($e)"),
          ),
        );
      }
      return false;
    }
  }

  Future<List<Peer>> _waitForPeers(Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final peers = ref.read(peersListProvider).asData?.value ?? const <Peer>[];
      if (peers.isNotEmpty) {
        return peers;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return const <Peer>[];
  }

  @override
  Widget build(BuildContext context) {
    // LISTEN HERE — this is the correct place
    // ref.listen(sessionProvider, (prev, next) {
    //   if (next != null && next.qrStatus == "active") {
    //     Navigator.pushReplacementNamed(context, "/menu");
    //   }
    // });

    ref.listen(sessionProvider, (prev, next) {
      if (next == null) return;

      // Detect QR scan transition
      if (prev != null &&
          prev.qrStatus == "pending" &&
          next.qrStatus == "active") {
        _qrScannedThisRuntime = true;
      }

      if (next.qrStatus == "active" && _qrScannedThisRuntime) {
        Future.microtask(() => _handleActivatedSession(next.id));
      }
    });


    final session = ref.watch(sessionProvider);
    final sessionError = ref.watch(sessionErrorProvider);
    final debugText = _discoveryDebug ?? BaseUrlService.lastDatagramDebug();
    ref.watch(peersListProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: session == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Preparing QR...",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  if (_discoveryError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _discoveryError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  else if (sessionError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        sessionError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  else
                    const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _startSessionWithDiscovery,
                    child: const Text(
                      "Retry",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, "/continue_session"),
                    child: const Text(
                      "Continue Existing Session",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (debugText != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "Discovery Debug:\n$debugText",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                  TextButton(
                    onPressed: _showDisplayDebug,
                    child: const Text(
                      "Display Debug",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Scan to Start Session",
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 20),

                  // --- QR CODE ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: session.qrUrl,
                      size: 260,
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    session.qrStatus == "pending"
                        ? "Waiting for your phone to scan..."
                        : "Activated!",
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),

                  const SizedBox(height: 20),
                  if (session.qrStatus == "pending")
                    const CircularProgressIndicator(),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _showDisplayDebug,
                    child: const Text(
                      "Display Debug",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, "/continue_session"),
                    child: const Text(
                      "Continue Existing Session",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (debugText != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "Discovery Debug:\n$debugText",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
          ),
        ),
      ),
    );
  }
}
