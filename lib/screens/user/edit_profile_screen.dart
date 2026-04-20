import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/providers/auth_provider.dart';
import 'package:voltogo_app/providers/user_provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:voltogo_app/services/supabase_service.dart';
import 'package:voltogo_app/utils/validators.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  Uint8List? _newAvatarBytes;
  String? _newAvatarExt;
  String? _currentAvatarUrl;

  bool _isLoading = false;
  bool _isSaving = false; // Added this variable!

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();

    // Pre-fill form after first frame
    Future.microtask(() {
      final profileAsync = ref.read(profileProvider);
      profileAsync.whenData((profile) {
        if (mounted && profile != null) {
          _nameController.text = profile.fullName ?? '';
          _phoneController.text = profile.phone ?? '';
          _currentAvatarUrl = profile.avatarUrl;
        }
      });
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, maxWidth: 600);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _newAvatarBytes = bytes;
        _newAvatarExt = image.path.split('.').last;
      });
    }
  }

  Future<void> _changePasswordDialog() async {
    final pwdController = TextEditingController();
    final confirmPwdController = TextEditingController(); // ADD THIS

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        // Change the content to a Column to hold two TextFields
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPwdController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newPassword = pwdController.text.trim();

              // 1. Check if passwords match
              if (newPassword != confirmPwdController.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.orange),
                );
                return; // Stop them from proceeding
              }

              // 2. Check Strong Password Requirements
              if (!Validators.isStrongPassword(newPassword)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(Validators.passwordRequirements), backgroundColor: Colors.orange),
                );
                return;
              }

              try {
                await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: newPassword)
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green)
                  );
                }
              } on AuthException catch (e) {
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
              } catch (e) {
                // Fallback for generic network errors
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text('Update'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String? finalAvatarUrl = _currentAvatarUrl;

      // Upload new image if one was taken
      if (_newAvatarBytes != null) {
        finalAvatarUrl = await SupabaseService().uploadAvatar('update.$_newAvatarExt', _newAvatarBytes!);
      }

      await ref.read(profileProvider.notifier).updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarUrl: finalAvatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // Navigate back only after the await finishes
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to permanently delete your account? \n\n'
              'This action cannot be undone and all your personal data and saved vehicles will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        // Grab the public.users.id from Riverpod
        final userModel = ref.read(userProvider).value;
        if (userModel == null) {
          throw Exception('User record not found. Please try logging in again.');
        }
        final publicUserId = userModel.id;

        // 1. Soft delete the data in Supabase using the CORRECT ID
        await ref.read(userProvider.notifier).deleteAccount(publicUserId);

        // 2. Log the user out of the authentication session using Supabase
        await Supabase.instance.client.auth.signOut();

        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profileAsync.when(
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Your Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _newAvatarBytes != null
                          ? MemoryImage(_newAvatarBytes!)
                          : (_currentAvatarUrl != null ? NetworkImage(_currentAvatarUrl!) as ImageProvider : null),
                      child: _newAvatarBytes == null && _currentAvatarUrl == null
                          ? const Icon(Icons.camera_alt, size: 40) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+60 1X XXX XXXX',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: _changePasswordDialog,
                  icon: const Icon(Icons.lock),
                  label: const Text('Change Password'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // Updated to just pass context, no need for user.id here!
                    onPressed: _isSaving ? null : () => _confirmDeleteAccount(context),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // ignore: unused_result
                  ref.refresh(profileProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}