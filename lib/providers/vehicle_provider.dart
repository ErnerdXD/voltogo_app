import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltogo_app/models/vehicle_model.dart';
import 'package:voltogo_app/services/supabase_service.dart';

class VehicleNotifier extends StateNotifier<AsyncValue<List<VehicleModel>>> {
  final SupabaseService _service;

  VehicleNotifier(this._service) : super(const AsyncValue.loading()) {
    fetchVehicles();
  }

  Future<void> fetchVehicles() async {
    state = const AsyncValue.loading();
    try {
      final vehicles = await _service.getVehicles();
      state = AsyncValue.data(vehicles);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addVehicle({
    required String brand,
    required String model,
    required String plateNumber,
    required String plugType,
    int? batteryCapacityKwh,
  }) async {
    try {
      await _service.addVehicle(
        brand: brand,
        model: model,
        plateNumber: plateNumber,
        plugType: plugType,
        batteryCapacityKwh: batteryCapacityKwh,
      );
      await fetchVehicles();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateVehicle(String vehicleId, Map<String, dynamic> updates) async {
    try {
      await _service.updateVehicle(vehicleId, updates);
      await fetchVehicles();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      final isReferenced = await _service.isVehicleReferencedInReservation(vehicleId);
      if (isReferenced) {
        // Don't set error state for business logic error, just throw
        throw Exception('referenced by existing reservations');
      }
      await _service.deleteVehicle(vehicleId);
      await fetchVehicles();
    } catch (e, st) {
      // Only set error state for unexpected errors
      if (!e.toString().contains('referenced by existing reservations')) {
        state = AsyncValue.error(e, st);
      }
      rethrow;
    }
  }

  void clearError() {
    if (state.hasError) {
      state = AsyncValue.data(state.value ?? []);
    }
  }
}

final vehicleProvider = StateNotifierProvider<VehicleNotifier, AsyncValue<List<VehicleModel>>>((ref) {
  final service = SupabaseService();
  return VehicleNotifier(service);
});
