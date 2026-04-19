class PaymentModel {
  const PaymentModel({
	required this.id,
	required this.reservationId,
	this.userId,
	this.amount,
	this.energyKwh,
	this.status,
	this.paidAt,
	this.stripePaymentIntentId,
	this.stripeCustomerId,
	this.paymentMethodType,
	this.paymentMethodLast4,
  });

  final String id;
  final String reservationId;
  final String? userId;
  final double? amount;
  final double? energyKwh;
  final String? status;
  final DateTime? paidAt;
  final String? stripePaymentIntentId;
  final String? stripeCustomerId;
  final String? paymentMethodType;
  final String? paymentMethodLast4;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
	return PaymentModel(
	  id: (json['id'] ?? '').toString(),
	  reservationId: (json['reservation_id'] ?? '').toString(),
	  userId: json['user_id']?.toString(),
	  amount: _parseDouble(json['amount']),
	  energyKwh: _parseDouble(json['energy_kwh']),
	  status: json['status'] as String?,
	  paidAt: _parseDateTime(json['paid_at']),
	  stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
	  stripeCustomerId: json['stripe_customer_id'] as String?,
	  paymentMethodType: json['payment_method_type'] as String?,
	  paymentMethodLast4: json['payment_method_last4'] as String?,
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
	  'stripe_payment_intent_id': stripePaymentIntentId,
	  'stripe_customer_id': stripeCustomerId,
	  'payment_method_type': paymentMethodType,
	  'payment_method_last4': paymentMethodLast4,
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
	String? stripePaymentIntentId,
	String? stripeCustomerId,
	String? paymentMethodType,
	String? paymentMethodLast4,
  }) {
	return PaymentModel(
	  id: id ?? this.id,
	  reservationId: reservationId ?? this.reservationId,
	  userId: userId ?? this.userId,
	  amount: amount ?? this.amount,
	  energyKwh: energyKwh ?? this.energyKwh,
	  status: status ?? this.status,
	  paidAt: paidAt ?? this.paidAt,
	  stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
	  stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
	  paymentMethodType: paymentMethodType ?? this.paymentMethodType,
	  paymentMethodLast4: paymentMethodLast4 ?? this.paymentMethodLast4,
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
