class ReservationModel {
  const ReservationModel({
	required this.id,
	required this.userId,
	this.slotId,
	this.vehicleId,
	this.startTime,
	this.endTime,
	this.status,
	this.qrCode,
  });

  final String id;
  final String userId;
  final String? slotId;
  final String? vehicleId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? status;
  final String? qrCode;

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
	return ReservationModel(
	  id: (json['id'] ?? '').toString(),
	  userId: (json['user_id'] ?? '').toString(),
	  slotId: json['slot_id']?.toString(),
	  vehicleId: json['vehicle_id']?.toString(),
	  startTime: _parseDateTime(json['start_time']),
	  endTime: _parseDateTime(json['end_time']),
	  status: json['status'] as String?,
	  qrCode: json['qr_code'] as String?,
	);
  }

  Map<String, dynamic> toJson() {
	return {
	  'id': id,
	  'user_id': userId,
	  'slot_id': slotId,
	  'vehicle_id': vehicleId,
	  'start_time': startTime?.toIso8601String(),
	  'end_time': endTime?.toIso8601String(),
	  'status': status,
	  'qr_code': qrCode,
	};
  }

  ReservationModel copyWith({
	String? id,
	String? userId,
	String? slotId,
	String? vehicleId,
	DateTime? startTime,
	DateTime? endTime,
	String? status,
	String? qrCode,
  }) {
	return ReservationModel(
	  id: id ?? this.id,
	  userId: userId ?? this.userId,
	  slotId: slotId ?? this.slotId,
	  vehicleId: vehicleId ?? this.vehicleId,
	  startTime: startTime ?? this.startTime,
	  endTime: endTime ?? this.endTime,
	  status: status ?? this.status,
	  qrCode: qrCode ?? this.qrCode,
	);
  }

  static DateTime? _parseDateTime(dynamic value) {
	if (value == null) return null;
	return DateTime.tryParse(value.toString());
  }
}
