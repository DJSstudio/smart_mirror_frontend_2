import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state/session_state.dart';

class MirrorQRScreen extends ConsumerWidget {
  const MirrorQRScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Smart Mirror - Scan to Connect")),
      body: Center(
        child: session == null
            ? ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(sessionProvider.notifier)
                      .startSession({"source": "mirror"});
                },
                child: const Text("Generate Session + Show QR"),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Scan this QR with your phone"),
                  const SizedBox(height: 20),
                  QrImageView(
                    data: session!.id,
                    size: 250,
                  ),
                ],
              ),
      ),
    );
  }
}
