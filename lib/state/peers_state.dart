import 'dart:async';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../peers/peer_discovery_service.dart';
import '../peers/peer_model.dart';
import '../utils/env.dart';
import '../api/client_provider.dart';
import '../services/base_url_service.dart';

final peerDiscoveryProvider = Provider<PeerDiscoveryService>((ref) {
  // Replace these values with your local mirror id + hostname
  final localId = const String.fromEnvironment('MIRROR_ID', defaultValue: 'local-mirror');
  final hostname = const String.fromEnvironment('HOSTNAME', defaultValue: 'mirror-001');
  final svc = PeerDiscoveryService(localMirrorId: localId, hostname: hostname);
  ref.onDispose(() {
    svc.stop();
  });
  return svc;
});

final peersListProvider = StreamProvider<List<Peer>>((ref) {
  final svc = ref.read(peerDiscoveryProvider);
  // Start discovery in background
  svc.start();

  // Emit peers every second
  return Stream.periodic(const Duration(seconds: 1), (_) {
    final peers = svc.peers.values.toList()
      ..sort((a, b) => b.lastSeenUnix.compareTo(a.lastSeenUnix));
    return peers;
  });
});

// Active mirror (selected by user)
final activeMirrorProvider = StateProvider<Peer?>((ref) => null);

// When active mirror changes, update Env + ApiClient
final activeMirrorSyncProvider = Provider<void>((ref) {
  final peer = ref.watch(activeMirrorProvider);
  if (peer != null) {
    // update Env and ApiClient base URL
    Env.updateBaseUrl(peer.baseUrl);
    final apiClient = ref.read(apiClientProvider);
    apiClient.updateBaseUrl(peer.baseUrl);
    unawaited(BaseUrlService.saveBaseUrl(peer.baseUrl));
  }
});
