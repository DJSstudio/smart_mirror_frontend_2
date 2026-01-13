import 'package:shared_preferences/shared_preferences.dart';

class ErrorLogger {
  static const _key = 'last_flutter_error';

  static Future<void> log(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, message);
  }

  static Future<String?> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
