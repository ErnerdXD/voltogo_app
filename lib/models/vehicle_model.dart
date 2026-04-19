class VehicleModel {
	const VehicleModel({
		required this.id,
		required this.userId,
		this.brand,
		this.model,
		this.plugType,
		this.batteryCapacityKwh,
		this.plateNumber,
	});

	final String id;
	final String userId;
	final String? brand;
	final String? model;
	final String? plugType;
	final int? batteryCapacityKwh;
	final String? plateNumber;

	factory VehicleModel.fromJson(Map<String, dynamic> json) {
		return VehicleModel(
			id: (json['id'] ?? '').toString(),
			userId: (json['user_id'] ?? '').toString(),
			brand: json['brand'] as String?,
			model: json['model'] as String?,
			plugType: json['plug_type'] as String?,
			batteryCapacityKwh: _parseInt(json['battery_capacity_kwh']),
			plateNumber: json['plate_number'] as String?,
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'id': id,
			'user_id': userId,
			'brand': brand,
			'model': model,
			'plug_type': plugType,
			'battery_capacity_kwh': batteryCapacityKwh,
			'plate_number': plateNumber,
		};
	}

	VehicleModel copyWith({
		String? id,
		String? userId,
		String? brand,
		String? model,
		String? plugType,
		int? batteryCapacityKwh,
		String? plateNumber,
	}) {
		return VehicleModel(
			id: id ?? this.id,
			userId: userId ?? this.userId,
			brand: brand ?? this.brand,
			model: model ?? this.model,
			plugType: plugType ?? this.plugType,
			batteryCapacityKwh: batteryCapacityKwh ?? this.batteryCapacityKwh,
			plateNumber: plateNumber ?? this.plateNumber,
		);
	}

	static int? _parseInt(dynamic value) {
		if (value == null) return null;
		if (value is int) return value;
		return int.tryParse(value.toString());
	}
}