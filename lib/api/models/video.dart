class VideoModel {
  final String id;
  final String sessionId;
  final String codec;
  final int sizeBytes;
  final bool encrypted;
  final String fileUrl;
  final DateTime createdAt;

  VideoModel({
    required this.id,
    required this.sessionId,
    required this.codec,
    required this.sizeBytes,
    required this.encrypted,
    required this.fileUrl,
    required this.createdAt,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json["id"],
      sessionId: json["session"],
      codec: json["codec"],
      sizeBytes: json["size_bytes"],
      encrypted: json["encrypted"],
      fileUrl: json["file_url"],
      createdAt: DateTime.parse(json["created_at"]),
    );
  }
}
