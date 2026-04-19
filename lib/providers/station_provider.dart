import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltogo_app/models/station_model.dart';
import 'package:voltogo_app/services/supabase_service.dart';

class StationsNotifier extends StateNotifier<AsyncValue<List<StationModel>>> {
  StationsNotifier() : super(const AsyncValue.loading()) {
    fetchStations();
  }

  Future<void> fetchStations() async {
    state = const AsyncValue.loading();
    try {
      final stations = await SupabaseService().getStations();
      state = AsyncValue.data(stations);
    } catch (e, st) {
      print('[StationsNotifier] Error: $e');
      state = AsyncValue.error(e, st);
    }
  }

// We will add createStation(), updateStation(), and deleteStation() here next!
}

final stationsProvider = StateNotifierProvider<StationsNotifier, AsyncValue<List<StationModel>>>((ref) {
  return StationsNotifier();
});