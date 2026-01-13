import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../peers/peer_model.dart';

class PeerDiscoveryService {
  final String localMirrorId;
  final String hostname;
  final int announcePort;
  final int announceIntervalSeconds;
  final int listenPort;
  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  final Map<String, Peer> _peers = {};

  PeerDiscoveryService({
    required this.localMirrorId,
    required this.hostname,
    this.announcePort = 5005,
    this.listenPort = 5005,
    this.announceIntervalSeconds = 10,
  });

  /// Start listening + broadcasting
  Future<void> start() async {
    // Bind to listen port on any interface
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort,
        reuseAddress: true, reusePort: true);
    _socket?.broadcastEnabled = true;
    _socket?.listen(_onDatagram);

    // Start periodic announces
    _announceTimer =
        Timer.periodic(Duration(seconds: announceIntervalSeconds), (_) async {
      await _broadcastPresence();
      _cleanupStalePeers();
    });

    // Immediately send one
    await _broadcastPresence();
  }

  Future<void> stop() async {
    _announceTimer?.cancel();
    _socket?.close();
    _socket = null;
  }

  Map<String, Peer> get peers => Map.unmodifiable(_peers);

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;
    try {
      final payload = utf8.decode(datagram.data);
      final map = json.decode(payload) as Map<String, dynamic>;
      final resolvedIp = _resolveIp(map["ip"], datagram.address.address);
      final peer = Peer.fromJson({
        ...map,
        if (resolvedIp != null) "ip": resolvedIp,
      });

      // Ignore our own announcements
      if (peer.mirrorId == localMirrorId) return;

      // Update lastSeen
      peer.lastSeenUnix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      _peers[peer.mirrorId] = peer;
    } catch (e) {
      // ignore parse errors
    }
  }

  String? _resolveIp(dynamic rawIp, String fallback) {
    if (rawIp is String && _isValidIp(rawIp)) {
      return rawIp;
    }
    if (_isValidIp(fallback)) {
      return fallback;
    }
    return null;
  }

  bool _isValidIp(String value) {
    if (value.isEmpty) return false;
    if (value == "0.0.0.0") return false;
    if (value.startsWith("127.")) return false;
    return InternetAddress.tryParse(value) != null;
  }

  Future<void> _broadcastPresence() async {
    if (_socket == null) return;
    final now = DateTime.now().toUtc();
    final payload = jsonEncode({
      'mirror_id': localMirrorId,
      'hostname': hostname,
      'ip': await _getLocalIp() ?? '0.0.0.0',
      'port': 8000,
      'timestamp': now.millisecondsSinceEpoch ~/ 1000,
    });

    final data = utf8.encode(payload);

    // Broadcast to common broadcast address first
    try {
      _socket?.send(data, InternetAddress('255.255.255.255'), announcePort);
    } catch (_) {}

    // Also try subnet-specific broadcasts (best-effort)
    final addrs = await NetworkInterface.list();
    for (final iface in addrs) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          final subnetBroadcast = _computeBroadcastAddress(addr.address, addr.rawAddress);
          if (subnetBroadcast != null) {
            try {
              _socket?.send(data, InternetAddress(subnetBroadcast), announcePort);
            } catch (_) {}
          }
        }
      }
    }
  }

  // Best-effort broadcast calculation (may return null)
  String? _computeBroadcastAddress(String ip, List<int> raw) {
    // We can't reliably compute without mask info here; skip.
    // Returning null means we rely on 255.255.255.255 only.
    return null;
  }

  Future<String?> _getLocalIp() async {
    try {
      final ifaces = await NetworkInterface.list();
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Remove peers not seen in last 30 seconds
  void _cleanupStalePeers() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final stale = <String>[];
    _peers.forEach((k, v) {
      if (now - v.lastSeenUnix > 30) stale.add(k);
    });
    for (final k in stale) _peers.remove(k);
  }
}
