import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- THE ACTIONABLE METRICS PROVIDER ---
final adminMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = Supabase.instance.client;

  // 1. Live Utilization (Active sessions right now)
  final activeReservations = await client.from('reservations')
      .select('id')
      .neq('status', 'completed')
      .neq('status', 'cancelled');

  // 2. Needs Attention (Broken or offline chargers)
  final brokenSlots = await client.from('slots')
      .select('id')
      .eq('status', 'maintenance');

  // 3. Today's Revenue
  // We get the start of the current day to filter payments
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

  final todayPayments = await client.from('payments')
      .select('amount')
      .gte('paid_at', startOfDay);

  double dailyRevenue = 0.0;
  for (var payment in todayPayments) {
    dailyRevenue += (payment['amount'] as num?)?.toDouble() ?? 0.0;
  }

  return {
    'active_sessions': activeReservations.length,
    'maintenance_slots': brokenSlots.length,
    'today_revenue': dailyRevenue,
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

            // --- ACTIONABLE METRICS BANNER ---
            metricsAsync.when(
              data: (metrics) => Row(
                children: [
                  Expanded(child: _MetricCard(title: 'Active\nSessions', count: metrics['active_sessions'].toString(), icon: Icons.bolt, color: Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(title: 'Needs\nAttention', count: metrics['maintenance_slots'].toString(), icon: Icons.build_circle, color: Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(title: 'Today\'s\nRevenue', count: 'RM ${metrics['today_revenue'].toStringAsFixed(0)}', icon: Icons.payments, color: Colors.green)),
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
              icon: Icons.electrical_services,
              title: 'Manage Slots',
              description: 'Configure individual chargers and maintenance mode',
              onTap: () => context.push('/admin/slots'),
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
          Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
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
        leading: Icon(icon, size: 32, color: Colors.grey[800]),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey[100],
      ),
    );
  }
}