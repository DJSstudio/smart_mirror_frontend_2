class SessionModel {
  final String id;
  final String status;
  final Map<String, dynamic> userMeta;
  final DateTime createdAt;
  final DateTime? expiry;

  SessionModel({
    required this.id,
    required this.status,
    required this.userMeta,
    required this.createdAt,
    this.expiry,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      status: json['status'],
      userMeta: json['user_meta'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      expiry:
          json['expiry'] != null ? DateTime.parse(json['expiry']) : null,
    );
  }
}
