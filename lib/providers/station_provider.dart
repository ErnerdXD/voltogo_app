import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltogo_app/models/station_model.dart';
import 'package:voltogo_app/services/supabase_service.dart';

final stationsProvider = FutureProvider<List<StationModel>>((ref) async {
  final service = SupabaseService();
  return service.getStations();
});
