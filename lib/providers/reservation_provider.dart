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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<ReservationModel?> createReservation({
    required String slotId,
    required String vehicleId,
    required DateTime startTime,
    required DateTime endTime,
    required int? currentBattery, // Accept nullable, but pass non-nullable
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
        currentBattery: currentBattery, // Now non-nullable
      );
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
}

final reservationProvider =
StateNotifierProvider<ReservationNotifier, ReservationState>((ref) {
  return ReservationNotifier();
});