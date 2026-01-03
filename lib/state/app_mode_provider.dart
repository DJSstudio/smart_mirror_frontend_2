import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_mode.dart';
import 'dart:io';

final appModeProvider = Provider<AppMode>((ref) {
  if (Platform.isMacOS) return AppMode.mirror; // testing mirror on Mac
  if (Platform.isAndroid || Platform.isIOS) return AppMode.phone;
  return AppMode.mirror;
});
