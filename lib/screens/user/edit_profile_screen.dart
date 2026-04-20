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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
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
      setState(() { _newAvatarBytes = bytes; _newAvatarExt = image.path.split('.').last; });
    }
  }

  Future<void> _changePasswordDialog() async {
    final pwdController = TextEditingController();
    final confirmPwdController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pwdController, obscureText: true, decoration: InputDecoration(labelText: 'New Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: confirmPwdController, obscureText: true, decoration: InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final newPassword = pwdController.text.trim();
              if (newPassword != confirmPwdController.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.orange));
                return;
              }
              if (!Validators.isStrongPassword(newPassword)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Validators.passwordRequirements), backgroundColor: Colors.orange));
                return;
              }
              try {
                await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green));
                }
              } on AuthException catch (e) {
                if (mounted) {
                  String friendlyMessage = e.message;
                  if (e.message.contains('different from the old password') || e.message.contains('same_password')) {
                    friendlyMessage = 'Your new password cannot be the same as your current password.';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyMessage), backgroundColor: Colors.orange));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Update'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() { _nameController.dispose(); _phoneController.dispose(); super.dispose(); }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String? finalAvatarUrl = _currentAvatarUrl;
      if (_newAvatarBytes != null) {
        finalAvatarUrl = await SupabaseService().uploadAvatar('update.$_newAvatarExt', _newAvatarBytes!);
      }
      await ref.read(profileProvider.notifier).updateProfile(fullName: _nameController.text.trim(), phone: _phoneController.text.trim(), avatarUrl: finalAvatarUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Delete Account', style: TextStyle(color: Colors.red))]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text('Are you sure you want to permanently delete your account?\n\nThis action cannot be undone and all your personal data and saved vehicles will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete Forever')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        final userModel = ref.read(userProvider).value;
        if (userModel == null) throw Exception('User record not found. Please try logging in again.');
        await ref.read(userProvider.notifier).deleteAccount(userModel.id);
        await Supabase.instance.client.auth.signOut();
        if (mounted) context.go('/login');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete account: $e')));
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: profileAsync.when(
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50],
                          backgroundImage: _newAvatarBytes != null ? MemoryImage(_newAvatarBytes!) : (_currentAvatarUrl != null ? NetworkImage(_currentAvatarUrl!) as ImageProvider : null),
                          child: _newAvatarBytes == null && _currentAvatarUrl == null ? Icon(Icons.person, size: 55, color: isDark ? Colors.blue[400] : Colors.blue[200]) : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: isDark ? Colors.blue[500] : Colors.blue[700], shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.grey[900]! : Colors.white, width: 2)),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Card(
                  elevation: isDark ? 0 : 2,
                  shadowColor: Colors.black12,
                  color: isDark ? Colors.grey[900] : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length < 10) return 'Please enter a valid phone number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _changePasswordDialog,
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Change Password'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.blue[300] : Colors.blue[700],
                                side: BorderSide(color: isDark ? Colors.blue[300]! : Colors.blue[700]!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 48),

                Row(
                  children: [
                    Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('DANGER ZONE', style: TextStyle(color: isDark ? Colors.red[400] : Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.red[400] : Colors.red,
                        side: BorderSide(color: isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
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
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}