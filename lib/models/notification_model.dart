class NotificationModel {
  const NotificationModel({
	required this.id,
	required this.userId,
	this.title,
	this.body,
	this.isRead,
	this.createdAt,
  });

  final String id;
  final String userId;
  final String? title;
  final String? body;
  final bool? isRead;
  final DateTime? createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
	return NotificationModel(
	  id: (json['id'] ?? '').toString(),
	  userId: (json['user_id'] ?? '').toString(),
	  title: json['title'] as String?,
	  body: json['body'] as String?,
	  isRead: _parseBool(json['is_read']),
	  createdAt: _parseDateTime(json['created_at']),
	);
  }

  Map<String, dynamic> toJson() {
	return {
	  'id': id,
	  'user_id': userId,
	  'title': title,
	  'body': body,
	  'is_read': isRead,
	  'created_at': createdAt?.toIso8601String(),
	};
  }

  NotificationModel copyWith({
	String? id,
	String? userId,
	String? title,
	String? body,
	bool? isRead,
	DateTime? createdAt,
  }) {
	return NotificationModel(
	  id: id ?? this.id,
	  userId: userId ?? this.userId,
	  title: title ?? this.title,
	  body: body ?? this.body,
	  isRead: isRead ?? this.isRead,
	  createdAt: createdAt ?? this.createdAt,
	);
  }

  static bool? _parseBool(dynamic value) {
	if (value == null) return null;
	if (value is bool) return value;
	if (value is num) return value != 0;
	final text = value.toString().toLowerCase();
	if (text == 'true' || text == 't' || text == '1') return true;
	if (text == 'false' || text == 'f' || text == '0') return false;
	return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
	if (value == null) return null;
	return DateTime.tryParse(value.toString());
  }
}
