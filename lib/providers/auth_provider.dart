import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/models/profile_model.dart';
import 'package:voltogo_app/services/supabase_service.dart';

/// Provides the current Supabase User
final authUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

/// Provides the stream of Auth State changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// A StateNotifier to manage the Profile of the logged-in user
class ProfileNotifier extends StateNotifier<AsyncValue<ProfileModel?>> {
  final SupabaseService _service;

  ProfileNotifier(this._service) : super(const AsyncValue.loading()) {
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    state = const AsyncValue.loading();
    try {
      // A single fetch is enough. If it's null, the UI handles it.
      final profile = await _service.getProfile();
      state = AsyncValue.data(profile);
    } catch (e) {
      print('[ProfileNotifier] Error: $e');
      state = const AsyncValue.data(null);
    }
  }

  Future<void> updateProfile({
    required String fullName,
    String? phone,
    String? avatarUrl,
    String? paymentMethod,
  }) async {
    try {
      print('[ProfileNotifier] Starting profile update...');
      final updatedProfile = await _service.updateProfile(
        fullName: fullName,
        phone: phone,
        avatarUrl: avatarUrl,
        paymentMethod: paymentMethod,
      );
      print('[ProfileNotifier] Update complete, updated profile: $updatedProfile');
      if (updatedProfile != null) {
        state = AsyncValue.data(updatedProfile);
        print('[ProfileNotifier] State updated with new profile');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      print('[ProfileNotifier] Refreshing profile from database...');
      final refreshedProfile = await _service.getProfile();
      print('[ProfileNotifier] Refreshed profile: $refreshedProfile');
      state = AsyncValue.data(refreshedProfile);
      print('[ProfileNotifier] Profile update flow complete!');
    } catch (e, st) {
      print('[ERROR] ProfileNotifier update failed: $e');
      print('[ERROR] Stack trace: $st');
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provides the Profile data to the UI
final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileModel?>>((ref) {
  final service = SupabaseService();
  return ProfileNotifier(service);
});
