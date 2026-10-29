import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../theme/glass_theme.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _loadOnce(String name, String username, String bio) {
    if (_initialized) return;
    _nameController.text = name;
    _usernameController.text = username;
    _bioController.text = bio;
    _initialized = true;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
        bio: _bioController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully ✨')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      final friendly = message.contains('409') || message.toLowerCase().contains('already taken')
          ? 'That username is already taken. Try another one.'
          : message.contains('422')
              ? 'Use 3–24 characters: letters, numbers, dots or underscores.'
              : 'Could not update your profile. Please check your connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.trenzyColors;
    final user = ref.watch(authProvider).valueOrNull;
    if (user != null) _loadOnce(user.name, user.username, user.bio);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Edit Profile', style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w700)),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: colors.foreground),
        ),
      ),
      body: user == null
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: colors.primary.withValues(alpha: .16),
                      backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                      child: user.avatarUrl.isEmpty
                          ? Icon(Icons.person_rounded, color: colors.primary, size: 42)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text('Make your Trenzy profile yours', style: TextStyle(color: colors.mutedFg, fontSize: 13))),
                  const SizedBox(height: 28),
                  _field(
                    label: 'Display name',
                    hint: 'How friends see you',
                    controller: _nameController,
                    icon: Icons.badge_outlined,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter your name'
                        : value.trim().length > 120 ? 'Name is too long' : null,
                  ),
                  const SizedBox(height: 18),
                  _field(
                    label: 'Username',
                    hint: 'your.unique.handle',
                    controller: _usernameController,
                    icon: Icons.alternate_email_rounded,
                    prefixText: '@',
                    validator: (value) {
                      final username = (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');
                      if (username.length < 3 || username.length > 24) return 'Use 3–24 characters';
                      if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(username)) return 'Use letters, numbers, dots or underscores only';
                      return null;
                    },
                  ),
                  const SizedBox(height: 7),
                  Text('Friends can find you using this username.', style: TextStyle(color: colors.mutedFg, fontSize: 12)),
                  const SizedBox(height: 18),
                  _field(
                    label: 'Bio',
                    hint: 'A little about your style (optional)',
                    controller: _bioController,
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: GlassGradients.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: colors.graphite,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? prefixText,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final colors = context.trenzyColors;
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: label == 'Bio' ? TextCapitalization.sentences : TextCapitalization.words,
      style: TextStyle(color: colors.foreground),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon, color: colors.primary),
        labelStyle: TextStyle(color: colors.mutedFg),
        hintStyle: TextStyle(color: colors.mutedFg.withValues(alpha: .7)),
        filled: true,
        fillColor: colors.graphite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.primary, width: 1.5)),
      ),
    );
  }
}
