// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/models/profile_model.dart';
import 'package:voltogo_app/models/vehicle_model.dart';
import 'package:voltogo_app/models/station_model.dart';
import 'package:voltogo_app/models/reservation_model.dart';
import 'package:voltogo_app/models/payment_model.dart';

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

      // Step 1: Create the record in the 'public.users' table
      final userResponse = await _client.from('users').upsert(
        {
          'auth_user_id': authUser.id,
          'role': 'member',
        },
        onConflict: 'auth_user_id', // Tells it to look for our UNIQUE lock!
      ).select('id').single();

      final String publicId = userResponse['id'];
      print('[DEBUG] Public User ID Created/Found: $publicId');

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
    String? paymentMethod,
    String? stripePaymentMethodId,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      // 1. Get the profile id first
      final profile = await getProfile();
      if (profile == null) throw Exception('Profile not found. Please re-login.');

      // 2. Perform the update using the profile's primary key (id)
      final updateData = {
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
      };
      if (paymentMethod != null) {
        updateData['payment_method'] = paymentMethod;
      }
      if (stripePaymentMethodId != null) {
        updateData['stripe_payment_method_id'] = stripePaymentMethodId;
      }
      final response = await _client
          .from('profiles')
          .update(updateData)
          .eq('id', profile.id)
          .select()
          .maybeSingle();

      if (response == null) throw Exception('Failed to update profile.');

      return ProfileModel.fromJson(response);
    } catch (e) {
      print('[SupabaseService] updateProfile failed: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount(String publicUserId) async {
    try {
      final activeReservations = await _client
          .from('reservations')
          .select('id')
          .eq('user_id', publicUserId)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .limit(1);

      if (activeReservations.isNotEmpty) {
        throw Exception(
            'Account cannot be deleted. You have active or unpaid reservations. '
                'Please complete or cancel them first.'
        );
      }

      // 1. Delete all vehicles
      await _client
          .from('vehicles')
          .delete()
          .eq('user_id', publicUserId);

      // 2. Scramble Profile (Anonymization)
      await _client
          .from('profiles')
          .update({
        'full_name': 'Deleted User',
        'phone': null,
        'email': null,
        'payment_method': null,
        'stripe_payment_method_id': null,
        'avatar_url': null,
      })
          .eq('user_id', publicUserId);

      // 3. Mark the user as deleted (Soft-Delete)
      await _client
          .from('users')
          .update({'is_deleted': true})
          .eq('id', publicUserId);

    } catch (e) {
      print('[SupabaseService] Error in soft delete: $e');
      // We want to pass the specific reservation error message directly to the user!
      if (e is Exception && e.toString().contains('Account cannot be deleted')) {
        rethrow;
      }
      throw Exception('Failed to delete account data.');
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

  /// Fetches the list of EV Models from the dataset for the dropdown
  Future<List<Map<String, dynamic>>> getEvModels() async {
    try {
      final response = await _client
          .from('ev_models')
          .select()
          .order('brand', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch EV models: $e');
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
      final userRecords = await _client
          .from('users')
          .select('id')
          .eq('auth_user_id', user.id);

      if ((userRecords as List).isEmpty) {
        throw Exception('User record not found');
      }
      
      final userId = userRecords[0]['id'];

      await _client.from('vehicles').insert({
        'user_id': userId,
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

  // --- RESERVATION CRUD (Module 3) ---

  /// Fetch all reservations for the current user
  Future<List<ReservationModel>> getUserReservations() async {
    final user = currentUser;
    if (user == null) {
      print('[SupabaseService] No current user logged in.');
      return [];
    }
    try {
      print('[SupabaseService] Current auth user id: \\${user.id}');
      // Get the user's public.users.id
      final userRecords = await _client
          .from('users')
          .select('id')
          .eq('auth_user_id', user.id);
      print('[SupabaseService] userRecords: \\${userRecords}');
      if ((userRecords as List).isEmpty) {
        print('[SupabaseService] No user record found for auth_user_id=\\${user.id}');
        return [];
      }
      final userId = userRecords[0]['id'];
      print('[SupabaseService] Using userId for reservations: \\${userId}');
      final response = await _client
          .from('reservations')
          .select('*')
          .eq('user_id', userId)
          .order('start_time', ascending: false);
      print('[SupabaseService] Raw reservations response: \\${response}');
      return (response as List)
          .map((json) => ReservationModel.fromJson(json))
          .toList();
    } catch (e) {
      print('[SupabaseService] Error fetching reservations: $e');
      return [];
    }
  }

  /// Create a new reservation
  Future<void> createReservation({
    required String slotId,
    required String vehicleId,
    required DateTime startTime,
    required DateTime endTime,
    required int currentBattery, // Add this parameter
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');
    try {
      // Get the user's public.users.id
      final userRecords = await _client
          .from('users')
          .select('id')
          .eq('auth_user_id', user.id);
          
      if ((userRecords as List).isEmpty) throw Exception('User record not found');
      
      final userId = userRecords[0]['id'];
      await _client.from('reservations').insert({
        'user_id': userId,
        'slot_id': slotId,
        'vehicle_id': vehicleId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'status': 'to pay',
        'current_battery': currentBattery, // Store battery
      });
    } catch (e) {
      print('[SupabaseService] Error creating reservation: $e');
      throw Exception('Failed to create reservation: $e');
    }
  }

  /// Cancel a reservation (set status to 'cancelled')
  Future<void> cancelReservation(String reservationId) async {
    try {
      await _client
          .from('reservations')
          .update({'status': 'cancelled'})
          .eq('id', reservationId);
    } catch (e) {
      print('[SupabaseService] Error cancelling reservation: $e');
      throw Exception('Failed to cancel reservation: $e');
    }
  }

  /// Delete a reservation permanently (e.g. if expired)
  Future<void> deleteReservation(String reservationId) async {
    try {
      await _client
          .from('reservations')
          .delete()
          .eq('id', reservationId);
    } catch (e) {
      print('[SupabaseService] Error deleting reservation: $e');
      throw Exception('Failed to delete reservation: $e');
    }
  }

  /// Update the status of a reservation (e.g., 'completed', 'cancelled')
  Future<void> updateReservationStatus(String reservationId, String status) async {
    try {
      await _client.from('reservations').update({'status': status}).eq('id', reservationId);
    } catch (e) {
      print('[SupabaseService] Error updating reservation status: $e');
      throw Exception('Failed to update reservation status: $e');
    }
  }

  // --- PAYMENT CRUD (Module 4) ---

  /// Create a new payment
  Future<void> createPayment({
    required String reservationId,
    String? userId,
    double? amount,
    double? energyKwh,
    String? status,
    DateTime? paidAt,
    String? stripePaymentIntentId,
    String? stripeCustomerId,
    String? paymentMethodType,
    String? paymentMethodLast4,
  }) async {
    try {
      await _client.from('payments').insert({
        'reservation_id': reservationId,
        'user_id': userId,
        'amount': amount,
        'energy_kwh': energyKwh,
        'status': status,
        'paid_at': paidAt?.toIso8601String(),
        'stripe_payment_intent_id': stripePaymentIntentId,
        'stripe_customer_id': stripeCustomerId,
        'payment_method_type': paymentMethodType,
        'payment_method_last4': paymentMethodLast4,
      });
    } catch (e) {
      print('[SupabaseService] Error creating payment: $e');
      throw Exception('Failed to create payment: $e');
    }
  }

  /// Update an existing payment
  Future<void> updatePayment({
    required String paymentId,
    double? amount,
    double? energyKwh,
    String? status,
    DateTime? paidAt,
    String? stripePaymentIntentId,
    String? stripeCustomerId,
    String? paymentMethodType,
    String? paymentMethodLast4,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (amount != null) updateData['amount'] = amount;
      if (energyKwh != null) updateData['energy_kwh'] = energyKwh;
      if (status != null) updateData['status'] = status;
      if (paidAt != null) updateData['paid_at'] = paidAt.toIso8601String();
      if (stripePaymentIntentId != null) updateData['stripe_payment_intent_id'] = stripePaymentIntentId;
      if (stripeCustomerId != null) updateData['stripe_customer_id'] = stripeCustomerId;
      if (paymentMethodType != null) updateData['payment_method_type'] = paymentMethodType;
      if (paymentMethodLast4 != null) updateData['payment_method_last4'] = paymentMethodLast4;
      await _client.from('payments').update(updateData).eq('id', paymentId);
    } catch (e) {
      print('[SupabaseService] Error updating payment: $e');
      throw Exception('Failed to update payment: $e');
    }
  }

  /// Fetch all payments for the current user
  Future<List<PaymentModel>> getPaymentsForUser() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      // Get the user's public.users.id
      final userRecords = await _client
          .from('users')
          .select('id')
          .eq('auth_user_id', user.id);
      
      if ((userRecords as List).isEmpty) return [];
      
      final userId = userRecords[0]['id'];
      final response = await _client
          .from('payments')
          .select('*')
          .eq('user_id', userId)
          .order('paid_at', ascending: false);
      return (response as List)
          .map((json) => PaymentModel.fromJson(json))
          .toList();
    } catch (e) {
      print('[SupabaseService] Error fetching payments: $e');
      return [];
    }
  }
}
