// admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Controls',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _AdminMenuTile(
              icon: Icons.ev_station,
              title: 'Manage Stations',
              description: 'Add, edit, or delete charging stations',
              onTap: () => context.push('/admin/stations'),
            ),
            const SizedBox(height: 12),
            _AdminMenuTile(
              icon: Icons.bolt,  // ✅ FIXED: Changed from Icons.power_plug
              title: 'Manage Slots',
              description: 'Configure charging slots',
              onTap: () => context.push('/admin/slots'),
            ),
            const SizedBox(height: 12),
            _AdminMenuTile(
              icon: Icons.analytics,
              title: 'System Analytics',
              description: 'View app usage and statistics',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AdminMenuTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: Colors.grey[100],
      ),
    );
  }
}
