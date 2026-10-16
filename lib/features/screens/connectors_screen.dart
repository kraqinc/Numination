import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/theme_controller.dart';
import '../widgets/numi_loading_animation.dart';

class ConnectorsScreen extends ConsumerStatefulWidget {
  const ConnectorsScreen({super.key});

  @override
  ConsumerState<ConnectorsScreen> createState() => _ConnectorsScreenState();
}

class _ConnectorsScreenState extends ConsumerState<ConnectorsScreen>
    with WidgetsBindingObserver {
  final Map<String, Map<String, dynamic>> _providers = {};
  bool _loading = true;
  bool _busy = false;
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (_busy) {
      return;
    }
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
      final list = (decoded['providers'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _providers
          ..clear()
          ..addEntries(list.map((row) => MapEntry(row['id'].toString(), row)));
        _callbackUrl = decoded['callbackUrl']?.toString();
        _encryptionConfigured = decoded['encryptionConfigured'] == true;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'No pudimos consultar los conectores.';
        _loading = false;
      });
    } finally {
      _busy = false;
    }
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
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final response = await ApiClient.post('/integrations/start', {
        'provider': provider,
      });
      final data = ApiClient.decode(response) as Map<String, dynamic>;
      final authUrl = Uri.tryParse(data['authorizationUrl']?.toString() ?? '');
      if (authUrl == null ||
          !authUrl.hasScheme ||
          !['https'].contains(authUrl.scheme)) {
        throw const ApiException(
          502,
          'El servidor no devolvió una URL de autorización válida.',
        );
      }
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const ApiException(
          502,
          'No se pudo abrir la página de autorización.',
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Termina la autorización en el navegador y vuelve a Numination.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is ApiException
          ? error.message
          : 'No se pudo iniciar la conexión.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _load(silent: true);
    }
  }

  String _consentNotice(String provider) {
    switch (provider) {
      case 'google':
        return 'Numination solicitará acceso de solo lectura a Gmail, Google Drive y Calendar. Revisa los permisos que muestra Google antes de aceptar.';
      case 'microsoft':
        return 'Numination solicitará acceso de solo lectura a Outlook Mail, Calendar y archivos de OneDrive. Comprueba los permisos de Microsoft antes de aceptar.';
      case 'github':
        return 'GitHub puede solicitar el alcance repo, que es amplio e incluye repositorios privados. Revisa cuidadosamente el permiso en GitHub y conecta solo una cuenta que estés autorizado a usar.';
      default:
        return 'Numination solicitará acceso al contenido de Notion que autorices. Revisa el espacio de trabajo y los permisos antes de aceptar.';
    }
  }

  Future<void> _showProviderSetup(String provider) async {
    final env = switch (provider) {
      'google' => 'GOOGLE_OAUTH_CLIENT_ID\nGOOGLE_OAUTH_CLIENT_SECRET',
      'microsoft' => 'MICROSOFT_OAUTH_CLIENT_ID\nMICROSOFT_OAUTH_CLIENT_SECRET',
      'github' => 'GITHUB_OAUTH_CLIENT_ID\nGITHUB_OAUTH_CLIENT_SECRET',
      _ => 'NOTION_OAUTH_CLIENT_ID\nNOTION_OAUTH_CLIENT_SECRET',
    };
    final text =
        'Configura estos secretos en Supabase Edge Function Secrets:\n\n$env\nINTEGRATION_TOKEN_ENCRYPTION_KEY\n\nDespués registra esta URL exacta como Redirect URI en el proveedor:\n\n${_callbackUrl ?? 'Consulta GET /integrations para obtenerla.'}\n\nLa clave de cifrado debe ser aleatoria y de 32 bytes codificados en Base64. No la pegues en el código, en GitHub ni en el APK.';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('OAuth pendiente de configurar'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (_callbackUrl != null) {
                unawaited(
                  Clipboard.setData(ClipboardData(text: _callbackUrl!)),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL de callback copiada.')),
                );
              }
            },
            child: const Text('Copiar callback'),
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
        title: Text('Desconectar $label'),
        content: const Text(
          'Numination eliminará los tokens guardados. Para quitar también el consentimiento del proveedor, revisa las aplicaciones conectadas de esa cuenta.',
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
    if (confirmed != true) {
      return;
    }
    try {
      final response = await ApiClient.post('/integrations/disconnect', {
        'provider': provider,
      });
      ApiClient.decode(response);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'No se pudo desconectar la cuenta.',
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
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      if (!mounted) {
        return;
      }
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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
                        icon: const Icon(LucideIcons.x),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'No hay elementos para mostrar.',
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
                                'Elemento';
                            final subtitleParts = <String>[];
                            final from = item['from']?.toString();
                            final description = item['description']?.toString();
                            final snippet = item['snippet']?.toString();
                            final when =
                                item['start']?.toString() ??
                                item['receivedAt']?.toString() ??
                                item['modifiedAt']?.toString() ??
                                item['lastEditedTime']?.toString();
                            if (from != null && from.isNotEmpty) {
                              subtitleParts.add(from);
                            }
                            if (when != null && when.isNotEmpty) {
                              subtitleParts.add(when);
                            }
                            if (description != null && description.isNotEmpty) {
                              subtitleParts.add(description);
                            }
                            if (snippet != null && snippet.isNotEmpty) {
                              subtitleParts.add(snippet);
                            }
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
                              trailing:
                                  _safeUrl(item['url']?.toString()) == null
                                  ? null
                                  : const Icon(
                                      LucideIcons.externalLink,
                                      size: 17,
                                    ),
                              onTap: () {
                                final uri = _safeUrl(item['url']?.toString());
                                if (uri != null) {
                                  unawaited(
                                    launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  );
                                }
                              },
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'No se pudieron cargar los datos del servicio.',
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
    _ => const [_ConnectorResource('Páginas', 'pages', LucideIcons.blocks)],
  };

  IconData _brandIcon(String provider) => switch (provider) {
    'google' => SimpleIcons.google,
    'microsoft' => LucideIcons.mail,
    'github' => SimpleIcons.github,
    _ => SimpleIcons.notion,
  };

  Color _brandColor(String provider) => switch (provider) {
    'google' => const Color(0xFF4285F4),
    'microsoft' => const Color(0xFF0078D4),
    'github' => const Color(0xFFB8C3D1),
    _ => const Color(0xFFFFFFFF),
  };

  String _label(String id) => switch (id) {
    'google' => 'Google Workspace',
    'microsoft' => 'Microsoft 365',
    'github' => 'GitHub',
    _ => 'Notion',
  };

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(appPaletteProvider);
    const providerIds = ['google', 'microsoft', 'github', 'notion'];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          'Conectores',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar conexiones',
            onPressed: () => _load(),
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
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
                    Text(_error!, textAlign: TextAlign.center),
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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 12),
                        child: child,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.link2, color: palette.accent),
                              const SizedBox(width: 10),
                              Text(
                                'Tu workspace, conectado',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Conecta tus servicios para consultar correo, archivos, eventos, repositorios y páginas desde Numination. Las conexiones usan permisos de lectura en los servicios que lo permiten.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _encryptionConfigured
                                    ? LucideIcons.shieldCheck
                                    : LucideIcons.shieldAlert,
                                size: 16,
                                color: _encryptionConfigured
                                    ? palette.accent
                                    : palette.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _encryptionConfigured
                                      ? 'Cifrado de tokens configurado'
                                      : 'El servidor aún necesita completar la configuración OAuth y el cifrado',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...providerIds.asMap().entries.map((entry) {
                    final index = entry.key;
                    final id = entry.value;
                    final provider = _providers[id] ?? <String, dynamic>{};
                    final configured = provider['configured'] == true;
                    final connected = provider['connected'] == true;
                    final resources = _resources(id);
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(id),
                      tween: Tween(begin: .96, end: 1),
                      duration: Duration(milliseconds: 220 + index * 80),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: connected
                                ? palette.accent.withValues(alpha: .55)
                                : palette.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: palette.background,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: palette.border),
                                  ),
                                  child: Icon(
                                    _brandIcon(id),
                                    size: 23,
                                    color: _brandColor(id),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _label(id),
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        provider['accountEmail']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? provider['accountEmail']
                                                  .toString()
                                            : _description(id),
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (connected
                                                      ? palette.accent
                                                      : palette.textSecondary)
                                                  .withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Text(
                                          connected
                                              ? 'Conectado'
                                              : configured
                                              ? 'Listo para conectar'
                                              : 'OAuth por configurar',
                                          style: TextStyle(
                                            color: connected
                                                ? palette.accent
                                                : palette.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: resources
                                  .map(
                                    (resource) => OutlinedButton.icon(
                                      onPressed: connected
                                          ? () => _loadResource(
                                              id,
                                              resource.resource,
                                              resource.label,
                                            )
                                          : null,
                                      icon: Icon(resource.icon, size: 15),
                                      label: Text(resource.label),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: palette.textPrimary,
                                        side: BorderSide(color: palette.border),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: connected
                                        ? () => _disconnect(id, _label(id))
                                        : configured
                                        ? () => _startConnection(id)
                                        : () => _showProviderSetup(id),
                                    icon: Icon(
                                      connected
                                          ? LucideIcons.unlink
                                          : configured
                                          ? LucideIcons.link
                                          : LucideIcons.settings2,
                                      size: 17,
                                    ),
                                    label: Text(
                                      connected
                                          ? 'Desconectar'
                                          : configured
                                          ? 'Conectar'
                                          : 'Configurar OAuth',
                                    ),
                                  ),
                                ),
                                if (id == 'github')
                                  IconButton(
                                    tooltip: 'Ver detalle de permisos',
                                    onPressed: () =>
                                        _showGithubPermissionInfo(),
                                    icon: const Icon(
                                      LucideIcons.info,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Numination no muestra una cuenta como conectada hasta que el proveedor termina OAuth. Desconectar elimina las credenciales almacenadas por Numination; también puedes revocar el consentimiento desde los ajustes de la cuenta externa.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _description(String provider) => switch (provider) {
    'google' => 'Gmail, Drive y Google Calendar',
    'microsoft' => 'Outlook, Calendar y OneDrive',
    'github' => 'Repositorios y código fuente',
    _ => 'Páginas y documentos de Notion',
  };

  Future<void> _showGithubPermissionInfo() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos de GitHub'),
        content: const Text(
          'El OAuth clásico con alcance repo puede permitir acceso amplio a repositorios privados. Autoriza solo tu cuenta de confianza. Para un lanzamiento público, es preferible migrar a una GitHub App con permisos específicos de lectura y Pull Requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
