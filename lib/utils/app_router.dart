import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/models/vehicle_model.dart';
import 'package:voltogo_app/screens/splash/splash_screen.dart';
import 'package:voltogo_app/screens/auth/login_screen.dart';
import 'package:voltogo_app/screens/auth/register_screen.dart';
import 'package:voltogo_app/screens/discovery/map_screen.dart';
import 'package:voltogo_app/screens/reservation/activity_screen.dart';
import 'package:voltogo_app/screens/payment/dashboard_screen.dart';
import 'package:voltogo_app/screens/payment/payment_method_screen.dart';
import 'package:voltogo_app/screens/user/profile_screen.dart';
import 'package:voltogo_app/screens/user/edit_profile_screen.dart';
import 'package:voltogo_app/screens/user/vehicles_screen.dart';
import 'package:voltogo_app/screens/user/add_vehicle_screen.dart';
import 'package:voltogo_app/screens/user/edit_vehicle_screen.dart';
import 'package:voltogo_app/screens/main_shell.dart';
import 'package:voltogo_app/screens/reservation/reservation_screen.dart';
import 'package:voltogo_app/screens/admin/admin_dashboard_screen.dart';
import 'package:voltogo_app/screens/admin/manage_stations_screen.dart';
import 'package:voltogo_app/screens/admin/manage_slots_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) async {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
    final isSplash = state.matchedLocation == '/';

    // If no session and not on auth/splash pages, go to login
    if (session == null && !isLoggingIn && !isSplash) {
      return '/login';
    }

    // Inside the redirect logic for orphaned sessions
    if (session != null && !isLoggingIn && !isSplash) {
      try {
        // We add a 3-second timeout to prevent the router from hanging
        final userRecord = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('auth_user_id', session.user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));

        if (userRecord == null) {
          debugPrint('[Router] Orphaned session detected. Signing out...');
          await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
          return '/login';
        }
      } catch (e) {
        // If the DB check fails (e.g., Timeout or Rate Limit),
        // we let them through to the app rather than kicking them out.
        debugPrint('[Router] DB Check bypassed (Rate limit/Slow): $e');
      }
    }
    // <caret> is here - we move to the next logic blocks

    // If on splash screen with valid session, go to map
    if (session != null && isSplash) {
      return '/map';
    }

    // If session exists and on auth page, redirect to main app
    if (session != null && isLoggingIn) {
      return '/map';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AnimatedSplashScreenWidget(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
      routes: [
        GoRoute(
          path: 'stations',
          builder: (context, state) => const ManageStationsScreen(),
        ),
        GoRoute(
          path: 'slots',
          builder: (context, state) => const ManageSlotsScreen(),
        ),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const MapScreen(title: 'VoltoGo'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/activity',
              builder: (context, state) => const ActivityScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stats',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: 'vehicles',
                  builder: (context, state) => const VehiclesScreen(),
                  routes: [
                    GoRoute(
                      path: 'add',
                      builder: (context, state) => const AddVehicleScreen(),
                    ),
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) {
                        final extra = state.extra as VehicleModel?;
                        if (extra == null) {
                          return const Scaffold(
                            body: Center(child: Text('No vehicle provided')),
                          );
                        }
                        return EditVehicleScreen(vehicle: extra);
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'payment-method',
                  builder: (context, state) => const PaymentMethodScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reservation',
              builder: (context, state) => const ReservationScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
