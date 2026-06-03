class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code,
    this.upgradeRequired = false,
    this.statusCode,
  });

  final String message;
  final String? code;
  final bool upgradeRequired;
  final int? statusCode;

  bool get isPlanLimit => code == 'PLAN_LIMIT_REACHED' || upgradeRequired;

  bool get isActiveSourceLimit => code == 'ACTIVE_SOURCE_LIMIT';

  factory ApiException.fromResponse(Map<String, dynamic> payload, int statusCode) {
    final error = payload['error'];
    if (error is Map<String, dynamic>) {
      final code = error['code']?.toString();
      final upgrade = error['upgrade_required'] == true || code == 'PLAN_LIMIT_REACHED';
      var message = error['message']?.toString() ?? 'Request failed';
      if (message == 'Source limit reached for current plan') {
        message = 'Gói Free chỉ được 1 nguồn. Nâng VIP để thêm nhiều nguồn.';
      }
      return ApiException(
        message: message,
        code: code,
        upgradeRequired: upgrade,
        statusCode: statusCode,
      );
    }

    final detail = payload['detail'];
    if (detail is Map<String, dynamic>) {
      return ApiException.fromResponse({'error': detail}, statusCode);
    }
    if (detail is String) {
      return ApiException(message: detail, statusCode: statusCode);
    }

    return ApiException(message: 'Request failed ($statusCode)', statusCode: statusCode);
  }

  @override
  String toString() => message;
}
