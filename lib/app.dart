import 'package:flutter/material.dart';
import 'package:voltogo_app/utils/app_colors.dart';
import 'package:voltogo_app/utils/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Voltogo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.seed),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.appBarBackground,
          foregroundColor: AppColors.onAppBar,
          elevation: 0,
        ),
      ),
      routerConfig: goRouter,
    );
  }
}
