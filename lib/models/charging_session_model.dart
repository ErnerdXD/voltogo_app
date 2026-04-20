class ChargingSessionModel {
		  const ChargingSessionModel({
			required this.id,
			required this.reservationId,
			this.checkedInAt,
			this.checkedOutAt,
			this.energyConsumedKwh,
			this.co2SavedKg,
			this.finalBattery,
		  });

		  final String id;
		  final String reservationId;
		  final DateTime? checkedInAt;
		  final DateTime? checkedOutAt;
		  final double? energyConsumedKwh;
		  final double? co2SavedKg;
		  final int? finalBattery;

	factory ChargingSessionModel.fromJson(Map<String, dynamic> json) {
					return ChargingSessionModel(
					  id: (json['id'] ?? '').toString(),
					  reservationId: (json['reservation_id'] ?? '').toString(),
					  checkedInAt: _parseDateTime(json['checked_in_at']),
					  checkedOutAt: _parseDateTime(json['checked_out_at']),
					  energyConsumedKwh: _parseDouble(json['energy_consumed_kwh']),
					  co2SavedKg: _parseDouble(json['co2_saved_kg']),
					  finalBattery: _parseInt(json['final_battery']),
					);
	}

	Map<String, dynamic> toJson() {
					return {
					  'id': id,
					  'reservation_id': reservationId,
					  'checked_in_at': checkedInAt?.toIso8601String(),
					  'checked_out_at': checkedOutAt?.toIso8601String(),
					  'energy_consumed_kwh': energyConsumedKwh,
					  'co2_saved_kg': co2SavedKg,
					  'final_battery': finalBattery,
					};
	}

	ChargingSessionModel copyWith({
					String? id,
					String? reservationId,
					DateTime? checkedInAt,
					DateTime? checkedOutAt,
					double? energyConsumedKwh,
					double? co2SavedKg,
					int? finalBattery,
				  }) {
					return ChargingSessionModel(
					  id: id ?? this.id,
					  reservationId: reservationId ?? this.reservationId,
					  checkedInAt: checkedInAt ?? this.checkedInAt,
					  checkedOutAt: checkedOutAt ?? this.checkedOutAt,
					  energyConsumedKwh: energyConsumedKwh ?? this.energyConsumedKwh,
					  co2SavedKg: co2SavedKg ?? this.co2SavedKg,
					  finalBattery: finalBattery ?? this.finalBattery,
					);
				  }
				  static int? _parseInt(dynamic value) {
					if (value == null) return null;
					if (value is int) return value;
					return int.tryParse(value.toString());
				  }

	static DateTime? _parseDateTime(dynamic value) {
		if (value == null) return null;
		return DateTime.tryParse(value.toString());
	}

	static double? _parseDouble(dynamic value) {
		if (value == null) return null;
		if (value is double) return value;
		if (value is int) return value.toDouble();
		return double.tryParse(value.toString());
	}
}