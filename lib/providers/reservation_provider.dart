// reservation_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reservation_model.dart';
import '../services/supabase_service.dart';

class ReservationState {
  final List<ReservationModel> reservations;
  final bool isLoading;
  final String? error;

  const ReservationState({
    this.reservations = const [],
    this.isLoading = false,
    this.error,
  });

  ReservationState copyWith({
    List<ReservationModel>? reservations,
    bool? isLoading,
    String? error,
  }) {
    return ReservationState(
      reservations: reservations ?? this.reservations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ReservationNotifier extends StateNotifier<ReservationState> {
  final SupabaseService _service = SupabaseService();

  ReservationNotifier() : super(const ReservationState());

  Future<void> fetchReservations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final reservations = await _service.getUserReservations();
      state = state.copyWith(reservations: reservations, isLoading: false);
      await _expireOldReservations();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _expireOldReservations() async {
    final now = DateTime.now();
    final List<ReservationModel> toExpire = [];
    for (final r in state.reservations) {
      if ((r.status == 'active' || r.status == 'to pay') &&
          r.endTime != null &&
          r.endTime!.isBefore(now)) {
        toExpire.add(r);
      }
    }
    for (final res in toExpire) {
      try {
        await _service.updateReservationStatus(res.id, 'expired');
        // Decrement station availability on session end
        if (res.slotId != null) {
          final slot = await _service.getSlotById(res.slotId!);
          if (slot != null) {
            await _service.decrementStationAvailability(slot.stationsId);
            // Mark slot as available again
            await _service.releaseSlot(slot.id);
          }
        }
      } catch (e) {
        print('[ReservationNotifier] Error expiring reservation ${res.id}: $e');
      }
    }
    if (toExpire.isNotEmpty) {
      await fetchReservations();
    }
  }

  Future<ReservationModel?> createReservation({
    required String slotId,
    required String vehicleId,
    required DateTime startTime,
    required DateTime endTime,
    required int? currentBattery,
    required int targetBattery,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (currentBattery == null) {
        throw Exception('Current battery cannot be null');
      }
      final reservation = await _service.createReservation(
        slotId: slotId,
        vehicleId: vehicleId,
        startTime: startTime,
        endTime: endTime,
        currentBattery: currentBattery,
        targetBattery: targetBattery,
      );
      if (reservation != null && reservation.slotId != null) {
        try {
          final slot = await _service.getSlotById(reservation.slotId!);
          if (slot != null) {
            await _service.decrementStationAvailability(slot.stationsId);
            // Mark slot as occupied
            await _service.occupySlot(slot.id);
          }
        } catch (e) {
          print('[ReservationNotifier] Error decrementing station availability or occupying slot: $e');
        }
      }
      await fetchReservations();
      return reservation;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> cancelReservation(String reservationId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.cancelReservation(reservationId);
      await fetchReservations();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> completeReservation(String reservationId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedList = state.reservations.map((r) {
        if (r.id == reservationId) return r.copyWith(status: 'paid');
        return r;
      }).toList();
      state = state.copyWith(reservations: updatedList, isLoading: false);
      await _service.updateReservationStatus(reservationId, 'paid');
      await fetchReservations();
    } catch (e) {
      try { await fetchReservations(); } catch (_) {}
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<ReservationModel> get activeReservations => state.reservations
      .where((r) => r.status == 'to pay' || r.status == 'active')
      .toList();

  List<ReservationModel> get expiredReservations => state.reservations
      .where((r) => r.status == 'expired')
      .toList();

  List<ReservationModel> get previousReservations => state.reservations
      .where((r) => r.status == 'completed' || r.status == 'cancelled')
      .toList();

  int get activeReservationCount => activeReservations.length;
}

final reservationProvider =
StateNotifierProvider<ReservationNotifier, ReservationState>((ref) {
  return ReservationNotifier();
});