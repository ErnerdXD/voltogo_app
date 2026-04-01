import 'package:flutter/material.dart';
import 'package:voltogo_app/widgets/brand_app_bar_title.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const BrandAppBarTitle(title: 'Activity'),
      ),
      body: const Center(child: Text('Past & Upcoming Bookings')),
    );
  }
}
