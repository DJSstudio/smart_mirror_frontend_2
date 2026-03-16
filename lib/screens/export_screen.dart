import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 4, 26, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B6661)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Export",
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B6661),
                          ),
                        ),
                      ],
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Scan to Download",
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B6661),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (loading)
                              const Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  color: Color(0xFFB9B1AA),
                                ),
                              )
                            else if (exportUrl == null)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  "Failed to generate export link",
                                  style: GoogleFonts.workSans(
                                    color: Colors.redAccent,
                                    fontSize: 14,
                                  ),
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
                            const SizedBox(height: 20),
                            Text(
                              "Scan this QR code on your phone\nto download your video",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.workSans(
                                color: const Color(0xFF8C8681),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Link valid for 10 minutes",
                              style: GoogleFonts.workSans(
                                color: const Color(0xFF9D948E),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEADFD8),
                          foregroundColor: const Color(0xFF6B6661),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: Color(0xFFE4DDD7)),
                          ),
                          elevation: 6,
                          shadowColor: Colors.black.withOpacity(0.12),
                        ),
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            "/qr",
                            (route) => false,
                          );
                        },
                        child: Text(
                          "End Session",
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
