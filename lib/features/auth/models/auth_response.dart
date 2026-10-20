class AuthResponse {
  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String accessToken;
  final DateTime expiresAtUtc;
  final String refreshToken;
  final DateTime refreshTokenExpiresAtUtc;

  AuthResponse({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.accessToken,
    required this.expiresAtUtc,
    required this.refreshToken,
    required this.refreshTokenExpiresAtUtc,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      expiresAtUtc: DateTime.tryParse(json['expiresAtUtc'] as String? ?? '') ?? DateTime.now(),
      refreshToken: json['refreshToken'] as String? ?? '',
      refreshTokenExpiresAtUtc:
          DateTime.tryParse(json['refreshTokenExpiresAtUtc'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'fullName': fullName,
      'role': role,
      'accessToken': accessToken,
      'expiresAtUtc': expiresAtUtc.toIso8601String(),
      'refreshToken': refreshToken,
      'refreshTokenExpiresAtUtc': refreshTokenExpiresAtUtc.toIso8601String(),
    };
  }
}