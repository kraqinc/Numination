import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/theme_controller.dart';
import 'projects_screen.dart';

class CoderScreen extends ConsumerStatefulWidget {
  const CoderScreen({super.key});

  @override
  ConsumerState<CoderScreen> createState() => _CoderScreenState();
}

class _CoderScreenState extends ConsumerState<CoderScreen> {
  final _nameController = TextEditingController(text: 'Mi proyecto');
  bool _isCreating = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _isCreating) return;

    setState(() {
      _isCreating = true;
      _errorText = null;
    });

    try {
      await ApiClient.post('/projects', {
        'name': name,
      });

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ProjectsScreen(),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isCreating = false;
        _errorText = 'No se pudo crear el proyecto';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(
          color: palette.textPrimary,
        ),
        title: Text(
          'Coder',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.code_rounded,
                      color: palette.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Nuevo proyecto Coder',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea el espacio donde vas a trabajar con Numination.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Nombre del proyecto',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _createProject(),
                    cursorColor: palette.accent,
                    style: TextStyle(
                      color: palette.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej. Numination App',
                      hintStyle: TextStyle(
                        color: palette.textSecondary,
                      ),
                      filled: true,
                      fillColor: palette.surfaceAlt,
                      prefixIcon: Icon(
                        Icons.folder_copy_outlined,
                        color: palette.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
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
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createProject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            palette.accent.withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              AppLocale.t('create'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: palette.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: palette.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Coder está disponible gratis por ahora. El proyecto quedará guardado en tu cuenta.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}