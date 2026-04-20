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
  int _step = 1; // 1: Email, 2: OTP, 3: New Password

  // --- STEP 1: SEND EMAIL ---
  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      setState(() => _step = 2); // Move to Step 2
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your email!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- STEP 2: VERIFY OTP ---
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // Verifying the recovery OTP temporarily authenticates the user in the background
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
        type: OtpType.recovery,
      );

      setState(() => _step = 3); // Move to Step 3
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid or expired OTP: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- STEP 3: UPDATE PASSWORD ---
  Future<void> _updatePassword() async {
    if (_newPasswordController.text.isEmpty) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!Validators.isStrongPassword(_newPasswordController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Validators.passwordRequirements), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Update the password for the temporarily authenticated session
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );

      // Kick them out so they can log in normally with the new password
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully! Please log in.'), backgroundColor: Colors.green)
        );
        context.go('/login');
      }

    } on AuthException catch (e) {
      if (mounted) {
        String friendlyMessage = e.message;
        if (e.message.contains('different from the old password') || e.message.contains('same_password')) {
          friendlyMessage = 'Your new password cannot be the same as your current password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyMessage), backgroundColor: Colors.orange)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[900]),
      ),
      // SafeArea + Center + SingleChildScrollView completely fixes the keyboard overflow!
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // --- UI FOR STEP 1: EMAIL ---
                    if (_step == 1) ...[
                      const Icon(Icons.lock_reset, size: 48, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text('Forgot Password?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Enter your email to receive a reset pin.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      TextField(
                          controller: _emailController,
                          decoration: InputDecoration(labelText: 'Email Address', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          keyboardType: TextInputType.emailAddress
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                            onPressed: _isLoading ? null : _sendOtp,
                            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send Reset Pin')
                        ),
                      ),
                    ]

                    // --- UI FOR STEP 2: OTP ---
                    else if (_step == 2) ...[
                      const Icon(Icons.mark_email_read, size: 48, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text('Check your Email', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Enter the 6-digit pin we just sent you.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      TextField(
                          controller: _otpController,
                          decoration: InputDecoration(labelText: '6-Digit OTP', prefixIcon: const Icon(Icons.pin), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          keyboardType: TextInputType.number,
                          maxLength: 6
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                            onPressed: _isLoading ? null : _verifyOtp,
                            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify Pin')
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _step = 1),
                        child: const Text('Change Email'),
                      ),
                    ]

                    // --- UI FOR STEP 3: NEW PASSWORD ---
                    else if (_step == 3) ...[
                        const Icon(Icons.shield, size: 48, color: Colors.green),
                        const SizedBox(height: 16),
                        Text('Create New Password', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Your identity has been verified.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 24),
                        TextField(
                            controller: _newPasswordController,
                            decoration: InputDecoration(labelText: 'New Password', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            obscureText: true
                        ),
                        const SizedBox(height: 12),
                        TextField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock_reset), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            obscureText: true
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: _isLoading ? null : _updatePassword,
                              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Reset Password')
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}