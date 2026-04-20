import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/providers/user_provider.dart';
import 'package:voltogo_app/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // 1. Authenticate with Supabase
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. INTERCEPT: Check if this user account was soft-deleted
      if (response.user != null) {
        final userRecord = await Supabase.instance.client
            .from('users')
            .select('is_deleted')
            .eq('auth_user_id', response.user!.id)
            .single();

        // BLOCK: If deleted, forcefully sign them back out and throw an error
        if (userRecord['is_deleted'] == true) {
          await Supabase.instance.client.auth.signOut();
          throw Exception('This account has been deleted. Please register a new account.');
        }
      }

      ref.invalidate(profileProvider);
      ref.invalidate(userProvider);
      ref.invalidate(authUserProvider);

      // 4. Success! Navigate to the map
      if (mounted) context.go('/map');

    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Soft background color
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- BRANDING SECTION ---
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/branding/voltogo_icon.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Welcome to VoltoGo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                const SizedBox(height: 8),
                Text('Power up your journey.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 32),

                // --- FORM CARD ---
                Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- FOOTER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Don\'t have an account?', style: TextStyle(color: Colors.grey[700])),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Create one', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}