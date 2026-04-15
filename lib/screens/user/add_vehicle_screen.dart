import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voltogo_app/providers/vehicle_provider.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _capacityController = TextEditingController();
  String _selectedPlugType = 'Type 2';

  final List<String> _plugTypes = ['Type 2', 'CCS2', 'CHAdeMO', 'Tesla'];

  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(vehicleProvider.notifier).addVehicle(
            brand: _brandController.text.trim(),
            model: _modelController.text.trim(),
            plateNumber: _plateController.text.trim(),
            plugType: _selectedPlugType,
            batteryCapacityKwh: int.tryParse(_capacityController.text.trim()),
          );
      if (mounted) {
        context.pop(); // Go back to the vehicle list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding vehicle: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Vehicle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Brand (e.g. Tesla, BYD)'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Model (e.g. Model 3, Atto 3)'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Plate Number'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Battery Capacity (kWh)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              const Text('Plug Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
               DropdownButtonFormField<String>(
                 initialValue: _selectedPlugType,
                 items: _plugTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                 onChanged: (v) => setState(() => _selectedPlugType = v!),
                 decoration: const InputDecoration(border: OutlineInputBorder()),
               ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text('Save Vehicle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
