import 'package:flutter/material.dart';
import 'package:voltogo_app/widgets/brand_app_bar_title.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const BrandAppBarTitle(title: 'Profile'),
      ),
      body: const Center(child: Text('User Information')),
    );
  }
}
