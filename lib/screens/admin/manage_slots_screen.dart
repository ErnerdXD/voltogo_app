import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltogo_app/models/station_model.dart';
import 'package:voltogo_app/providers/station_provider.dart';
import 'package:voltogo_app/services/supabase_service.dart';

class ManageSlotsScreen extends ConsumerStatefulWidget {
  const ManageSlotsScreen({super.key});

  @override
  ConsumerState<ManageSlotsScreen> createState() => _ManageSlotsScreenState();
}

class _ManageSlotsScreenState extends ConsumerState<ManageSlotsScreen> {

  Future<void> _showAddSlotDialog(StationModel station) async {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final priceController = TextEditingController(text: '1.50');
    String selectedType = 'CCS2';
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Charger to ${station.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(labelText: 'Slot Code (e.g. A1, Charger 1)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Connector Type', border: OutlineInputBorder()),
                      items: ['CCS2', 'Type 2', 'CHAdeMO'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setModalState(() => selectedType = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price per kWh (RM)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (formKey.currentState!.validate()) {
                            setModalState(() => isSubmitting = true);
                            try {
                              await SupabaseService().createSlot(
                                stationId: station.id,
                                slotCode: codeController.text.trim(),
                                connectorType: selectedType,
                                pricePerKwh: double.parse(priceController.text.trim()),
                              );
                              ref.read(stationsProvider.notifier).fetchStations();
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot added!'), backgroundColor: Colors.green));
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            } finally {
                              setModalState(() => isSubmitting = false);
                            }
                          }
                        },
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Add Charger'),
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

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Charging Slots')),
      body: stationsAsync.when(
        data: (stations) => stations.isEmpty
            ? const Center(child: Text('Create a station first to add slots.'))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            final slots = station.slots ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.ev_station),
                title: Text(station.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${slots.length} Chargers Active'),
                children: [
                  ...slots.map((slot) {
                    final isAvailable = slot.status == 'available';
                    return ListTile(
                      leading: Icon(Icons.bolt, color: isAvailable ? Colors.green : Colors.orange),
                      title: Text('${slot.slotCode} (${slot.connectorType})'),
                      subtitle: Text('RM ${slot.pricePerKwh?.toStringAsFixed(2)} / kWh'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The Maintenance Toggle Switch!
                          Switch(
                            value: isAvailable,
                            activeColor: Colors.green,
                            onChanged: (value) async {
                              try {
                                final newStatus = value ? 'available' : 'maintenance';
                                await SupabaseService().updateSlotStatus(slot.id, newStatus);
                                ref.read(stationsProvider.notifier).fetchStations();
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              try {
                                await SupabaseService().deleteSlot(slot.id, station.id);
                                ref.read(stationsProvider.notifier).fetchStations();
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                          )
                        ],
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton.icon(
                      onPressed: () => _showAddSlotDialog(station),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Charger to Station'),
                    ),
                  )
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}