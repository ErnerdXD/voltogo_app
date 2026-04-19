class UserModel {
	const UserModel({
		required this.id,
		this.authUserId,
		this.role,
		this.createdAt,
		this.isDeleted = false, // Added with a default of false
	});

	final String id;
	final String? authUserId;
	final String? role;
	final DateTime? createdAt;
	final bool isDeleted; // New property

	factory UserModel.fromJson(Map<String, dynamic> json) {
		return UserModel(
			id: (json['id'] ?? '').toString(),
			authUserId: json['auth_user_id']?.toString(),
			role: json['role'] as String?,
			createdAt: _parseDateTime(json['created_at']),
			// Safely parse the boolean, defaulting to false if it's missing
			isDeleted: json['is_deleted'] as bool? ?? false,
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'id': id,
			'auth_user_id': authUserId,
			'role': role,
			'created_at': createdAt?.toIso8601String(),
			'is_deleted': isDeleted, // Added to JSON export
		};
	}

	UserModel copyWith({
		String? id,
		String? authUserId,
		String? role,
		DateTime? createdAt,
		bool? isDeleted, // Added to copyWith
	}) {
		return UserModel(
			id: id ?? this.id,
			authUserId: authUserId ?? this.authUserId,
			role: role ?? this.role,
			createdAt: createdAt ?? this.createdAt,
			isDeleted: isDeleted ?? this.isDeleted, // Passes the updated value
		);
	}

	static DateTime? _parseDateTime(dynamic value) {
		if (value == null) return null;
		return DateTime.tryParse(value.toString())?.toLocal();
	}
}