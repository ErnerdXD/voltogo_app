import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/models/user_model.dart';

/// Provides the current app user record from the users table
class UserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  UserNotifier() : super(const AsyncValue.loading()) {
    fetchUser();
  }

  Future<void> fetchUser() async {
    state = const AsyncValue.loading();
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      // We use maybeSingle() because new users might not have a record yet
      // during the first few milliseconds of registration.
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('auth_user_id', authUser.id)
          .maybeSingle();

      if (data == null) {
        state = const AsyncValue.data(null);
        return;
      }

      state = AsyncValue.data(UserModel.fromJson(data));
    } catch (e, st) {
      // If there's an error (like RLS blocking), we show it clearly
      print('[UserNotifier] Error fetching user record: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final userProvider =
    StateNotifierProvider<UserNotifier, AsyncValue<UserModel?>>((ref) {
  return UserNotifier();
});






