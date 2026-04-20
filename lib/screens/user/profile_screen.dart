import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final authUser = ref.watch(authUserProvider);
    final themeMode = ref.watch(themeProvider);
    final userAsync = ref.watch(userProvider);

    // --- THE FIX: Detect Dark Mode ---
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: profileAsync.when(
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- HEADER CARD ---
              Card(
                elevation: isDark ? 0 : 4,
                shadowColor: Colors.black12,
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50],
                            child: profile?.avatarUrl != null
                                ? ClipOval(child: Image.network(profile!.avatarUrl!, fit: BoxFit.cover, width: 100, height: 100))
                                : Icon(Icons.person, size: 50, color: isDark ? Colors.blue[400] : Colors.blue[300]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile?.fullName?.isNotEmpty == true ? profile!.fullName! : 'Welcome, Driver',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(authUser?.email ?? '', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      if (profile?.phone?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(profile!.phone!, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- ADMIN DASHBOARD BUTTON ---
              if (userAsync.value?.role == 'admin') ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.indigo[400] : Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.dashboard_customize),
                    label: const Text('Admin Console', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () => context.go('/admin'),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // --- SETTINGS MENU ---
              Card(
                elevation: isDark ? 0 : 2,
                shadowColor: Colors.black12,
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profile',
                      isDark: isDark,
                      onTap: () => context.push('/profile/edit'),
                    ),
                    Divider(height: 1, indent: 56, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    _MenuTile(
                      icon: Icons.directions_car_outlined,
                      title: 'My Garage',
                      isDark: isDark,
                      onTap: () => context.push('/profile/vehicles'),
                    ),
                    Divider(height: 1, indent: 56, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    _MenuTile(
                      icon: themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      title: themeMode == ThemeMode.dark ? 'Light Mode' : 'Dark Mode',
                      isDark: isDark,
                      onTap: () => ref.read(themeProvider.notifier).state = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- LOGOUT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    ref.invalidate(profileProvider);
                    ref.invalidate(userProvider);
                    ref.invalidate(authUserProvider);
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.red[400] : Colors.red,
                    side: BorderSide(color: isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- THE FIX: Rounded Logo Footer ---
              Opacity(
                opacity: isDark ? 0.8 : 0.5,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16), // Fixes the ugly square
                      child: Image.asset('assets/branding/voltogo_icon.png', width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 12),
                    Text('VoltoGo v1.0.0', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey[800])),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

// Custom widget for sleek menu items
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.title, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: isDark ? Colors.blue[400] : Colors.blue[700]),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.grey[200] : Colors.black87)),
      trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey[600] : Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: onTap,
    );
  }
}