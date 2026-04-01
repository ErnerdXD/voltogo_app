class PaymentModel {
  const PaymentModel({
	required this.id,
	required this.reservationId,
	this.userId,
	this.amount,
	this.energyKwh,
	this.status,
	this.paidAt,
  });

  final String id;
  final String reservationId;
  final String? userId;
  final double? amount;
  final double? energyKwh;
  final String? status;
  final DateTime? paidAt;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
	return PaymentModel(
	  id: (json['id'] ?? '').toString(),
	  reservationId: (json['reservation_id'] ?? '').toString(),
	  userId: json['user_id']?.toString(),
	  amount: _parseDouble(json['amount']),
	  energyKwh: _parseDouble(json['energy_kwh']),
	  status: json['status'] as String?,
	  paidAt: _parseDateTime(json['paid_at']),
	);
  }

  Map<String, dynamic> toJson() {
	return {
	  'id': id,
	  'reservation_id': reservationId,
	  'user_id': userId,
	  'amount': amount,
	  'energy_kwh': energyKwh,
	  'status': status,
	  'paid_at': paidAt?.toIso8601String(),
	};
  }

  PaymentModel copyWith({
	String? id,
	String? reservationId,
	String? userId,
	double? amount,
	double? energyKwh,
	String? status,
	DateTime? paidAt,
  }) {
	return PaymentModel(
	  id: id ?? this.id,
	  reservationId: reservationId ?? this.reservationId,
	  userId: userId ?? this.userId,
	  amount: amount ?? this.amount,
	  energyKwh: energyKwh ?? this.energyKwh,
	  status: status ?? this.status,
	  paidAt: paidAt ?? this.paidAt,
	);
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
