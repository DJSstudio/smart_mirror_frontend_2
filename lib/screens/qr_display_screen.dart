import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state/session_provider.dart';

class QRDisplayScreen extends ConsumerStatefulWidget {
  const QRDisplayScreen({super.key});

  @override
  ConsumerState<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends ConsumerState<QRDisplayScreen> {
  bool _started = false;
  bool _qrScannedThisRuntime = false; // 🔴 ADD THIS

  @override
  void initState() {
    super.initState();
    _qrScannedThisRuntime = false; // 🔴 ADD THIS

    // Start QR session ONCE
    Future.microtask(() {
      if (!_started) {
        _started = true;
        ref.read(sessionProvider.notifier).startFreshQrSession();
      }
    });
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
      _qrScannedThisRuntime = true; // 🔴 THIS IS THE KEY LINE
    }

    if (next.qrStatus == "active" && _qrScannedThisRuntime) {
      Navigator.pushReplacementNamed(context, "/menu");
    }
  });


    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: session == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text("Preparing QR...", style: TextStyle(color: Colors.white, fontSize: 20)),
                  SizedBox(height: 20),
                  CircularProgressIndicator(),
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
                ],
              ),
      ),
    );
  }
}
