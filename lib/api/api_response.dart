class ApiResponse {
  final bool ok;
  final dynamic data;
  final int status;

  ApiResponse({
    required this.ok,
    required this.data,
    required this.status,
  });

  factory ApiResponse.success(dynamic data, int status) {
    return ApiResponse(ok: true, data: data, status: status);
  }

  factory ApiResponse.error(dynamic data, int status) {
    return ApiResponse(ok: false, data: data, status: status);
  }
}
