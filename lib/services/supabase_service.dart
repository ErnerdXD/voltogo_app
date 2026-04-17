// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/models/profile_model.dart';
import 'package:voltogo_app/models/vehicle_model.dart';
import 'package:voltogo_app/models/station_model.dart';

class SupabaseService {
  // Singleton pattern for the service
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // --- AUTH GETTER ---
  User? get currentUser => _client.auth.currentUser;

  // --- USER SETUP (Module 1) ---

   /// Complete user setup after signup
  Future<void> setupUserAfterSignup(User authUser, {String? fullName}) async {
    try {
      // DEBUG: Verify we are actually authenticated
      print('[DEBUG] Auth UID: ${authUser.id}');
      print('[DEBUG] Current User Session: ${_client.auth.currentSession != null}');
      print('[DEBUG] Current JWT: ${_client.auth.currentSession?.accessToken != null}');
      // Step 1: Create the record in the 'public.users' table
      // We NEED the returned 'id' to link to the profile
      final userResponse = await _client.from('users').insert({
        'auth_user_id': authUser.id,
        'role': 'member',
      }).select('id').single();

      final String publicId = userResponse['id'];
      print('[DEBUG] Public User ID Created: $publicId');

      // Step 2: Create the profile using the PUBLIC ID, not the Auth ID
      await _client.from('profiles').insert({
        'user_id': publicId,
        'full_name': fullName ?? authUser.email?.split('@')[0] ?? 'User',
        'email': _client.auth.currentUser?.email,
      });

      print('[SupabaseService] Setup complete for: $publicId');
    } catch (e) {
      print('[SupabaseService] Setup Error: $e');
      rethrow;
    }
  }

  // --- PROFILE CRUD (Module 1) ---

  /// Read: Fetch current user's profile
  Future<ProfileModel?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {// Direct Join: Get the profile where the linked user has the current auth_id
      // This is the most efficient way to query in Supabase
      final response = await _client
          .from('profiles')
          .select('*, users!inner(auth_user_id)')
          .eq('users.auth_user_id', user.id)
          .maybeSingle();

      if (response == null) {
        print('[SupabaseService] No profile found for auth_id: ${user.id}');
        return null;
      }

      return ProfileModel.fromJson(response);
    } catch (e) {
      print('[SupabaseService] Error fetching profile: $e');
      return null;
    }
  }

  Future<ProfileModel?> updateProfile({
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      // 1. Get the profile id first
      final profile = await getProfile();
      if (profile == null) throw Exception('Profile not found. Please re-login.');

      // 2. Perform the update using the profile's primary key (id)
      final response = await _client
          .from('profiles')
          .update({
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
      })
          .eq('id', profile.id)
          .select()
          .single();

      return ProfileModel.fromJson(response);
    } catch (e) {
      print('[SupabaseService] updateProfile failed: $e');
      rethrow;
    }
  }

  // --- VEHICLE CRUD (Module 1) ---

  /// Read: Fetch all vehicles for the current user
  Future<List<VehicleModel>> getVehicles() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('vehicles')
          .select('*, users!inner(auth_user_id)')
          .eq('users.auth_user_id', user.id);

      return (response as List)
          .map((json) => VehicleModel.fromJson(json))
          .toList();
    } catch (e) {
      print('[SupabaseService] Error fetching vehicles: $e');
      return [];
    }
  }

  /// Create: Add a new EV
  Future<void> addVehicle({
    required String brand,
    required String model,
    required String plateNumber,
    required String plugType,
    int? batteryCapacityKwh,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      // Find our public.users.id first
      final userRecord = await _client
          .from('users')
          .select('id')
          .eq('auth_user_id', user.id)
          .single();

      await _client.from('vehicles').insert({
        'user_id': userRecord['id'],
        'brand': brand,
        'model': model,
        'plate_number': plateNumber,
        'plug_type': plugType,
        'battery_capacity_kwh': batteryCapacityKwh,
      });
    } catch (e) {
      print('[SupabaseService] Error adding vehicle: $e');
      throw Exception('Failed to add vehicle: $e');
    }
  }

  /// Update: Edit vehicle details
  Future<void> updateVehicle(String vehicleId, Map<String, dynamic> updates) async {
    await _client
        .from('vehicles')
        .update(updates)
        .eq('id', vehicleId);
  }

  /// Delete: Remove a vehicle
  Future<void> deleteVehicle(String vehicleId) async {
    await _client
        .from('vehicles')
        .delete()
        .eq('id', vehicleId);
  }

  // --- STATION CRUD (Module 2) ---

  /// Read: Fetch all stations
  Future<List<StationModel>> getStations() async {
    try {
      // This fetches stations AND their related slots using Supabase's join syntax
      final response = await _client
          .from('stations')
          .select('*, slots(*)');

      return (response as List).map((json) {
        // Map the station data
        final station = StationModel.fromJson(json);
        // You can also map the 'slots' list here if you add a List<SlotModel>
        // field to your StationModel
        return station;
      }).toList();
    } catch (e) {
      print('[SupabaseService] Error fetching stations: $e');
      return [];
    }
  }
}
