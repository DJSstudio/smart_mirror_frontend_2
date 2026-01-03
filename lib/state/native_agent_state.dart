import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../native/native_agent.dart';

final nativeAgentProvider = Provider((ref) => NativeAgent);

final nativeAgentEventsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return NativeAgent.events();
});

final lastRecordedPathProvider = StateProvider<String?>((ref) => null);
