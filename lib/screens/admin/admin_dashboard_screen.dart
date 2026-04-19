import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- THE LIVE METRICS PROVIDER ---
// This safely counts how many rows exist in your tables without downloading all the data
final adminMetricsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final client = Supabase.instance.client;

  // Fetch total stations
  final stations = await client.from('stations').select('id');
  // Fetch total slots
  final slots = await client.from('slots').select('id');
  // Fetch active reservations (not completed, not cancelled)
  final activeReservations = await client.from('reservations')
      .select('id')
      .neq('status', 'completed')
      .neq('status', 'cancelled');

  return {
    'total_stations': stations.length,
    'total_slots': slots.length,
    'active_reservations': activeReservations.length,
  };
});
// ---------------------------------

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(adminMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/map'),
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            label: const Text('User View', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(adminMetricsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text('Network Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // --- LIVE METRICS BANNER ---
            metricsAsync.when(
              data: (metrics) => Row(
                children: [
                  Expanded(child: _MetricCard(title: 'Stations', count: metrics['total_stations'].toString(), icon: Icons.ev_station, color: Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(title: 'Slots', count: metrics['total_slots'].toString(), icon: Icons.bolt, color: Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(title: 'Active\nSessions', count: metrics['active_reservations'].toString(), icon: Icons.timer, color: Colors.green)),
                ],
              ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
              error: (err, stack) => Card(color: Colors.red[50], child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Failed to load metrics: $err'))),
            ),
            // ---------------------------

            const SizedBox(height: 32),
            const Text('Infrastructure Controls', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            _AdminMenuTile(
              icon: Icons.ev_station,
              title: 'Manage Stations',
              description: 'Add, edit, or delete charging locations',
              onTap: () => context.push('/admin/stations'),
            ),
            const SizedBox(height: 12),
            _AdminMenuTile(
              icon: Icons.bolt,
              title: 'Manage Slots',
              description: 'Configure individual chargers and maintenance mode',
              onTap: () => context.push('/admin/slots'),
            ),
            const SizedBox(height: 12),
            _AdminMenuTile(
              icon: Icons.people,
              title: 'User Management',
              description: 'View registered members and override locks',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User Management coming soon!')));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Widget for the 3 little metric squares at the top
class _MetricCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.title, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Your existing menu tile widget (Keep this!)
class _AdminMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AdminMenuTile({required this.icon, required this.title, required this.description, required this.onTap});

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