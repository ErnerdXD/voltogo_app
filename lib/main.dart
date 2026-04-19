import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/app.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  Stripe.publishableKey = 'pk_test_51TNalyRv52dLdlOpFquusWsCsuOb6ZvO76zmZ6vvIGVtTpxHNPLMz3pfyWOAw60QpqHys0qrRr0yoBrDV7tqL1f500gzgypSI9';
  await Stripe.instance.applySettings();
  print('[DEBUG] Stripe initialized successfully');
  runApp(
    ProviderScope(
      child: const MyApp(),
    ),
  );
}