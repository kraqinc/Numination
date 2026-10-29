import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/theme_controller.dart';
import '../../core/theme.dart';
import '../widgets/numi_loading_animation.dart';

class ConnectorsScreen extends ConsumerStatefulWidget {
  const ConnectorsScreen({super.key});

  @override
  ConsumerState<ConnectorsScreen> createState() => _ConnectorsScreenState();
}

class _ConnectorsScreenState extends ConsumerState<ConnectorsScreen>
    with WidgetsBindingObserver {
  static const _providerIds = [
    'google',
    'microsoft',
    'github',
    'notion',
    'figma',
    'vercel',
    'supabase',
    'linear',
  ];

  final Map<String, Map<String, dynamic>> _providers = {};
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String _query = '';
  String? _error;
  String? _callbackUrl;
  bool _encryptionConfigured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await ApiClient.get('/integrations');
      final decoded = ApiClient.decode(response) as Map<String, dynamic>;
      final providers = (decoded['providers'] as List? ?? const [])
          .whereType()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _providers
          ..clear()
          ..addEntries(
            providers.map((row) => MapEntry(row['id'].toString(), row)),
          );
        _callbackUrl = decoded['callbackUrl']?.toString();
        _encryptionConfigured = decoded['encryptionConfigured'] == true;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'No pudimos consultar los conectores en este momento.';
        _loading = false;
      });
    } finally {
      _busy = false;
    }
  }

  bool _isConnected(String id) => _providers[id]?['connected'] == true;
  bool _isConfigured(String id) => _providers[id]?['configured'] == true;

  List<String> get _visibleProviderIds {
    if (_query.isEmpty) return _providerIds;
    return _providerIds
        .where((id) {
          final provider = _providers[id] ?? const <String, dynamic>{};
          final email = provider['accountEmail']?.toString() ?? '';
          final text = '${_label(id)} ${_description(id)} $email'.toLowerCase();
          return text.contains(_query);
        })
        .toList(growable: false);
  }

  Future<void> _startConnection(String provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ref.read(appPaletteProvider).surface,
        title: const Text('Conectar servicio'),
        content: Text(_consentNotice(provider)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final response = await ApiClient.post('/integrations/start', {
        'provider': provider,
      });
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final authUrl = Uri.tryParse(data['authorizationUrl']?.toString() ?? '');
      if (authUrl == null || !authUrl.hasScheme || authUrl.scheme != 'https') {
        throw const ApiException(
          502,
          'El servidor no devolvió una dirección web de autorización válida.',
        );
      }
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const ApiException(
          502,
          'No se pudo abrir la página de autorización externa.',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa la autorización en el navegador y regresa a Numination.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'No se pudo iniciar la conexión con el servicio.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _load(silent: true);
    }
  }

  String _consentNotice(String provider) {
    switch (provider) {
      case 'google':
        return 'Numination solicitará acceso de solo lectura a tus correos de Gmail, archivos de Google Drive y eventos del Calendario. Te recomendamos verificar los permisos directamente en la ventana de Google antes de aceptar.';
      case 'microsoft':
        return 'Numination solicitará acceso de solo lectura a Outlook, tu calendario y documentos en OneDrive. Comprueba los permisos de Microsoft antes de aceptar.';
      case 'github':
        return 'GitHub podría solicitar permisos amplios de repositorio (alcance repo) para acceder a tu código privado. Revisa cuidadosamente los alcances y conecta únicamente cuentas confiables.';
      case 'notion':
        return 'Numination solicitará acceso al espacio de trabajo y contenido de Notion que decidas autorizar.';
      case 'figma':
        return 'Revisa los permisos que Figma solicita para acceder de forma segura a tus diseños, archivos y comentarios.';
      case 'vercel':
        return 'Comprueba los permisos solicitados para visualizar tus proyectos, despliegues y ajustes en Vercel.';
      case 'supabase':
        return 'Revisa con atención los permisos solicitados sobre tus bases de datos y recursos en Supabase antes de autorizar.';
      case 'linear':
        return 'Comprueba los permisos solicitados para acceder a las incidencias, proyectos y equipos de Linear.';
      default:
        return 'Numination solicitará acceso al contenido del servicio que autorices. Revisa los permisos antes de continuar.';
    }
  }

  Future<void> _showProviderSetup(String provider) async {
    final serviceName = _label(provider);
    final setupText = 'Para habilitar la conexión con $serviceName, es necesario configurar las credenciales de acceso (Client ID y Client Secret) junto con la clave de seguridad de cifrado en las variables del servidor.\n\n'
        '1. Registra las credenciales de la aplicación en los secretos del servidor.\n'
        '2. Configura la siguiente dirección web exacta como la URL de redirección (Redirect URI) en la plataforma del proveedor:\n\n'
        '${_callbackUrl ?? 'Consulta GET /integrations para obtener la URL.'}\n\n'
        'Asegúrate de que la clave de cifrado sea única, segura y esté protegida. Nunca la expongas en código público o repositorios.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ref.read(appPaletteProvider).surface,
        title: Text('Configuración pendiente para $serviceName'),
        content: SingleChildScrollView(child: SelectableText(setupText)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (_callbackUrl != null) {
                unawaited(
                  Clipboard.setData(ClipboardData(text: _callbackUrl!)),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('La dirección de callback se ha copiado al portapapeles.')),
                );
              }
            },
            child: const Text('Copiar enlace'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnect(String provider, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ref.read(appPaletteProvider).surface,
        title: Text('Desconectar $label'),
        content: const Text(
          'Numination eliminará de forma segura los accesos guardados. Si deseas revocar el permiso por completo, también puedes hacerlo desde la configuración de aplicaciones conectadas de tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await ApiClient.post('/integrations/disconnect', {
        'provider': provider,
      });
      ApiClient.decode(response);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'No se pudo desconectar la cuenta en este momento.',
          ),
        ),
      );
    }
  }

  Future<void> _loadResource(
    String provider,
    String resource,
    String title,
  ) async {
    try {
      final response = await ApiClient.get(
        '/integrations/data?provider=$provider&resource=$resource',
      );
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final items = (data['items'] as List? ?? const [])
          .whereType()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      if (!mounted) return;
      final palette = ref.read(appPaletteProvider);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: palette.surface,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(LucideIcons.x, color: palette.textPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'No hay elementos disponibles para mostrar.',
                            style: TextStyle(color: palette.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              Divider(color: palette.border, height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final itemTitle =
                                item['title']?.toString() ??
                                item['subject']?.toString() ??
                                'Elemento sin título';
                            final subtitleParts = <String>[];
                            for (final key in [
                              'from',
                              'start',
                              'receivedAt',
                              'modifiedAt',
                              'lastEditedTime',
                              'description',
                              'snippet',
                            ]) {
                              final value = item[key]?.toString();
                              if (value != null &&
                                  value.isNotEmpty &&
                                  subtitleParts.length < 4) {
                                subtitleParts.add(value);
                              }
                            }
                            final uri = _safeUrl(item['url']?.toString());
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: palette.accent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _itemIcon(resource),
                                  color: palette.accent,
                                  size: 19,
                                ),
                              ),
                              title: Text(
                                itemTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: subtitleParts.isEmpty
                                  ? null
                                  : Text(
                                      subtitleParts.join(' · '),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                              trailing: uri == null
                                  ? null
                                  : Icon(
                                      LucideIcons.externalLink,
                                      size: 17,
                                      color: palette.textSecondary,
                                    ),
                              onTap: uri == null
                                  ? null
                                  : () => unawaited(
                                      launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      ),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'No se pudieron consultar los datos de este servicio.',
          ),
        ),
      );
    }
  }

  Uri? _safeUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null ||
        !uri.hasScheme ||
        !['https', 'http'].contains(uri.scheme)) {
      return null;
    }
    return uri;
  }

  IconData _itemIcon(String resource) => switch (resource) {
    'calendar' => LucideIcons.calendarDays,
    'drive' => LucideIcons.fileText,
    'repositories' => LucideIcons.gitBranch,
    'pages' => LucideIcons.blocks,
    'files' => LucideIcons.fileText,
    'comments' => LucideIcons.mail,
    'versions' => LucideIcons.gitBranch,
    'projects' => LucideIcons.folderOpen,
    'deployments' => LucideIcons.gitBranch,
    'domains' => LucideIcons.blocks,
    'logs' => LucideIcons.fileText,
    'sql' => LucideIcons.fileText,
    'auth' => LucideIcons.shieldAlert,
    'storage' => LucideIcons.folderOpen,
    'issues' => LucideIcons.gitBranch,
    'teams' => LucideIcons.blocks,
    _ => LucideIcons.mail,
  };

  List<_ConnectorResource> _resources(String provider) => switch (provider) {
    'google' => const [
      _ConnectorResource('Gmail', 'gmail', LucideIcons.mail),
      _ConnectorResource('Drive', 'drive', LucideIcons.folderOpen),
      _ConnectorResource('Calendar', 'calendar', LucideIcons.calendarDays),
    ],
    'microsoft' => const [
      _ConnectorResource('Outlook', 'mail', LucideIcons.mail),
      _ConnectorResource('Calendar', 'calendar', LucideIcons.calendarDays),
      _ConnectorResource('OneDrive', 'drive', LucideIcons.folderOpen),
    ],
    'github' => const [
      _ConnectorResource('Repositorios', 'repositories', LucideIcons.gitBranch),
    ],
    'notion' => const [
      _ConnectorResource('Páginas', 'pages', LucideIcons.blocks),
    ],
    'figma' => const [
      _ConnectorResource('Archivos', 'files', LucideIcons.fileText),
      _ConnectorResource('Comentarios', 'comments', LucideIcons.mail),
      _ConnectorResource('Versiones', 'versions', LucideIcons.gitBranch),
    ],
    'vercel' => const [
      _ConnectorResource('Proyectos', 'projects', LucideIcons.folderOpen),
      _ConnectorResource('Despliegues', 'deployments', LucideIcons.gitBranch),
      _ConnectorResource('Dominios', 'domains', LucideIcons.blocks),
      _ConnectorResource('Logs', 'logs', LucideIcons.fileText),
    ],
    'supabase' => const [
      _ConnectorResource('Proyectos', 'projects', LucideIcons.folderOpen),
      _ConnectorResource('SQL', 'sql', LucideIcons.fileText),
      _ConnectorResource('Auth', 'auth', LucideIcons.shieldAlert),
      _ConnectorResource('Storage', 'storage', LucideIcons.folderOpen),
    ],
    'linear' => const [
      _ConnectorResource('Incidencias', 'issues', LucideIcons.gitBranch),
      _ConnectorResource('Proyectos', 'projects', LucideIcons.folderOpen),
      _ConnectorResource('Equipos', 'teams', LucideIcons.blocks),
    ],
    _ => const [],
  };

  IconData _brandIcon(String provider) => switch (provider) {
    'google' => SimpleIcons.google,
    'github' => SimpleIcons.github,
    'notion' => SimpleIcons.notion,
    'figma' => SimpleIcons.figma,
    'supabase' => SimpleIcons.supabase,
    'linear' => SimpleIcons.linear, // Corregido el error tipográfico anterior ('liear')
    'vercel' => SimpleIcons.vercel,
    _ => LucideIcons.mail,
  };

  Color _brandColor(String provider, AppPalette palette) => switch (provider) {
    'google' => const Color(0xFF4285F4),
    'microsoft' => const Color(0xFF0078D4),
    'github' =>
      palette.isDark ? const Color(0xFFB8C3D1) : const Color(0xFF24292F),
    'figma' => const Color(0xFFF24E1E),
    'vercel' =>
      palette.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111),
    'supabase' => const Color(0xFF3ECF8E),
    'linear' => const Color(0xFF8B69FF),
    _ => palette.textPrimary,
  };

  String _label(String id) => switch (id) {
    'google' => 'Google Workspace',
    'microsoft' => 'Microsoft 365',
    'github' => 'GitHub',
    'notion' => 'Notion',
    'figma' => 'Figma',
    'vercel' => 'Vercel',
    'supabase' => 'Supabase',
    'linear' => 'Linear',
    _ => id,
  };

  String _description(String id) => switch (id) {
    'google' => 'Gmail, Drive y Google Calendar',
    'microsoft' => 'Outlook, Calendar y OneDrive',
    'github' => 'Repositorios y código fuente',
    'notion' => 'Páginas y documentos de Notion',
    'figma' => 'Diseños, archivos y comentarios',
    'vercel' => 'Proyectos y despliegues',
    'supabase' => 'Bases de datos, Auth y proyectos',
    'linear' => 'Tareas, incidencias y proyectos',
    _ => 'Conecta tu cuenta de $id',
  };

  Widget _sectionTitle(String title, AppPalette palette, {String? count}) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (count != null)
            Text(
              count,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronRight,
            size: 19,
            color: palette.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _brandTile(String id, AppPalette palette, {double size = 60}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(
        _brandIcon(id),
        size: size * .43,
        color: _brandColor(id, palette),
      ),
    );
  }

  Future<void> _showConnectorActions(String id) async {
    final palette = ref.read(appPaletteProvider);
    final connected = _isConnected(id);
    final configured = _isConfigured(id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _brandTile(id, palette, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _label(id),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          connected
                              ? 'Conectado exitosamente'
                              : configured
                              ? 'Listo para conectar'
                              : 'Configuración pendiente',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (connected) ...[
                ..._resources(id).map(
                  (resource) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(resource.icon, color: palette.textSecondary),
                    title: Text(
                      resource.label,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: palette.textSecondary,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      unawaited(
                        _loadResource(id, resource.resource, resource.label),
                      );
                    },
                  ),
                ),
                if (id == 'github')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      LucideIcons.shieldAlert,
                      color: palette.textSecondary,
                    ),
                    title: Text(
                      'Revisar permisos de acceso',
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      unawaited(_showGithubPermissionInfo());
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    LucideIcons.unlink,
                    color: Color(0xFFE05A5A),
                  ),
                  title: const Text(
                    'Desconectar cuenta',
                    style: TextStyle(color: Color(0xFFE05A5A)),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_disconnect(id, _label(id)));
                  },
                ),
              ] else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    configured ? LucideIcons.plus : LucideIcons.settings2,
                    color: palette.textPrimary,
                  ),
                  title: Text(
                    configured ? 'Conectar cuenta' : 'Configurar acceso',
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(
                      configured
                          ? _startConnection(id)
                          : _showProviderSetup(id),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectorRow(String id, AppPalette palette) {
    final connected = _isConnected(id);
    final configured = _isConfigured(id);
    final email = _providers[id]?['accountEmail']?.toString();
    final subtitle = connected && email != null && email.isNotEmpty
        ? 'Conectado · $email'
        : connected
        ? 'Conectado · ${_description(id)}'
        : _description(id);

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (connected) {
              unawaited(_showConnectorActions(id));
            } else if (configured) {
              unawaited(_startConnection(id));
            } else {
              unawaited(_showProviderSetup(id));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            child: Row(
              children: [
                _brandTile(id, palette),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: connected
                              ? palette.accent
                              : palette.textSecondary,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                      if (!connected && !configured) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Requiere configuración previa',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: connected
                      ? 'Opciones de ${_label(id)}'
                      : configured
                      ? 'Conectar ${_label(id)}'
                      : 'Configurar ${_label(id)}',
                  onPressed: () {
                    if (connected || !configured) {
                      unawaited(_showConnectorActions(id));
                    } else {
                      unawaited(_startConnection(id));
                    }
                  },
                  icon: Icon(
                    configured && !connected
                        ? LucideIcons.plus
                        : LucideIcons.ellipsis,
                    size: configured && !connected ? 27 : 23,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: palette.border),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);
    final visibleIds = _visibleProviderIds;
    final connectedIds = visibleIds.where(_isConnected).toList(growable: false);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.maybePop(context),
          icon: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border),
            ),
            child: Icon(
              LucideIcons.arrowLeft,
              color: palette.textPrimary,
              size: 21,
            ),
          ),
        ),
        title: Text(
          'Conectores',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar conexiones',
            onPressed: () => unawaited(_load()),
            icon: Icon(
              LucideIcons.refreshCw,
              color: palette.textPrimary,
              size: 20,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: palette.background,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.search,
                    color: palette.textSecondary,
                    size: 23,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                      ),
                      cursorColor: palette.accent,
                      decoration: InputDecoration(
                        hintText: 'Buscar conectores',
                        hintStyle: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Limpiar búsqueda',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: Icon(
                        LucideIcons.x,
                        size: 19,
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading && _providers.isEmpty
          ? const Center(child: NumiLoadingAnimation())
          : _error != null && _providers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 6, 28, 28),
                children: [
                  if (connectedIds.isNotEmpty) ...[
                    _sectionTitle(
                      'Instalados',
                      palette,
                      count: '${connectedIds.length}',
                    ),
                    SizedBox(
                      height: 91,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: connectedIds.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final id = connectedIds[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => unawaited(_showConnectorActions(id)),
                            child: SizedBox(
                              width: 66,
                              child: Column(
                                children: [
                                  _brandTile(id, palette, size: 58),
                                  const SizedBox(height: 6),
                                  Text(
                                    _label(id)
                                        .replaceAll(' Workspace', '')
                                        .replaceAll(
                                          'Microsoft 365',
                                          'Microsoft',
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  _sectionTitle(
                    'Servicios disponibles',
                    palette,
                    count: '${visibleIds.length}',
                  ),
                  if (visibleIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 44),
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.searchX,
                            size: 32,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No encontramos ningún conector',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prueba escribiendo otro nombre.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...visibleIds.map((id) => _connectorRow(id, palette)),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _encryptionConfigured
                            ? LucideIcons.shieldCheck
                            : LucideIcons.shieldAlert,
                        size: 17,
                        color: _encryptionConfigured
                            ? palette.accent
                            : palette.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _encryptionConfigured
                              ? 'El sistema de cifrado está configurado correctamente. Recuerda revisar los permisos del servicio antes de autorizar.'
                              : 'El servidor requiere finalizar la configuración de seguridad y autenticación. Una cuenta aparecerá como conectada únicamente al completar el acceso.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showGithubPermissionInfo() async {
    final palette = ref.read(appPaletteProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: const Text('Información de permisos de GitHub'),
        content: const Text(
          'La autenticación tradicional con acceso total a repositorios otorga permisos amplios sobre tus proyectos privados. Asegúrate de conectar exclusivamente cuentas de confianza.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _ConnectorResource {
  const _ConnectorResource(this.label, this.resource, this.icon);
  final String label;
  final String resource;
  final IconData icon;
}