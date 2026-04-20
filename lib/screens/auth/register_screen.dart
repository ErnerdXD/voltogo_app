import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/services/supabase_service.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:voltogo_app/utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  Uint8List? _avatarBytes;
  String? _avatarExt;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, maxWidth: 600);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
        _avatarExt = image.path.split('.').last;
      });
    }
  }

  Future<void> _signUp() async {
    // Existing empty check
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Password Check
    if (!Validators.isStrongPassword(_passwordController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Validators.passwordRequirements), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Step 1: Sign up with Supabase Auth.
      // This sends the OTP email, but does NOT fully authenticate them yet.
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Step 2: Show the OTP dialog to the user so they can enter the 6-digit pin!
      if (mounted) {
        _showOtpDialog();
      }

    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOtpDialog() {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Force them to enter it
      builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Verify Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter the 6-digit pin sent to your email.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'OTP'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isVerifying ? null : () async {
                    setDialogState(() => isVerifying = true);
                    try {
                      // 1. Verify the OTP
                      final response = await Supabase.instance.client.auth.verifyOTP(
                        email: _emailController.text.trim(),
                        token: otpController.text.trim(),
                        type: OtpType.signup,
                      );

                      if (response.user == null) throw Exception('Verification failed');

                      // 2. NOW they are authenticated! We can safely upload the image.
                      String? avatarUrl;
                      if (_avatarBytes != null) {
                        avatarUrl = await SupabaseService().uploadAvatar('avatar.$_avatarExt', _avatarBytes!);
                      }

                      // 3. Create the Database records
                      await SupabaseService().setupUserAfterSignup(
                        response.user!,
                        fullName: _nameController.text.trim(),
                        avatarUrl: avatarUrl,
                      );

                      // 4. Force sign out so router doesn't skip Login
                      await Supabase.instance.client.auth.signOut();

                      if (mounted) {
                        Navigator.pop(ctx); // Close dialog
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration complete!'), backgroundColor: Colors.green));
                        context.go('/login');
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    } finally {
                      setDialogState(() => isVerifying = false);
                    }
                  },
                  child: isVerifying ? const CircularProgressIndicator() : const Text('Verify & Complete'),
                )
              ],
            );
          }
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center( // 1. Keeps it centered when keyboard is closed
        child: SingleChildScrollView( // 2. Makes it scrollable when keyboard opens!
          padding: const EdgeInsets.all(24.0), // 3. Moved the padding here
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                  child: _avatarBytes == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _signUp,
                child: const Text('Sign Up'),
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
