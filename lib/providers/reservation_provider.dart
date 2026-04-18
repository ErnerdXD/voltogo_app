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
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.createReservation(
        slotId: slotId,
        vehicleId: vehicleId,
        startTime: startTime,
        endTime: endTime,
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
}

final reservationProvider = StateNotifierProvider<ReservationNotifier, ReservationState>((ref) {
  return ReservationNotifier();
});

