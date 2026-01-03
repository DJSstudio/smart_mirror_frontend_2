import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/models/session.dart';
import '../services/session_service.dart';

class SessionNotifier extends StateNotifier<SessionModel?> {
  final Ref ref;

  SessionNotifier(this.ref) : super(null);

  // Start new session
  Future<bool> startSession(Map<String, dynamic> meta) async {
    final service = SessionService(ref);
    final session = await service.startSession(meta);

    if (session != null) {
      state = session;
      return true;
    }
    return false;
  }

  // End session
  Future<void> endSession() async {
    if (state == null) return;

    final service = SessionService(ref);
    await service.endSession(state!.id);

    state = null;
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionModel?>(
  (ref) => SessionNotifier(ref),
);
