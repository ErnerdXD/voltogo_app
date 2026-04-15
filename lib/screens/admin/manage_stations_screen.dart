import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltogo_app/providers/station_provider.dart';

class ManageStationsScreen extends ConsumerWidget {
  const ManageStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Charging Stations'),
      ),
      body: stationsAsync.when(
        data: (stations) => stations.isEmpty
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ev_station_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No stations available'),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.ev_station, color: Colors.blue),
                title: Text(station.name ?? 'Unknown Station'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Address: ${station.address ?? 'N/A'}'),
                    Text('Total Slots: ${station.totalSlots ?? 0}'),
                    Text('Status: ${station.status ?? 'inactive'}'),
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      child: Text('Delete'),
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement add station functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add station feature coming soon')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

