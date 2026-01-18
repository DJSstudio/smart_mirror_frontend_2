import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import '../peers/peer_model.dart';
import '../services/base_url_service.dart';
import '../services/session_transfer_service.dart';
import '../state/peers_state.dart';
import '../state/session_provider.dart';

class ContinueSessionScreen extends ConsumerStatefulWidget {
  const ContinueSessionScreen({super.key});

  @override
  ConsumerState<ContinueSessionScreen> createState() =>
      _ContinueSessionScreenState();
}

class _ContinueSessionScreenState
    extends ConsumerState<ContinueSessionScreen> {
  final List<RemoteSessionEntry> _entries = [];
  bool _loading = false;
  String? _error;

  SessionTransferService get _service =>
      SessionTransferService(ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final apiClient = ref.read(apiClientProvider);
      final ok = await BaseUrlService.bootstrap(apiClient);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = "No mirror found on LAN. Check Wi-Fi and backend.";
        });
      }
    });
    ref.listen<AsyncValue<List<Peer>>>(peersListProvider, (prev, next) {
      final peers = next.asData?.value ?? const <Peer>[];
      if (peers.isNotEmpty) {
        _refreshSessions(peers);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final peers = ref.read(peersListProvider).asData?.value ?? const <Peer>[];
      if (peers.isNotEmpty) {
        _refreshSessions(peers);
      }
    });
  }

  Future<void> _refreshSessions(List<Peer> peers) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _service.fetchRemoteSessions(peers);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(entries);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load sessions";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _startTransfer(RemoteSessionEntry entry) async {
    String status = "Starting transfer...";
    StateSetter? setDialogState;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            setDialogState = setStateDialog;
            return AlertDialog(
              title: const Text("Transferring Session"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(status, textAlign: TextAlign.center),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final sessionId = await _service.transferSession(
        entry,
        onStatus: (msg) {
          status = msg;
          if (setDialogState != null) {
            setDialogState!(() {});
          }
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      ref.read(sessionProvider.notifier).setActiveSession(sessionId);
      Navigator.pushReplacementNamed(context, "/menu");
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Transfer failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final peersAsync = ref.watch(peersListProvider);
    final peers = peersAsync.asData?.value ?? const <Peer>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Continue Session"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshSessions(peers),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (peers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "No mirrors found on LAN.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  Expanded(
                    child: _entries.isEmpty
                        ? const Center(
                            child: Text(
                              "No active sessions found.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              return ListTile(
                                title: Text(
                                  "${entry.peer.hostname} • ${entry.status}",
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  entry.sessionId,
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white54,
                                ),
                                onTap: () => _startTransfer(entry),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
