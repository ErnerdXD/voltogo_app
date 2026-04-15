import 'package:flutter/material.dart';

class ManageSlotsScreen extends StatelessWidget {
  const ManageSlotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Charging Slots'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Slot Management'),
            const SizedBox(height: 8),
            const Text('Feature coming soon'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add slot feature coming soon')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
