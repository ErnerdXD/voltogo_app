class UserModel {
  const UserModel({
	required this.id,
	this.authUserId,
	this.role,
	this.createdAt,
  });

  final String id;
  final String? authUserId;
  final String? role;
  final DateTime? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
	return UserModel(
	  id: (json['id'] ?? '').toString(),
	  authUserId: json['auth_user_id']?.toString(),
	  role: json['role'] as String?,
	  createdAt: _parseDateTime(json['created_at']),
	);
  }

  Map<String, dynamic> toJson() {
	return {
	  'id': id,
	  'auth_user_id': authUserId,
	  'role': role,
	  'created_at': createdAt?.toIso8601String(),
	};
  }

  UserModel copyWith({
	String? id,
	String? authUserId,
	String? role,
	DateTime? createdAt,
  }) {
	return UserModel(
	  id: id ?? this.id,
	  authUserId: authUserId ?? this.authUserId,
	  role: role ?? this.role,
	  createdAt: createdAt ?? this.createdAt,
	);
  }

  static DateTime? _parseDateTime(dynamic value) {
	if (value == null) return null;
	return DateTime.tryParse(value.toString());
  }
}
