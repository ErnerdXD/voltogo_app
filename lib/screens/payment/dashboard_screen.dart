import 'package:flutter/material.dart';
import 'package:voltogo_app/widgets/brand_app_bar_title.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const BrandAppBarTitle(title: 'Dashboard'),
      ),
      body: const Center(child: Text('Energy & CO2 Stats')),
    );
  }
}
