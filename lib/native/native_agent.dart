import 'dart:async';
import 'package:flutter/services.dart';

class NativeAgent {
  static const MethodChannel _channel = MethodChannel('smartmirror/native_agent');
  static const EventChannel _events = EventChannel('smartmirror/native_agent_events');

  static Stream<Map<String, dynamic>>? _eventStream;

  static Future<bool> startRecording({required String filename}) async {
    try {
      final res = await _channel.invokeMethod<bool>('startRecording', {'filename': filename});
      return res ?? false;
    } catch (e) {
      print('startRecording error: $e');
      return false;
    }
  }

  static Future<String?> stopRecording() async {
    try {
      final path = await _channel.invokeMethod<String>('stopRecording');
      return path;
    } catch (e) {
      print('stopRecording error: $e');
      return null;
    }
  }

  static Future<bool> preview() async {
    try {
      final res = await _channel.invokeMethod<bool>('preview');
      return res ?? true;
    } catch (e) {
      print('preview error: $e');
      return false;
    }
  }

  static Future<bool> playOnMirror(String path) async {
    try {
      final res = await _channel.invokeMethod<bool>('playOnMirror', {'path': path});
      return res ?? false;
    } catch (e) {
      print('playOnMirror error: $e');
      return false;
    }
  }

  static Future<bool> compareOnMirror(String left, String right) async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'compareOnMirror',
        {'left': left, 'right': right},
      );
      return res ?? false;
    } catch (e) {
      print('compareOnMirror error: $e');
      return false;
    }
  }

  static Future<bool> showMirrorIdle() async {
    try {
      final res = await _channel.invokeMethod<bool>('showMirrorIdle');
      return res ?? false;
    } catch (e) {
      print('showMirrorIdle error: $e');
      return false;
    }
  }

  static Future<bool> hideMirror() async {
    try {
      final res = await _channel.invokeMethod<bool>('hideMirror');
      return res ?? false;
    } catch (e) {
      print('hideMirror error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getDisplayInfo() async {
    try {
      final res = await _channel.invokeMethod<dynamic>('getDisplayInfo');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {};
    } catch (e) {
      print('getDisplayInfo error: $e');
      return {};
    }
  }

  static Future<String?> captureUsbVideo({bool autoStart = true}) async {
    final path = await _channel.invokeMethod<String>(
      'captureUsbVideo',
      {'auto_start': autoStart},
    );
    return path;
  }

  static Future<bool> hasExternalCamera() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasExternalCamera');
      return res ?? false;
    } catch (e) {
      print('hasExternalCamera error: $e');
      return false;
    }
  }

  static Future<String?> getLastCrash() async {
    try {
      final res = await _channel.invokeMethod<dynamic>('getLastCrash');
      if (res is String) {
        return res;
      }
      return null;
    } catch (e) {
      print('getLastCrash error: $e');
      return null;
    }
  }

  static Future<void> clearLastCrash() async {
    try {
      await _channel.invokeMethod<dynamic>('clearLastCrash');
    } catch (e) {
      print('clearLastCrash error: $e');
    }
  }

  static Future<String?> getMirrorStatus() async {
    try {
      final res = await _channel.invokeMethod<dynamic>('getMirrorStatus');
      if (res is String) {
        return res;
      }
      return null;
    } catch (e) {
      print('getMirrorStatus error: $e');
      return null;
    }
  }

  static Future<void> clearMirrorStatus() async {
    try {
      await _channel.invokeMethod<dynamic>('clearMirrorStatus');
    } catch (e) {
      print('clearMirrorStatus error: $e');
    }
  }

  static Future<Map<String, dynamic>> getLastUsbCaptureStatus() async {
    try {
      final res = await _channel.invokeMethod<dynamic>('getLastUsbCaptureStatus');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {};
    } catch (e) {
      print('getLastUsbCaptureStatus error: $e');
      return {};
    }
  }

  static Future<void> clearLastUsbCaptureStatus() async {
    try {
      await _channel.invokeMethod<dynamic>('clearLastUsbCaptureStatus');
    } catch (e) {
      print('clearLastUsbCaptureStatus error: $e');
    }
  }

  static Future<String?> getLastRecorded() async {
    try {
      final path = await _channel.invokeMethod<String>('getLastRecorded');
      return path;
    } catch (e) {
      print('getLastRecorded error: $e');
      return null;
    }
  }

  static Stream<Map<String, dynamic>> events() {
    _eventStream ??= _events.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'event': event.toString()};
    });
    return _eventStream!;
  }

  static Future<void> openNativePlayer(String source) async {
    try {
      await _channel.invokeMethod<dynamic>(
        'openNativePlayer',
        {'source': source},
      );
    } catch (e) {
      print('openNativePlayer error: $e');
    }
  }

  static Future<void> openNativeCompare(String left, String right) async {
    try {
      await _channel.invokeMethod<dynamic>(
        'openNativeCompare',
        {'left': left, 'right': right},
      );
    } catch (e) {
      print('openNativeCompare error: $e');
    }
  }
}
