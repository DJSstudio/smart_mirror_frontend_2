import 'package:shared_preferences/shared_preferences.dart';

class RecordResumeService {
  static const _sessionKey = "resume_record_session";
  static const _timeKey = "resume_record_time_ms";

  static Future<void> markPending(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, sessionId);
    await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<String?> consumePending({Duration maxAge = const Duration(minutes: 3)}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_sessionKey);
    final ts = prefs.getInt(_timeKey);
    if (sessionId == null || sessionId.isEmpty || ts == null) {
      return null;
    }
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > maxAge.inMilliseconds) {
      await clear();
      return null;
    }
    await clear();
    return sessionId;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_timeKey);
  }
}
