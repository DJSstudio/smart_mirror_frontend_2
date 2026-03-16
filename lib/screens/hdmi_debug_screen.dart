import 'package:flutter/material.dart';
import '../native/native_agent.dart';

class HdmiDebugScreen extends StatefulWidget {
  const HdmiDebugScreen({super.key});

  @override
  State<HdmiDebugScreen> createState() => _HdmiDebugScreenState();
}

class _HdmiDebugScreenState extends State<HdmiDebugScreen> {
  final _playController = TextEditingController();
  final _leftController = TextEditingController();
  final _rightController = TextEditingController();

  Map<String, dynamic> _info = {};
  String? _lastResult;
  String? _mirrorStatus;
  int _rotation = 0;
  int _preferredDisplayId = -1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshInfo();
  }

  @override
  void dispose() {
    _playController.dispose();
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  Future<void> _refreshInfo() async {
    setState(() {
      _loading = true;
    });
    final info = await NativeAgent.getDisplayInfo();
    final status = await NativeAgent.getMirrorStatus();
    final rotation = await NativeAgent.getMirrorRotation();
    final preferred = await NativeAgent.getPreferredMirrorDisplay();
    if (!mounted) return;
    setState(() {
      _info = info;
      _mirrorStatus = status;
      _rotation = rotation ?? 0;
      _preferredDisplayId = preferred ?? -1;
      _loading = false;
    });
  }

  Future<void> _setRotation(int degrees) async {
    await NativeAgent.setMirrorRotation(degrees);
    await _refreshInfo();
  }

  Future<void> _setPreferredDisplay(int displayId) async {
    await NativeAgent.setPreferredMirrorDisplay(displayId);
    await _refreshInfo();
  }

  Future<void> _clearPreferredDisplay() async {
    await NativeAgent.clearPreferredMirrorDisplay();
    await _refreshInfo();
  }

  Future<void> _runAction(String label, Future<bool> Function() action) async {
    setState(() {
      _lastResult = "$label: running...";
    });
    final ok = await action();
    if (!mounted) return;
    setState(() {
      _lastResult = "$label: ${ok ? "ok" : "failed"}";
    });
  }

  @override
  Widget build(BuildContext context) {
    final displays = (_info["displays"] as List?) ?? [];
    final currentId = _info["currentDisplayId"];
    final presentationIds = (_info["presentationIds"] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("HDMI Debug"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "currentDisplayId: $currentId",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              "presentationIds: $presentationIds",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else
              ...displays.map((d) {
                final map = Map<String, dynamic>.from(d as Map);
                final id = map["id"];
                final isPreferred = id == _preferredDisplayId;
                final isCurrent = id == currentId;
                final isPresentation = map["isPresentation"] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "id=$id state=${map["state"]} "
                        "flags=${map["flags"]} "
                        "size=${map["width"]}x${map["height"]}\n${map["name"]}",
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (isCurrent || !isPresentation)
                                  ? null
                                  : () => _setPreferredDisplay(id),
                              child: Text(
                                isCurrent
                                    ? "App display"
                                    : (isPreferred ? "Selected" : "Use this display"),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _clearPreferredDisplay,
              child: const Text("Auto-select display"),
            ),
            const Divider(height: 32),
            if (_mirrorStatus != null)
              Text(
                "mirrorStatus: $_mirrorStatus",
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 8),
            Text(
              "rotation: $_rotation°",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              "preferredDisplayId: ${_preferredDisplayId == -1 ? 'auto' : _preferredDisplayId}",
              style: const TextStyle(color: Colors.white70),
            ),
            if (_mirrorStatus != null) const SizedBox(height: 8),
            if (_lastResult != null)
              Text(
                _lastResult!,
                style: const TextStyle(color: Colors.white),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _runAction(
                      "Show idle",
                      () => NativeAgent.showMirrorIdle(),
                    ),
                    child: const Text("Show Idle"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _runAction(
                      "Hide mirror",
                      () => NativeAgent.hideMirror(),
                    ),
                    child: const Text("Hide"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Rotate HDMI (mirror output only)",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Portrait rotation (90°)"),
              value: _rotation == 90,
              onChanged: (value) => _setRotation(value ? 90 : 0),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await NativeAgent.clearMirrorStatus();
                _refreshInfo();
              },
              child: const Text("Clear Mirror Status"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _playController,
              decoration: const InputDecoration(
                labelText: "Play URL or path",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                final value = _playController.text.trim();
                if (value.isEmpty) {
                  setState(() {
                    _lastResult = "Play: missing URL/path";
                  });
                  return;
                }
                _runAction("Play", () => NativeAgent.playOnMirror(value));
              },
              child: const Text("Play on HDMI"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _leftController,
              decoration: const InputDecoration(
                labelText: "Compare left URL/path",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rightController,
              decoration: const InputDecoration(
                labelText: "Compare right URL/path",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                final left = _leftController.text.trim();
                final right = _rightController.text.trim();
                if (left.isEmpty || right.isEmpty) {
                  setState(() {
                    _lastResult = "Compare: missing URL/path";
                  });
                  return;
                }
                _runAction("Compare", () => NativeAgent.compareOnMirror(left, right));
              },
              child: const Text("Compare on HDMI"),
            ),
          ],
        ),
      ),
    );
  }
}
