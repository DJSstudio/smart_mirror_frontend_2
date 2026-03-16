import '../native/native_agent.dart';

class DisplaySelectionService {
  static Future<void> autoSelectMirrorForSmallDisplay() async {
    final preferred = await NativeAgent.getPreferredMirrorDisplay();
    if (preferred != null && preferred != -1) return;

    final info = await NativeAgent.getDisplayInfo();
    final currentId = info["currentDisplayId"] as int?;
    final displays = (info["displays"] as List?) ?? [];
    if (currentId == null) return;

    final external = <Map<String, dynamic>>[];
    Map<String, dynamic>? smallestDisplay;

    for (final d in displays) {
      final map = Map<String, dynamic>.from(d as Map);
      final isPresentation = map["isPresentation"] == true;
      if (!isPresentation) continue;
      external.add(map);
      final w = map["width"] as int? ?? 0;
      final h = map["height"] as int? ?? 0;
      final area = w * h;
      if (smallestDisplay == null) {
        smallestDisplay = map;
      } else {
        final sw = smallestDisplay["width"] as int? ?? 0;
        final sh = smallestDisplay["height"] as int? ?? 0;
        final sArea = sw * sh;
        if (area > 0 && (sArea == 0 || area < sArea)) {
          smallestDisplay = map;
        }
      }
    }

    if (smallestDisplay == null) return;
    final smallestId = smallestDisplay["id"] as int?;
    if (smallestId == null) return;

    // Only auto-select if app is running on the smallest display.
    if (currentId != smallestId) return;

    Map<String, dynamic>? mirrorCandidate;
    for (final map in external) {
      final id = map["id"] as int?;
      if (id == null || id == smallestId) continue;
      if (mirrorCandidate == null) {
        mirrorCandidate = map;
        continue;
      }
      final w = map["width"] as int? ?? 0;
      final h = map["height"] as int? ?? 0;
      final area = w * h;
      final mw = mirrorCandidate["width"] as int? ?? 0;
      final mh = mirrorCandidate["height"] as int? ?? 0;
      final mArea = mw * mh;
      if (area > mArea) {
        mirrorCandidate = map;
      }
    }

    final mirrorId = mirrorCandidate?["id"] as int?;
    if (mirrorId == null) return;
    await NativeAgent.setPreferredMirrorDisplay(mirrorId);
  }

  static Future<void> forceMirrorToLargestExternal() async {
    final info = await NativeAgent.getDisplayInfo();
    final currentId = info["currentDisplayId"] as int?;
    final displays = (info["displays"] as List?) ?? [];
    if (currentId == null) return;

    final external = <Map<String, dynamic>>[];
    for (final d in displays) {
      final map = Map<String, dynamic>.from(d as Map);
      if (map["isPresentation"] == true) {
        external.add(map);
      }
    }
    if (external.isEmpty) return;

    Map<String, dynamic>? smallest;
    Map<String, dynamic>? largest;

    for (final map in external) {
      final w = map["width"] as int? ?? 0;
      final h = map["height"] as int? ?? 0;
      final area = w * h;
      if (smallest == null) {
        smallest = map;
      } else {
        final sw = smallest["width"] as int? ?? 0;
        final sh = smallest["height"] as int? ?? 0;
        final sArea = sw * sh;
        if (area > 0 && (sArea == 0 || area < sArea)) {
          smallest = map;
        }
      }
      if (largest == null) {
        largest = map;
      } else {
        final lw = largest["width"] as int? ?? 0;
        final lh = largest["height"] as int? ?? 0;
        final lArea = lw * lh;
        if (area > lArea) {
          largest = map;
        }
      }
    }

    final smallestId = smallest?["id"] as int?;
    final largestId = largest?["id"] as int?;
    if (smallestId == null || largestId == null) return;

    // Only force if app is running on the smallest display.
    if (currentId != smallestId) return;

    await NativeAgent.setPreferredMirrorDisplay(largestId);
  }
}
