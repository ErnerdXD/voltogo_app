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
      state = state.copyWith(reservations: reservations, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createReservation({
    required String slotId,
    required String vehicleId,
    required DateTime startTime,
    required DateTime endTime,
    required int currentBattery, // Add this parameter
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.createReservation(
        slotId: slotId,
        vehicleId: vehicleId,
        startTime: startTime,
        endTime: endTime,
        currentBattery: currentBattery, // Pass battery
      );
      await fetchReservations();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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

  /// Mark a reservation as completed (used after successful payment)
  Future<void> completeReservation(String reservationId) async {
    state = state.copyWith(isLoading: true, error: null);
    // Optimistic update: mark locally as completed so UI updates immediately
    try {
      final updatedList = state.reservations.map((r) {
        // After payment succeeds we mark the reservation as 'paid' so it remains
        // in the active reservations list (and shows QR / View Details).
        if (r.id == reservationId) return r.copyWith(status: 'paid');
        return r;
      }).toList();
      state = state.copyWith(reservations: updatedList, isLoading: false);

      // Persist change on server and refresh
      await _service.updateReservationStatus(reservationId, 'paid');
      await fetchReservations();
    } catch (e) {
      // Revert optimistic update on error
      try {
        await fetchReservations();
      } catch (_) {}
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final reservationProvider = StateNotifierProvider<ReservationNotifier, ReservationState>((ref) {
  return ReservationNotifier();
});
