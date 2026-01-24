import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

class BaseUrlService {
  static const _key = "base_url";
  static const _defaultPort = 8000;
  static const _announcePort = 5005;
  static const String _expectedMirrorId =
      String.fromEnvironment('MIRROR_ID', defaultValue: '');
  static const String _expectedHostname =
      String.fromEnvironment('HOSTNAME', defaultValue: '');
  static const bool _allowRemoteFallback =
      bool.fromEnvironment('ALLOW_REMOTE_BACKEND', defaultValue: false);

  static String? _lastDatagramDebug;

  static String? lastDatagramDebug() => _lastDatagramDebug;
  static void clearLastDatagramDebug() {
    _lastDatagramDebug = null;
  }

  static Future<String?> getSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url);
  }

  static Future<void> clearSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<bool> bootstrap(ApiClient apiClient) async {
    final discovered = await _discoverFromLan();
    if (discovered == null || discovered.isEmpty) {
      return false;
    }
    await saveBaseUrl(discovered);
    apiClient.updateBaseUrl(discovered);
    return true;
  }

  static Future<String?> _discoverFromLan({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    RawDatagramSocket? socket;
    final completer = Completer<String?>();
    Timer? timer;
    Timer? announceTimer;
    final localIps = await _getLocalIps();
    String? fallback;

    try {
      final boundSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: true,
      );
      socket = boundSocket;
      boundSocket.broadcastEnabled = true;
      _sendDiscover(boundSocket);
      announceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _sendDiscover(boundSocket);
      });
      boundSocket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = boundSocket.receive();
        if (datagram == null) return;
        try {
          final payload = utf8.decode(datagram.data);
          _lastDatagramDebug =
              "from=${datagram.address.address}:${datagram.port}\n$payload";
          final map = json.decode(payload);
          if (map is! Map<String, dynamic>) return;
          final resolved = _resolveBroadcastUrl(map, datagram.address.address);
          if (resolved == null) return;
          final payloadIp = _resolveIp(map["ip"], datagram.address.address);
          final matchesExpected = _matchesExpectedMirror(map);
          final isLocal =
              payloadIp != null && localIps.contains(payloadIp);
          if (isLocal || matchesExpected) {
            if (!completer.isCompleted) {
              completer.complete(resolved);
            }
            return;
          }
          if (_allowRemoteFallback) {
            fallback ??= resolved;
          }
        } catch (_) {}
      });
      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(fallback);
        }
      });
      final result = await completer.future;
      return result;
    } catch (_) {
      return null;
    } finally {
      timer?.cancel();
      announceTimer?.cancel();
      socket?.close();
    }
  }

  static String? _resolveIp(dynamic rawIp, String fallback) {
    if (rawIp is String && _isValidIp(rawIp)) {
      return rawIp;
    }
    if (_isValidIp(fallback)) {
      return fallback;
    }
    return null;
  }

  static void _sendDiscover(RawDatagramSocket socket) {
    try {
      final payload = json.encode({
        "type": "discover",
        "timestamp": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      final data = utf8.encode(payload);
      socket.send(data, InternetAddress("255.255.255.255"), _announcePort);
    } catch (_) {}
  }

  static bool _matchesExpectedMirror(Map<String, dynamic> map) {
    if (_expectedMirrorId.isEmpty && _expectedHostname.isEmpty) {
      return false;
    }
    final mirrorId = map["mirror_id"];
    if (_expectedMirrorId.isNotEmpty && mirrorId == _expectedMirrorId) {
      return true;
    }
    final hostname = map["hostname"];
    if (_expectedHostname.isNotEmpty && hostname == _expectedHostname) {
      return true;
    }
    return false;
  }

  static String? _resolveBroadcastUrl(
    Map<String, dynamic> map,
    String fallbackIp,
  ) {
    final baseUrl = map["base_url"];
    if (baseUrl is String && baseUrl.trim().isNotEmpty) {
      return _normalizeBaseUrl(baseUrl);
    }

    final payloadIp = map["ip"];
    String? ip;
    if (payloadIp is String && _isValidIp(payloadIp)) {
      ip = payloadIp;
    } else if (_isValidIp(fallbackIp)) {
      ip = fallbackIp;
    }
    if (ip == null) return null;

    final portValue = map["port"];
    final port = (portValue is num) ? portValue.toInt() : _defaultPort;
    return _normalizeBaseUrl("http://$ip:$port");
  }

  static String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (!value.startsWith("http://") && !value.startsWith("https://")) {
      value = "http://$value";
    }
    value = value.replaceAll(RegExp(r"/+$"), "");
    if (value.endsWith("/api")) {
      return value;
    }
    return "$value/api";
  }

  static Future<Set<String>> _getLocalIps() async {
    final results = <String>{};
    try {
      final ifaces = await NetworkInterface.list();
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254')) {
            results.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return results;
  }

  static bool _isValidIp(String value) {
    if (value.isEmpty) return false;
    if (value == "0.0.0.0") return false;
    if (value.startsWith("127.")) return false;
    return InternetAddress.tryParse(value) != null;
  }
}
