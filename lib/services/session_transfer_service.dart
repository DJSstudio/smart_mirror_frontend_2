import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../peers/peer_model.dart';

class RemoteSessionEntry {
  final Peer peer;
  final Map<String, dynamic> session;

  RemoteSessionEntry({required this.peer, required this.session});

  String get sessionId =>
      (session["id"] ?? session["session_id"] ?? "").toString();
  String get status => (session["status"] ?? "unknown").toString();
}

class SessionTransferService {
  final ApiClient apiClient;
  final Dio _dio = Dio();

  SessionTransferService(this.apiClient);

  Future<List<RemoteSessionEntry>> fetchRemoteSessions(List<Peer> peers) async {
    final entries = <RemoteSessionEntry>[];
    final localBase = apiClient.dio.options.baseUrl;
    for (final peer in peers) {
      if (localBase.isNotEmpty && peer.baseUrl == localBase) {
        continue;
      }
      try {
        final dio = Dio(
          BaseOptions(
            baseUrl: peer.baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final res = await dio.get("/peer/sessions");
        if (res.statusCode != 200 || res.data is! Map) {
          continue;
        }
        final data = Map<String, dynamic>.from(res.data as Map);
        final sessions = (data["sessions"] as List?) ?? [];
        for (final s in sessions) {
          if (s is Map) {
            entries.add(RemoteSessionEntry(
              peer: peer,
              session: Map<String, dynamic>.from(s),
            ));
          }
        }
      } catch (_) {}
    }
    return entries;
  }

  Future<String> transferSession(
    RemoteSessionEntry entry, {
    void Function(String message)? onStatus,
  }) async {
    onStatus?.call("Resolving local mirror...");
    final localMirrorId = await _getLocalMirrorId();
    if (localMirrorId == null || localMirrorId.isEmpty) {
      throw Exception("Unable to resolve local mirror id");
    }

    final sourceDio = Dio(
      BaseOptions(
        baseUrl: entry.peer.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    onStatus?.call("Requesting transfer token...");
    final tokenRes = await sourceDio.post(
      "/transfer_session_request",
      data: {
        "session_id": entry.sessionId,
        "to_mirror_id": localMirrorId,
      },
    );
    if (tokenRes.statusCode != 201 || tokenRes.data is! Map) {
      throw Exception("Transfer token request failed");
    }
    final tokenData = Map<String, dynamic>.from(tokenRes.data as Map);
    final token = tokenData["token"]?.toString();
    if (token == null || token.isEmpty) {
      throw Exception("Transfer token missing");
    }

    onStatus?.call("Fetching session snapshot...");
    final snapRes = await sourceDio.get(
      "/transfer_session_snapshot",
      queryParameters: {"session_id": entry.sessionId},
    );
    if (snapRes.statusCode != 200 || snapRes.data is! Map) {
      throw Exception("Snapshot fetch failed");
    }
    final snapData = Map<String, dynamic>.from(snapRes.data as Map);
    final sessionMeta =
        Map<String, dynamic>.from((snapData["session"] as Map?) ?? {});
    final videos = (snapData["videos"] as List?) ?? [];

    onStatus?.call("Preparing session...");
    final completeRes = await apiClient.post(
      "/transfer_session_complete",
      body: {
        "token": token,
        "session_metadata": _filterSessionMeta(sessionMeta),
      },
    );
    if (!completeRes.ok) {
      throw Exception("Local session prepare failed");
    }

    final tempDir = await getTemporaryDirectory();
    for (var i = 0; i < videos.length; i++) {
      final raw = videos[i];
      if (raw is! Map) continue;
      final video = Map<String, dynamic>.from(raw);
      final fileUrl = video["file_url"]?.toString();
      if (fileUrl == null || fileUrl.isEmpty) continue;

      final name = _buildFilename(video, i);
      final path = "${tempDir.path}/$name";

      onStatus?.call("Downloading video ${i + 1}/${videos.length}...");
      await _dio.download(fileUrl, path);

      onStatus?.call("Uploading video ${i + 1}/${videos.length}...");
      final uploadRes = await apiClient.uploadVideoFile(
        entry.sessionId,
        path,
        filename: name,
      );
      if (!uploadRes.ok) {
        throw Exception("Video upload failed");
      }

      try {
        await File(path).delete();
      } catch (_) {}
    }

    onStatus?.call("Finalizing transfer...");
    final finalizeRes = await sourceDio.post(
      "/transfer_session_finalize",
      data: {"token": token},
    );
    if (finalizeRes.statusCode != 200) {
      throw Exception("Finalize transfer failed");
    }

    return entry.sessionId;
  }

  Future<Map<String, dynamic>?> getLocalActiveSession() async {
    final res = await apiClient.get("/peer/sessions");
    if (!res.ok || res.data is! Map) return null;
    final data = Map<String, dynamic>.from(res.data as Map);
    final sessions = (data["sessions"] as List?) ?? [];
    if (sessions.isEmpty) return null;
    final session = sessions.first;
    if (session is! Map) return null;
    return Map<String, dynamic>.from(session);
  }

  String _buildFilename(Map<String, dynamic> video, int index) {
    final rawId = video["id"]?.toString();
    if (rawId != null && rawId.isNotEmpty) {
      return "transfer_$rawId.mp4";
    }
    return "transfer_$index.mp4";
  }

  Map<String, dynamic> _filterSessionMeta(Map<String, dynamic> session) {
    final deviceId = session["device_id"];
    final userId = session["user_id"];
    return {
      if (deviceId != null) "device_id": deviceId,
      if (userId != null) "user_id": userId,
    };
  }

  Future<String?> _getLocalMirrorId() async {
    final res = await apiClient.get("/peer/sessions");
    if (!res.ok || res.data is! Map) return null;
    final data = Map<String, dynamic>.from(res.data as Map);
    final mirror = data["mirror"];
    if (mirror is! Map) return null;
    final meta = mirror["metadata"];
    if (meta is Map) {
      final mirrorId = meta["mirror_id"]?.toString();
      if (mirrorId != null && mirrorId.isNotEmpty) {
        return mirrorId;
      }
    }
    return mirror["id"]?.toString();
  }
}
