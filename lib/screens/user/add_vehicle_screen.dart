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

  bool _isLoadingModels = true;
  List<Map<String, dynamic>> _allEvModels = [];
  List<String> _availableBrands = [];
  List<Map<String, dynamic>> _modelsForSelectedBrand = [];
  String? _selectedBrand;
  Map<String, dynamic>? _selectedEvModel;
  bool _isSaving = false;

  @override
  void initState() { super.initState(); _fetchEvModels(); }

  Future<void> _fetchEvModels() async {
    try {
      final models = await SupabaseService().getEvModels();
      final uniqueBrands = models.map((m) => m['brand']?.toString() ?? 'Unknown').toSet().toList();
      uniqueBrands.sort();
      if (mounted) setState(() { _allEvModels = models; _availableBrands = uniqueBrands; _isLoadingModels = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoadingModels = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load EV Database: $e'))); }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEvModel == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vehicle model.'))); return; }
    setState(() => _isSaving = true);
    try {
      await ref.read(vehicleProvider.notifier).addVehicle(
        brand: _selectedEvModel!['brand'], model: _selectedEvModel!['model'], plateNumber: _plateController.text.trim().toUpperCase(),
        plugType: _selectedEvModel!['plug_type'] ?? 'Type 2 / CCS2', batteryCapacityKwh: (_selectedEvModel!['battery_capacity_kwh'] as num?)?.toInt(),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding vehicle: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: Text('Add Vehicle', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: _isLoadingModels
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: isDark ? 0 : 2,
                shadowColor: Colors.black12,
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Icon(Icons.electric_car, color: isDark ? Colors.blue[400] : Colors.blue[700]), const SizedBox(width: 8), Text('Vehicle Make & Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87))]),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Select Brand', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        initialValue: _selectedBrand,
                        items: _availableBrands.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBrand = value; _selectedEvModel = null;
                            _modelsForSelectedBrand = _allEvModels.where((m) => m['brand'] == value).toList();
                            _modelsForSelectedBrand.sort((a, b) => (a['model'] ?? '').compareTo(b['model'] ?? ''));
                          });
                        },
                        validator: (v) => v == null ? 'Please select a brand' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        decoration: InputDecoration(labelText: 'Select Model', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        initialValue: _selectedEvModel,
                        isExpanded: true,
                        items: _selectedBrand == null ? [] : _modelsForSelectedBrand.map((modelMap) => DropdownMenuItem<Map<String, dynamic>>(value: modelMap, child: Text(modelMap['model']?.toString() ?? 'Unknown'))).toList(),
                        onChanged: _selectedBrand == null ? null : (value) => setState(() => _selectedEvModel = value),
                        validator: (v) => v == null ? 'Please select a model' : null,
                        disabledHint: const Text('Select a brand first...'),
                      ),

                      if (_selectedEvModel != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: isDark ? 0.1 : 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(children: [Icon(Icons.ev_station, color: isDark ? Colors.blue[400] : Colors.blue[700]), const SizedBox(height: 4), Text('${_selectedEvModel!['plug_type'] ?? 'Unknown'}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), Text('Plug Type', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey))]),
                              Container(height: 40, width: 1, color: Colors.blue.withValues(alpha: 0.2)),
                              Column(children: [Icon(Icons.battery_charging_full, color: isDark ? Colors.green[400] : Colors.green[600]), const SizedBox(height: 4), Text('${_selectedEvModel!['battery_capacity_kwh']} kWh', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), Text('Capacity', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey))]),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: isDark ? 0 : 2,
                shadowColor: Colors.black12,
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Icon(Icons.badge, color: isDark ? Colors.blue[400] : Colors.blue[700]), const SizedBox(width: 8), Text('Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87))]),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(labelText: 'License Plate Number', hintText: 'e.g. VBG 1234', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (v) => v == null || v.isEmpty ? 'Plate number is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save to Garage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}