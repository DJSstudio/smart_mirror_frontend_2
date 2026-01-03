class Peer {
  final String mirrorId;
  final String hostname;
  final String ip;
  final int port;
  int lastSeenUnix; // epoch seconds

  Peer({
    required this.mirrorId,
    required this.hostname,
    required this.ip,
    required this.port,
    required this.lastSeenUnix,
  });

  factory Peer.fromJson(Map<String, dynamic> j) {
    return Peer(
      mirrorId: j['mirror_id'] as String,
      hostname: j['hostname'] as String,
      ip: j['ip'] as String,
      port: (j['port'] as num).toInt(),
      lastSeenUnix: (j['timestamp'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mirror_id': mirrorId,
        'hostname': hostname,
        'ip': ip,
        'port': port,
        'timestamp': lastSeenUnix,
      };

  String get baseUrl => 'http://$ip:$port/api';
}
