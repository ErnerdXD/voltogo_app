import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false; // Tracks which step of the UI we are on

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      setState(() => _otpSent = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your email!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndReset() async {
    if (_otpController.text.isEmpty || _newPasswordController.text.isEmpty) return;

    // 1. Check if passwords match
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 2. Check Strong Password Requirements
    if (!Validators.isStrongPassword(_newPasswordController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Validators.passwordRequirements), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Verify the 6-digit (or 8-digit) OTP
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
        type: OtpType.recovery,
      );

      // 2. The user is now temporarily logged in! Update their password.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );

      // 3. Kick them out so they can log in normally with the new password
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully! Please login.'), backgroundColor: Colors.green)
        );
        context.go('/login');
      }

    } on AuthException catch (e) {
      // --- THE ERROR INTERCEPTOR ---
      if (mounted) {
        String friendlyMessage = e.message;

        // Intercept the specific Supabase 'same_password' rejection
        if (e.message.contains('different from the old password') || e.message.contains('same_password')) {
          friendlyMessage = 'Your new password cannot be the same as your current password.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyMessage), backgroundColor: Colors.orange)
        );
      }
      // -----------------------------
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_otpSent) ...[
              const Text('Enter your email to receive a 6-digit reset pin.'),
              const SizedBox(height: 16),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _isLoading ? null : _sendOtp, child: _isLoading ? const CircularProgressIndicator() : const Text('Send OTP')),
              ),
            ] else ...[
              const Text('Enter the 6-digit pin sent to your email, and your new password.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(controller: _otpController, decoration: const InputDecoration(labelText: '6-Digit OTP', border: OutlineInputBorder()), keyboardType: TextInputType.number, maxLength: 6),
              const SizedBox(height: 12),
              TextField(controller: _newPasswordController, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()), obscureText: true),
              const SizedBox(height: 12),
              TextField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
                  obscureText: true
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _isLoading ? null : _verifyAndReset, child: _isLoading ? const CircularProgressIndicator() : const Text('Reset Password')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}