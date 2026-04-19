import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voltogo_app/providers/vehicle_provider.dart';
import 'package:voltogo_app/services/supabase_service.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();

  // Data State Variables
  bool _isLoadingModels = true;
  List<Map<String, dynamic>> _allEvModels = [];

  // Cascading Dropdown Variables
  List<String> _availableBrands = [];
  List<Map<String, dynamic>> _modelsForSelectedBrand = [];

  String? _selectedBrand;
  Map<String, dynamic>? _selectedEvModel;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchEvModels();
  }

  // 1. Fetch all cars and extract the unique Brands
  Future<void> _fetchEvModels() async {
    try {
      final service = SupabaseService();
      final models = await service.getEvModels();

      // Extract unique brands using a Set, then convert to a sorted List
      final uniqueBrands = models
          .map((m) => m['brand']?.toString() ?? 'Unknown')
          .toSet()
          .toList();
      uniqueBrands.sort(); // Sort alphabetically (Acura, Audi, BMW, etc.)

      if (mounted) {
        setState(() {
          _allEvModels = models;
          _availableBrands = uniqueBrands;
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingModels = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load EV Database: $e')),
        );
      }
    }
  }

  // 2. Save the selected car
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEvModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle model.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(vehicleProvider.notifier).addVehicle(
        brand: _selectedEvModel!['brand'],
        model: _selectedEvModel!['model'],
        plateNumber: _plateController.text.trim().toUpperCase(),
        plugType: _selectedEvModel!['plug_type'] ?? 'Type 2 / CCS2',
        // Convert the Double/Float from ev_models to an Integer for your vehicles table
        batteryCapacityKwh: (_selectedEvModel!['battery_capacity_kwh'] as num?)?.toInt(),
      );

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding vehicle: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Vehicle')),
      body: _isLoadingModels
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Specifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),

              // DROPDOWN 1: The Brand
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Brand',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                initialValue: _selectedBrand,
                items: _availableBrands.map((brand) {
                  return DropdownMenuItem(value: brand, child: Text(brand));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBrand = value;
                    _selectedEvModel = null; // Reset the model dropdown

                    _modelsForSelectedBrand = _allEvModels
                        .where((m) => m['brand'] == value)
                        .toList();

                    // Sort alphabetically
                    _modelsForSelectedBrand.sort((a, b) =>
                        (a['model'] ?? '').compareTo(b['model'] ?? ''));
                  });
                },
                validator: (v) => v == null ? 'Please select a brand' : null,
              ),

              const SizedBox(height: 20),

              // DROPDOWN 2: The Model
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: 'Select Model',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.electric_car),
                ),
                initialValue: _selectedEvModel,
                isExpanded: true, // Prevents long model names from breaking the UI
                // Disable the dropdown entirely if no brand is selected yet
                items: _selectedBrand == null
                    ? []
                    : _modelsForSelectedBrand.map((modelMap) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: modelMap,
                    child: Text(modelMap['model']?.toString() ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: _selectedBrand == null
                    ? null
                    : (value) {
                  setState(() {
                    _selectedEvModel = value;
                  });
                },
                validator: (v) => v == null ? 'Please select a model' : null,
                disabledHint: const Text('Please select a brand first'),
              ),

              const SizedBox(height: 20),

              // Display the specs of the selected car
              if (_selectedEvModel != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.ev_station, color: Colors.green),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedEvModel!['plug_type'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text('Plug Type', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.battery_charging_full, color: Colors.green),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedEvModel!['battery_capacity_kwh']} kWh',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text('Capacity', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Plate Number input
              const Text(
                'Registration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Plate Number',
                  hintText: 'e.g. VBG 1234',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Plate number is required' : null,
              ),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Vehicle to Garage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}