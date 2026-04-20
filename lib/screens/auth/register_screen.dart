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
    final XFile? image = await picker.pickImage(
        source: ImageSource.camera, maxWidth: 600);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
        _avatarExt = image.path
            .split('.')
            .last;
      });
    }
  }

  Future<void> _signUp() async {
    // Existing empty check
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Password Check
    if (!Validators.isStrongPassword(_passwordController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Validators.passwordRequirements),
            backgroundColor: Colors.orange),
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
      builder: (ctx) =>
          StatefulBuilder(
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
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(), labelText: 'OTP'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: isVerifying ? null : () async {
                        setDialogState(() => isVerifying = true);
                        try {
                          // Verify the OTP
                          final response = await Supabase.instance.client.auth
                              .verifyOTP(
                            email: _emailController.text.trim(),
                            token: otpController.text.trim(),
                            type: OtpType.signup,
                          );

                          if (response.user == null) throw Exception(
                              'Verification failed');

                          String? avatarUrl;
                          if (_avatarBytes != null) {
                            avatarUrl = await SupabaseService().uploadAvatar(
                                'avatar.$_avatarExt', _avatarBytes!);
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
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text(
                                    'Registration complete!'),
                                    backgroundColor: Colors.green));
                            context.go('/login');
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger
                              .of(context)
                              .showSnackBar(SnackBar(content: Text('Error: $e'),
                              backgroundColor: Colors.red));
                        } finally {
                          setDialogState(() => isVerifying = false);
                        }
                      },
                      child: isVerifying
                          ? const CircularProgressIndicator()
                          : const Text('Verify & Complete'),
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
      backgroundColor: Colors.grey[50], // Match login background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[900]),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 24.0, vertical: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Create Account', style: Theme
                    .of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.blue[900])),
                const SizedBox(height: 8),
                Text('Join the VoltoGo network today.', style: Theme
                    .of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 24),

                Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Avatar picker moved inside the card for a cohesive profile setup feel
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.blue[50],
                                backgroundImage: _avatarBytes != null
                                    ? MemoryImage(_avatarBytes!)
                                    : null,
                                child: _avatarBytes == null ? Icon(
                                    Icons.person, size: 45,
                                    color: Colors.blue[200]) : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.blue, shape: BoxShape.circle),
                                child: const Icon(
                                    Icons.camera_alt, color: Colors.white,
                                    size: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_reset),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isLoading ? null : _signUp,
                            child: _isLoading
                                ? const SizedBox(height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                                : const Text('Sign Up', style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?',
                        style: TextStyle(color: Colors.grey[700])),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Log In',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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