class ProfileModel {
	const ProfileModel({
		required this.id,
		this.userId,
		this.fullName,
		this.email,
		this.phone,
		this.avatarUrl,
		this.createdAt,
		this.paymentMethod,
		this.stripePaymentMethodId,
	});

	final String id;
	final String? userId;
	final String? fullName;
	final String? email;
	final String? phone;
	final String? avatarUrl;
	final DateTime? createdAt;
	final String? paymentMethod;
	final String? stripePaymentMethodId;

	factory ProfileModel.fromJson(Map<String, dynamic> json) {
		return ProfileModel(
			id: (json['id'] ?? '').toString(),
			userId: json['user_id']?.toString(),
			fullName: json['full_name'] as String?,
			email: json['email'] as String?,
			phone: json['phone'] as String?,
			avatarUrl: json['avatar_url'] as String?,
			createdAt: _parseDateTime(json['created_at']),
			paymentMethod: json['payment_method'] as String?,
			stripePaymentMethodId: json['stripe_payment_method_id'] as String?,
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'id': id,
			'user_id': userId,
			'full_name': fullName,
			'email': email,
			'phone': phone,
			'avatar_url': avatarUrl,
			'created_at': createdAt?.toIso8601String(),
			'payment_method': paymentMethod,
			'stripe_payment_method_id': stripePaymentMethodId,
		};
	}

	ProfileModel copyWith({
		String? id,
		String? userId,
		String? fullName,
		String? email,
		String? phone,
		String? avatarUrl,
		DateTime? createdAt,
		String? paymentMethod,
		String? stripePaymentMethodId,
	}) {
		return ProfileModel(
			id: id ?? this.id,
			userId: userId ?? this.userId,
			fullName: fullName ?? this.fullName,
			email: email ?? this.email,
			phone: phone ?? this.phone,
			avatarUrl: avatarUrl ?? this.avatarUrl,
			createdAt: createdAt ?? this.createdAt,
			paymentMethod: paymentMethod ?? this.paymentMethod,
			stripePaymentMethodId: stripePaymentMethodId ?? this.stripePaymentMethodId,
		);
	}

	static DateTime? _parseDateTime(dynamic value) {
		if (value == null) return null;
		return DateTime.tryParse(value.toString())?.toLocal();
	}
}
