import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/splash_screen.dart';

const String supabaseUrl = 'https://ejeseyuqdubakwqnzjbz.supabase.co';
const String supabaseKey = 'sb_secret_DW5bmUizDnD6Wca9-eG-wg_EGpabMnn';
//boom

Future<void> main() async {
  // Required for Supabase initialization
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase before the app starts
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoltoGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Ensure AnimatedSplashScreenWidget is correctly exported in splash_screen.dart
      home: const AnimatedSplashScreenWidget(),
    );
  }
}
