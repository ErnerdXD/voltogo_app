import 'package:flutter/material.dart';
import 'package:voltogo_app/widgets/brand_app_bar_title.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('Energy & CO2 Stats')),
    );
  }
}
