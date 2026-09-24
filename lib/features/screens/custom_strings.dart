import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api.dart';
import '../../core/auth_controller.dart';
import '../../core/i18n.dart';
import '../../core/models.dart';
import '../../core/theme_controller.dart';

class CustomStringsScreen extends ConsumerStatefulWidget {
  const CustomStringsScreen({super.key});

  @override
  ConsumerState<CustomStringsScreen> createState() =>
      _CustomStringsScreenState();
}

class _CustomStringsScreenState extends ConsumerState<CustomStringsScreen> {
  final _nameController = TextEditingController();
  final _pronounsController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pronounsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiClient.get('/auth/me');
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      final metadata =
          Supabase.instance.client.auth.currentUser?.userMetadata ?? {};

      final persistedAvatar =
          user.avatarUrl ??
          metadata['avatarUrl']?.toString() ??
          metadata['avatar_url']?.toString();

      if (!mounted) return;

      setState(() {
        _nameController.text = user.displayName ?? '';
        _pronounsController.text = user.pronouns ?? '';
        _avatarUrl = persistedAvatar;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'No se pudo cargar tu perfil';
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Sesión no encontrada');

      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath = '$userId/avatar.$ext';

      await client.storage
          .from('avatars')
          .upload(
            storagePath,
            File(picked.path),
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      final bustedUrl =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      var persisted = false;

      try {
        await ApiClient.patch('/auth/me', {
          'avatarUrl': publicUrl,
        });
        persisted = true;
      } catch (_) {}

      try {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'avatarUrl': publicUrl,
              'avatar_url': publicUrl,
            },
          ),
        );
        persisted = true;
      } catch (_) {}

      if (!persisted) {
        throw Exception('No se pudo guardar la foto');
      }

      if (!mounted) return;

      setState(() {
        _avatarUrl = bustedUrl;
        _isUploadingAvatar = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
        _errorText = 'No se pudo subir la foto';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ApiClient.patch('/auth/me', {
        'displayName': _nameController.text.trim(),
        'pronouns': _pronounsController.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } catch (e) {
      setState(() => _errorText = 'No se pudo guardar tu perfil');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final palette = ref.watch(appPaletteProvider);
    final email = auth is AuthAuthenticated ? auth.email : '';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          AppLocale.t('profile'),
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: palette.textPrimary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: palette.surfaceAlt,
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _isUploadingAvatar
                              ? CircularProgressIndicator(
                                  color: palette.textPrimary,
                                )
                              : (_avatarUrl == null
                                    ? Icon(
                                        Icons.person,
                                        color: palette.textSecondary,
                                        size: 44,
                                      )
                                    : null),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    email,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  AppLocale.t('name'),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _ProfileField(controller: _nameController, hint: 'Tu nombre'),
                const SizedBox(height: 20),
                Text(
                  AppLocale.t('pronouns'),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _ProfileField(
                  controller: _pronounsController,
                  hint: 'ej. él/ella/elle',
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            AppLocale.t('save'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfileField extends ConsumerWidget {
  const _ProfileField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(appPaletteProvider);
    return TextField(
      controller: controller,
      style: TextStyle(color: palette.textPrimary),
      cursorColor: palette.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: palette.textSecondary),
        filled: true,
        fillColor: palette.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
