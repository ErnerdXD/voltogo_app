class SlotModel {
	const SlotModel({
		required this.id,
		required this.stationsId,
		this.slotCode,
		this.connectorType,
		this.pricePerKwh,
		this.status,
	});

	final String id;
	final String stationsId;
	final String? slotCode;
	final String? connectorType;
	final double? pricePerKwh;
	final String? status;

	factory SlotModel.fromJson(Map<String, dynamic> json) {
		return SlotModel(
			id: (json['id'] ?? '').toString(),
			stationsId: (json['stations_id'] ?? '').toString(),
			slotCode: json['slot_code'] as String?,
			connectorType: json['connector_type'] as String?,
			pricePerKwh: _parseDouble(json['price_per_kwh']),
			status: json['status'] as String?,
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'id': id,
			'stations_id': stationsId,
			'slot_code': slotCode,
			'connector_type': connectorType,
			'price_per_kwh': pricePerKwh,
			'status': status,
		};
	}

	SlotModel copyWith({
		String? id,
		String? stationsId,
		String? slotCode,
		String? connectorType,
		double? pricePerKwh,
		String? status,
	}) {
		return SlotModel(
			id: id ?? this.id,
			stationsId: stationsId ?? this.stationsId,
			slotCode: slotCode ?? this.slotCode,
			connectorType: connectorType ?? this.connectorType,
			pricePerKwh: pricePerKwh ?? this.pricePerKwh,
			status: status ?? this.status,
		);
	}

	static double? _parseDouble(dynamic value) {
		if (value == null) return null;
		if (value is double) return value;
		if (value is int) return value.toDouble();
		return double.tryParse(value.toString());
	}
}