import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltogo_app/models/station_model.dart';
import 'package:voltogo_app/providers/station_provider.dart';
import 'package:voltogo_app/services/supabase_service.dart';

class ManageStationsScreen extends ConsumerStatefulWidget {
  const ManageStationsScreen({super.key});

  @override
  ConsumerState<ManageStationsScreen> createState() => _ManageStationsScreenState();
}

class _ManageStationsScreenState extends ConsumerState<ManageStationsScreen> {

  Future<void> _showStationFormDialog({StationModel? existingStation}) async {
    final isEditing = existingStation != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingStation?.name ?? '');
    final addressController = TextEditingController(text: existingStation?.address ?? '');
    final latController = TextEditingController(text: existingStation?.latitude?.toString() ?? '');
    final lngController = TextEditingController(text: existingStation?.longitude?.toString() ?? '');
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isEditing ? 'Edit Station' : 'Add New Station', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Station Name', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: latController,
                            decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lngController,
                            decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (formKey.currentState!.validate()) {
                            setModalState(() => isSubmitting = true);
                            try {
                              if (isEditing) {
                                await SupabaseService().updateStation(
                                    existingStation.id,
                                    {
                                      'name': nameController.text.trim(),
                                      'address': addressController.text.trim(),
                                      'latitude': double.parse(latController.text.trim()),
                                      'longitude': double.parse(lngController.text.trim()),
                                    }
                                );
                              } else {
                                await SupabaseService().createStation(
                                  name: nameController.text.trim(),
                                  address: addressController.text.trim(),
                                  latitude: double.parse(latController.text.trim()),
                                  longitude: double.parse(lngController.text.trim()),
                                );
                              }

                              ref.read(stationsProvider.notifier).fetchStations();

                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isEditing ? 'Station updated!' : 'Station added!'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              }
                            } finally {
                              setModalState(() => isSubmitting = false);
                            }
                          }
                        },
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(isEditing ? 'Save Changes' : 'Create Station'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }

  Future<void> _confirmDeleteStation(StationModel station) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Station?'),
        content: Text('Are you sure you want to permanently delete "${station.name}"? This will also delete all slots attached to it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService().deleteStation(station.id);
        ref.read(stationsProvider.notifier).fetchStations();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Station deleted')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Charging Stations')),
      body: stationsAsync.when(
        data: (stations) => stations.isEmpty
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ev_station_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No stations available. Add one below!'),
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
                title: Text(station.name ?? 'Unknown Station', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${station.address ?? 'N/A'}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: station.status == 'active' ? Colors.green[100] : Colors.red[100], borderRadius: BorderRadius.circular(12)),
                          child: Text(station.status?.toUpperCase() ?? 'INACTIVE', style: TextStyle(fontSize: 10, color: station.status == 'active' ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text('•  ${station.totalSlots ?? 0} Slots', style: const TextStyle(fontSize: 12)),
                      ],
                    )
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _showStationFormDialog(existingStation: station);
                    if (value == 'delete') _confirmDeleteStation(station);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStationFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Station'),
      ),
    );
  }
}