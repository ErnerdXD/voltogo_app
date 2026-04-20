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
    this.createdAt,
    this.currentBattery,
    this.cancellationReason,
    this.targetBattery,
    this.finalBattery,
  });

  final String id;
  final String userId;
  final String? slotId;
  final String? vehicleId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? status;
  final String? qrCode;
  final DateTime? createdAt;
  final int? currentBattery;
  final String? cancellationReason;
  final int? targetBattery;
  final int? finalBattery;

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
      createdAt: _parseDateTime(json['created_at']),
      currentBattery: _parseInt(json['current_battery']),
      cancellationReason: json['cancellation_reason'] as String?,
      targetBattery: _parseInt(json['target_battery']),
      finalBattery: _parseInt(json['final_battery']),
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
      'created_at': createdAt?.toIso8601String(),
      'current_battery': currentBattery,
      'cancellation_reason': cancellationReason,
      'target_battery': targetBattery,
      'final_battery': finalBattery,
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
    DateTime? createdAt,
    int? currentBattery,
    String? cancellationReason,
    int? targetBattery,
    int? finalBattery,
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
      createdAt: createdAt ?? this.createdAt,
      currentBattery: currentBattery ?? this.currentBattery,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      targetBattery: targetBattery ?? this.targetBattery,
      finalBattery: finalBattery ?? this.finalBattery,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}