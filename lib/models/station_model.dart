import 'package:voltogo_app/models/slot_model.dart';

class StationModel {
  const StationModel({
	required this.id,
	this.externalId,
	this.name,
	this.address,
	this.latitude,
	this.longitude,
	this.totalSlots,
	this.status,
	this.createdBy,
	this.slots,
  });

  final String id;
  final String? externalId;
  final String? name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? totalSlots;
  final String? status;
  final String? createdBy;
  final List<SlotModel>? slots;

  factory StationModel.fromJson(Map<String, dynamic> json) {
	return StationModel(
	  id: (json['id'] ?? '').toString(),
	  externalId: json['external_id'] as String?,
	  name: json['name'] as String?,
	  address: json['address'] as String?,
	  latitude: _parseDouble(json['latitude']),
	  longitude: _parseDouble(json['longitude']),
	  totalSlots: _parseInt(json['total_slots']),
	  status: json['status'] as String?,
	  createdBy: json['created_by']?.toString(),
	  slots: (json['slots'] as List?)?.map((e) => SlotModel.fromJson(e as Map<String, dynamic>)).toList(),
	);
  }

  Map<String, dynamic> toJson() {
	return {
	  'id': id,
	  'external_id': externalId,
	  'name': name,
	  'address': address,
	  'latitude': latitude,
	  'longitude': longitude,
	  'total_slots': totalSlots,
	  'status': status,
	  'created_by': createdBy,
	  'slots': slots?.map((e) => e.toJson()).toList(),
	};
  }

  StationModel copyWith({
	String? id,
	String? externalId,
	String? name,
	String? address,
	double? latitude,
	double? longitude,
	int? totalSlots,
	String? status,
	String? createdBy,
	List<SlotModel>? slots,
  }) {
	return StationModel(
	  id: id ?? this.id,
	  externalId: externalId ?? this.externalId,
	  name: name ?? this.name,
	  address: address ?? this.address,
	  latitude: latitude ?? this.latitude,
	  longitude: longitude ?? this.longitude,
	  totalSlots: totalSlots ?? this.totalSlots,
	  status: status ?? this.status,
	  createdBy: createdBy ?? this.createdBy,
	  slots: slots ?? this.slots,
	);
  }

  static int? _parseInt(dynamic value) {
	if (value == null) return null;
	if (value is int) return value;
	return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
	if (value == null) return null;
	if (value is double) return value;
	if (value is int) return value.toDouble();
	return double.tryParse(value.toString());
  }
}
