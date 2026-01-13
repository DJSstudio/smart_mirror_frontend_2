import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to manage persistent device_id across app sessions
class DeviceService {
  static const String _deviceIdKey = "mirror_device_id";

  /// Get or create device_id - ensures same device_id is used throughout app lifecycle
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if device_id already exists
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // Generate new device_id using UUID
      deviceId = Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
      print("🆕 Generated new device_id: $deviceId");
    } else {
      print("✅ Using existing device_id: $deviceId");
    }

    return deviceId!;
  }

  /// Get current device_id (without creating if it doesn't exist)
  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  /// Reset device_id (for testing or logout scenarios)
  static Future<void> resetDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    print("🔄 Device ID reset");
  }
}
