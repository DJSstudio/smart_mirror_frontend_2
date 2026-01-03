import 'dart:io';

class PlatformInfo {
  static bool get isMacOS => Platform.isMacOS;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
}
