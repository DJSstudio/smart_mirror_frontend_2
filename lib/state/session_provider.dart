// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:http/http.dart' as http;
// import '../api/api_provider.dart';


// class MirrorSession {
//   final String id;
//   final String qrUrl;
//   final String qrStatus;

//   MirrorSession({
//     required this.id,
//     required this.qrUrl,
//     required this.qrStatus,
//   });

//   factory MirrorSession.fromJson(Map<String, dynamic> j) {
//     return MirrorSession(
//       id: j["session_id"] ?? j["id"],
//       qrUrl: j["qr_url"] ?? "",
//       qrStatus: j["qr_status"] ?? "pending",
//     );
//   }
// }


// class SessionNotifier extends StateNotifier<MirrorSession?> {
//   SessionNotifier() : super(null);

//   Timer? _pollTimer;

//   Future<void> startFreshQrSession() async {
//     _pollTimer?.cancel();
//     _pollTimer = null;
//     state = null;
//     await createQrSession();
//   }

//   Future<void> createQrSession() async {
//     final res = await http.post(
//       Uri.parse("http://192.168.1.8:8000/api/session/qr/create"),
//     );

//     final data = jsonDecode(res.body);
//     state = MirrorSession.fromJson(data);

//     _startPolling();
//   }

//   void _startPolling() {
//     _pollTimer?.cancel();

//     _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
//       if (state == null) return;
      
//       final res = await http.get(
//         Uri.parse(
//           "http://192.168.1.8:8000/api/session/qr/status?id=${state!.id}",
//         ),
//       );

//       final data = jsonDecode(res.body);
//       final updatedStatus = data["qr_status"];
//       final updatedSessionId = data["session_id"];

//       if (updatedStatus == "active") {
//         state = MirrorSession(
//           id: updatedSessionId,
//           qrUrl: state!.qrUrl,
//           qrStatus: "active",
//         );
//       }
//     });
//   }


//   @override
//   void dispose() {
//     _pollTimer?.cancel();
//     super.dispose();
//   }
// }

// final sessionProvider =
//     StateNotifierProvider<SessionNotifier, MirrorSession?>(
//   (ref) => SessionNotifier(),
// );



import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';

/// ----------------------------
/// MODEL
/// ----------------------------
class MirrorSession {
  final String id;
  final String qrUrl;
  final String qrStatus;

  MirrorSession({
    required this.id,
    required this.qrUrl,
    required this.qrStatus,
  });

  factory MirrorSession.fromJson(Map<String, dynamic> j) {
    return MirrorSession(
      id: j["session_id"] ?? j["id"],
      qrUrl: j["qr_url"] ?? "",
      qrStatus: j["qr_status"] ?? "pending",
    );
  }
}

/// ----------------------------
/// STATE NOTIFIER
/// ----------------------------
class SessionNotifier extends StateNotifier<MirrorSession?> {
  SessionNotifier(this.ref) : super(null);

  final Ref ref;
  Timer? _pollTimer;

  /// Start a brand-new QR session
  Future<void> startFreshQrSession() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    state = null;

    await _createQrSession();
  }

  /// Create QR session
  Future<void> _createQrSession() async {
    final api = ref.read(apiClientProvider);

    final res = await api.post("/session/qr/create");
    if (!res.ok) return;

    state = MirrorSession.fromJson(res.data);
    _startPolling();
  }

  /// Poll QR status
  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (state == null) return;

      final api = ref.read(apiClientProvider);
      final res =
          await api.get("/session/qr/status?id=${state!.id}");

      if (!res.ok) return;

      final updatedStatus = res.data["qr_status"];

      if (updatedStatus == "active") {
        timer.cancel();
        _pollTimer = null;

        state = MirrorSession(
          id: res.data["session_id"],
          qrUrl: state!.qrUrl,
          qrStatus: "active",
        );
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

/// ----------------------------
/// PROVIDER
/// ----------------------------
final sessionProvider =
    StateNotifierProvider<SessionNotifier, MirrorSession?>(
  (ref) => SessionNotifier(ref),
);
