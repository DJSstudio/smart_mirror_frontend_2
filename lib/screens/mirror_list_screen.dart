import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/peers_state.dart';
import '../peers/peer_model.dart';

class MirrorListScreen extends ConsumerWidget {
  const MirrorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(peersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Available Mirrors')),
      body: peersAsync.when(
        data: (peers) {
          if (peers.isEmpty) {
            return const Center(child: Text('No peers found on LAN'));
          }
          return ListView.builder(
            itemCount: peers.length,
            itemBuilder: (context, i) {
              final p = peers[i];
              return _peerTile(context, ref, p);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _peerTile(BuildContext context, WidgetRef ref, Peer p) {
    final active = ref.watch(activeMirrorProvider)?.mirrorId == p.mirrorId;
    return ListTile(
      title: Text('${p.hostname} (${p.ip})'),
      subtitle: Text('Port: ${p.port} • Seen: ${DateTime.fromMillisecondsSinceEpoch(p.lastSeenUnix * 1000)}'),
      trailing: active ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () async {
        ref.read(activeMirrorProvider.notifier).state = p;
        // Trigger sync provider side-effect
        ref.read(activeMirrorSyncProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to ${p.hostname}')),
        );
      },
    );
  }
}
