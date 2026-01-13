import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/api_provider.dart';
import '../services/device_service.dart';
import '../state/session_provider.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String? exportUrl;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchExportUrl();
  }

  Future<void> _fetchExportUrl() async {
    final api = ref.read(apiClientProvider);
    final session = ref.read(sessionProvider);

    if (session == null) return;

    // Request export token - backend will use session's device_id
    final res = await api.post(
      "/export/token",
      body: {
        "session_id": session.id,
      },
    );

    if (res.ok) {
      setState(() {
        exportUrl = res.data["export_url"];
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Export"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          const Text(
            "Scan to Download",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          if (loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else if (exportUrl == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Failed to generate export link",
                style: TextStyle(color: Colors.redAccent),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: exportUrl!,
                size: 240,
              ),
            ),

          const SizedBox(height: 24),

          const Text(
            "Scan this QR code on your phone\nto download your video",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            "Link valid for 10 minutes",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    "/qr",
                    (route) => false,
                  );
                },
                child: const Text(
                  "End Session",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
