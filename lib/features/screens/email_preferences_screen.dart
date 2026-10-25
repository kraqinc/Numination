import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/theme_controller.dart';

class EmailPreferencesScreen extends ConsumerStatefulWidget {
  const EmailPreferencesScreen({super.key});

  @override
  ConsumerState<EmailPreferencesScreen> createState() =>
      _EmailPreferencesScreenState();
}

class _EmailPreferencesScreenState
    extends ConsumerState<EmailPreferencesScreen> {
  final Map<String, bool> _preferences = {
    'login_alerts_enabled': true,
    'product_updates_enabled': false,
    'newsletter_enabled': false,
  };
  bool _loading = true;
  String? _error;
  final Set<String> _saving = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient.get('/email-preferences');
      final data = Map<String, dynamic>.from(ApiClient.decode(response) as Map);
      if (!mounted) return;
      setState(() {
        for (final key in _preferences.keys) {
          _preferences[key] = data[key] is bool
              ? data[key] as bool
              : _defaultFor(key);
        }
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'No se pudieron cargar las preferencias de correo.';
        _loading = false;
      });
    }
  }

  bool _defaultFor(String key) => key == 'login_alerts_enabled';

  Future<void> _setPreference(String key, bool value) async {
    if (_saving.contains(key)) return;
    final previous = _preferences[key] ?? _defaultFor(key);
    setState(() {
      _preferences[key] = value;
      _saving.add(key);
      _error = null;
    });
    try {
      final response = await ApiClient.patch('/email-preferences', {
        key: value,
      });
      final data = Map<String, dynamic>.from(ApiClient.decode(response) as Map);
      if (!mounted) return;
      setState(() {
        for (final preference in _preferences.keys) {
          if (data[preference] is bool) {
            _preferences[preference] = data[preference] as bool;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _preferences[key] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'No se pudo guardar la preferencia.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(key));
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
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          'Correos de Numination',
          style: TextStyle(color: palette.textPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 38,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Elige qué correos quieres recibir. Las novedades y la newsletter son opcionales.',
                  style: TextStyle(color: palette.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 14),
                _PreferenceTile(
                  palette: palette,
                  icon: Icons.shield_outlined,
                  title: 'Nuevo inicio de sesión detectado',
                  subtitle:
                      'Avisos de seguridad cuando se detecte un inicio de sesión nuevo.',
                  value: _preferences['login_alerts_enabled']!,
                  saving: _saving.contains('login_alerts_enabled'),
                  onChanged: (value) =>
                      _setPreference('login_alerts_enabled', value),
                ),
                const SizedBox(height: 10),
                _PreferenceTile(
                  palette: palette,
                  icon: Icons.system_update_alt,
                  title: 'Nuevas actualizaciones',
                  subtitle:
                      'Novedades de Numination, funciones nuevas y cambios importantes.',
                  value: _preferences['product_updates_enabled']!,
                  saving: _saving.contains('product_updates_enabled'),
                  onChanged: (value) =>
                      _setPreference('product_updates_enabled', value),
                ),
                const SizedBox(height: 10),
                _PreferenceTile(
                  palette: palette,
                  icon: Icons.mark_email_unread_outlined,
                  title: 'Newsletter',
                  subtitle:
                      'Resúmenes de novedades y anuncios de producto por correo.',
                  value: _preferences['newsletter_enabled']!,
                  saving: _saving.contains('newsletter_enabled'),
                  onChanged: (value) =>
                      _setPreference('newsletter_enabled', value),
                ),
                const SizedBox(height: 16),
                Text(
                  'Los correos se envían cuando el servicio de correo de Numination está configurado. Puedes cambiar estas preferencias aquí.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final dynamic palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: saving ? null : onChanged,
        activeThumbColor: palette.accent,
        secondary: Icon(icon, color: palette.textPrimary),
        title: Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
