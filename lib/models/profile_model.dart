class ProfileModel {
  const ProfileModel({
	required this.id,
	this.userId,
	this.fullName,
	this.phone,
	this.avatarUrl,
	this.createdAt,
  });

  final String id;
  final String? userId;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
	return ProfileModel(
	  id: (json['id'] ?? '').toString(),
	  userId: json['user_id']?.toString(),
	  fullName: json['full_name'] as String?,
	  phone: json['phone'] as String?,
	  avatarUrl: json['avatar_url'] as String?,
	  createdAt: _parseDateTime(json['created_at']),
	);
  }

  Map<String, dynamic> toJson() {
	return {
	  'id': id,
	  'user_id': userId,
	  'full_name': fullName,
	  'phone': phone,
	  'avatar_url': avatarUrl,
	  'created_at': createdAt?.toIso8601String(),
	};
  }

  ProfileModel copyWith({
	String? id,
	String? userId,
	String? fullName,
	String? phone,
	String? avatarUrl,
	DateTime? createdAt,
  }) {
	return ProfileModel(
	  id: id ?? this.id,
	  userId: userId ?? this.userId,
	  fullName: fullName ?? this.fullName,
	  phone: phone ?? this.phone,
	  avatarUrl: avatarUrl ?? this.avatarUrl,
	  createdAt: createdAt ?? this.createdAt,
	);
  }

  static DateTime? _parseDateTime(dynamic value) {
	if (value == null) return null;
	return DateTime.tryParse(value.toString());
  }
}
