import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/session_provider.dart';
import '../native/native_agent.dart';
import '../utils/error_logger.dart';
import '../api/client_provider.dart';
import '../services/base_url_service.dart';
import '../services/session_transfer_service.dart';
import '../services/record_resume_service.dart';
import '../services/display_selection_service.dart';
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
  bool _selectingDisplay = false;

  Future<void> _showDisplayDebug() async {
    if (_debugOpen || !mounted) return;
    _debugOpen = true;
    try {
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
    } finally {
      _debugOpen = false;
    }
  }

  Future<void> _showMirrorDisplayPicker() async {
    if (_selectingDisplay || !mounted) return;
    _selectingDisplay = true;
    try {
      final info = await NativeAgent.getDisplayInfo();
      final currentId = info["currentDisplayId"] as int?;
      final preferred = await NativeAgent.getPreferredMirrorDisplay();
      final displays = (info["displays"] as List?) ?? [];
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Choose Mirror Display"),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: displays.map((d) {
                  final map = Map<String, dynamic>.from(d as Map);
                  final id = map["id"] as int?;
                  final w = map["width"] as int? ?? 0;
                  final h = map["height"] as int? ?? 0;
                  final isPresentation = map["isPresentation"] == true;
                  final isCurrent = id == currentId;
                  final isPreferred = id == preferred;
                  final name = map["name"]?.toString() ?? "Display";
                  final subtitle = "$name  ${w}x$h";

                  return ListTile(
                    dense: true,
                    enabled: isPresentation && !isCurrent,
                    title: Text("Display $id"),
                    subtitle: Text(
                      isCurrent
                          ? "$subtitle (App screen)"
                          : (isPresentation ? subtitle : "$subtitle (Not eligible)"),
                    ),
                    trailing: isPreferred
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: (!isPresentation || isCurrent || id == null)
                        ? null
                        : () async {
                            await NativeAgent.setPreferredMirrorDisplay(id);
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Mirror display set to id=$id"),
                              ),
                            );
                          },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    } finally {
      _selectingDisplay = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _qrScannedThisRuntime = false; // 🔴 ADD THIS
    Future.microtask(() async {
      await NativeAgent.showMirrorIdle();
      await DisplaySelectionService.forceMirrorToLargestExternal();
    });
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

    final titleStyle = GoogleFonts.playfairDisplay(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF6B6661),
    );
    final bodyStyle = GoogleFonts.workSans(
      fontSize: 14,
      color: const Color(0xFF8C8681),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2ECE7),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final cardWidth = (maxWidth * 0.9).clamp(360.0, 900.0);
            return Center(
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Text(
                    "Scan to Start Session",
                    style: titleStyle,
                  ),
                  TextButton.icon(
                    onPressed: _showMirrorDisplayPicker,
                    icon: const Icon(Icons.monitor, size: 16, color: Color(0xFF8C8681)),
                    label: Text(
                      "Mirror Screen",
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        color: const Color(0xFF8C8681),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: cardWidth,
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F2EE),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white70),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: session == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Preparing QR...", style: titleStyle),
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
                                    const CircularProgressIndicator(
                                      color: Color(0xFFB9B1AA),
                                    ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: _startSessionWithDiscovery,
                                    child: Text("Retry", style: bodyStyle),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pushNamed(context, "/continue_session"),
                                    child: Text(
                                      "Continue Existing Session",
                                      style: bodyStyle,
                                    ),
                                  ),
                                  if (debugText != null) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        "Discovery Debug:\n$debugText",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.workSans(
                                          fontSize: 11,
                                          color: const Color(0xFF9D948E),
                                        ),
                                      ),
                                    ),
                                  ],
                                  TextButton(
                                    onPressed: _showDisplayDebug,
                                    child: Text(
                                      "Display Debug",
                                      style: GoogleFonts.workSans(
                                        fontSize: 12,
                                        color: const Color(0xFF9D948E),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
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
                                    style: bodyStyle,
                                  ),
                                  const SizedBox(height: 20),
                                  if (session.qrStatus == "pending")
                                    const CircularProgressIndicator(
                                      color: Color(0xFFB9B1AA),
                                    ),
                                  const SizedBox(height: 20),
                                  TextButton(
                                    onPressed: _showDisplayDebug,
                                    child: Text(
                                      "Display Debug",
                                      style: GoogleFonts.workSans(
                                        fontSize: 12,
                                        color: const Color(0xFF9D948E),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pushNamed(context, "/continue_session"),
                                    child: Text(
                                      "Continue Existing Session",
                                      style: bodyStyle,
                                    ),
                                  ),
                                  if (debugText != null) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        "Discovery Debug:\n$debugText",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.workSans(
                                          fontSize: 11,
                                          color: const Color(0xFF9D948E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
