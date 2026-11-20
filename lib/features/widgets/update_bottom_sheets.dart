import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/error_messages.dart';
import '../../core/update_service.dart';

class UpdateBottomSheets {
  static bool _startupCheckInFlight = false;

  static Future<void> checkOnLaunch(BuildContext context) async {
    if ((!Platform.isWindows && !Platform.isLinux) ||
        _startupCheckInFlight ||
        !await UpdateService.automaticUpdatesEnabled()) {
      return;
    }

    _startupCheckInFlight = true;
    try {
      final update = await UpdateService.checkForDesktopUpdate();
      if (update == null || !context.mounted) return;
      await _showUpdate(context, update, showObsoleteBanner: true);
    } catch (_) {
      // Un fallo de red no debe bloquear el inicio de Numination.
    } finally {
      _startupCheckInFlight = false;
    }
  }

  static Future<void> showVersionInfo(BuildContext context) async {
    final english = AppErrorMessages.isEnglish;
    final installed = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    AppUpdateInfo? latest;
    String? checkError;
    var checking = false;

    try {
      latest = await UpdateService.getLatestDesktopRelease();
    } catch (_) {
      checkError = english
          ? 'Could not check the latest version.'
          : 'No se pudo consultar la última versión.';
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final hasUpdate =
                latest != null &&
                UpdateService.isNewerVersion(
                  latest!.version,
                  installed.version,
                );
            final colors = Theme.of(sheetContext).colorScheme;

            Future<void> refresh() async {
              setSheetState(() {
                checking = true;
                checkError = null;
              });
              try {
                final refreshed = await UpdateService.getLatestDesktopRelease();
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  latest = refreshed;
                  checking = false;
                });
              } catch (_) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  checking = false;
                  checkError = english
                      ? 'Could not check the latest version.'
                      : 'No se pudo consultar la última versión.';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colors.primary,
                          size: 27,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            english
                                ? 'About Numination'
                                : 'Acerca de Numination',
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _VersionRow(
                      label: english
                          ? 'Installed version'
                          : 'Versión instalada',
                      value: installed.version,
                    ),
                    const SizedBox(height: 12),
                    _VersionRow(
                      label: english ? 'Build' : 'Compilación',
                      value: installed.buildNumber,
                    ),
                    const SizedBox(height: 12),
                    _VersionRow(
                      label: english ? 'Latest version' : 'Última versión',
                      value: checking
                          ? (english ? 'Checking...' : 'Consultando...')
                          : (latest?.version ?? '—'),
                    ),
                    const SizedBox(height: 16),
                    if (checking)
                      const LinearProgressIndicator()
                    else if (checkError != null)
                      Text(checkError!, style: TextStyle(color: colors.error))
                    else if (hasUpdate)
                      Text(
                        english
                            ? 'A new version is ready to install.'
                            : 'Hay una nueva versión lista para instalar.',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        latest == null
                            ? (english
                                  ? 'No release is available for this platform yet.'
                                  : 'Todavía no hay una versión publicada para esta plataforma.')
                            : (english
                                  ? 'Numination is up to date.'
                                  : 'Numination está actualizado.'),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    if (latest != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'SHA-256',
                        style: Theme.of(sheetContext).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        latest!.sha256,
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: checking ? null : refresh,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(english ? 'Check again' : 'Comprobar'),
                          ),
                        ),
                        if (hasUpdate) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                final update = latest!;
                                Navigator.of(sheetContext).pop();
                                if (context.mounted) {
                                  await _showUpdate(
                                    context,
                                    update,
                                    showObsoleteBanner: false,
                                  );
                                }
                              },
                              icon: const Icon(Icons.download_rounded),
                              label: Text(english ? 'Update' : 'Actualizar'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _showUpdate(
    BuildContext context,
    AppUpdateInfo update, {
    required bool showObsoleteBanner,
  }) async {
    final english = AppErrorMessages.isEnglish;
    var downloading = false;
    var progress = 0.0;
    String? errorMessage;

    final installedLater = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final colors = Theme.of(sheetContext).colorScheme;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.system_update_alt_rounded,
                        color: colors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          english
                              ? 'A new Numination update is available'
                              : 'Hay una actualización nueva en Numination',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    english
                        ? 'Version ${update.version} is ready. Install it to get the latest improvements and fixes.'
                        : 'La versión ${update.version} ya está disponible. Instálala para recibir las últimas mejoras y correcciones.',
                  ),
                  if (downloading) ...[
                    const SizedBox(height: 22),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 9),
                    Text(
                      english
                          ? 'Downloading and verifying: ${(progress * 100).round()}%'
                          : 'Descargando y verificando: ${(progress * 100).round()}%',
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(errorMessage!, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: downloading
                              ? null
                              : () => Navigator.of(sheetContext).pop(false),
                          child: Text(english ? 'Not now' : 'Ahora no'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: downloading
                              ? null
                              : () async {
                                  setSheetState(() {
                                    downloading = true;
                                    progress = 0;
                                    errorMessage = null;
                                  });
                                  try {
                                    await UpdateService.installDesktopUpdate(
                                      update,
                                      onProgress: (value) {
                                        if (!sheetContext.mounted) return;
                                        setSheetState(() => progress = value);
                                      },
                                    );
                                  } catch (_) {
                                    if (!sheetContext.mounted) return;
                                    setSheetState(() {
                                      downloading = false;
                                      errorMessage = english
                                          ? 'The update could not be downloaded, verified or installed. Check that the app file is in a writable folder and try again.'
                                          : 'No se pudo descargar, verificar o instalar la actualización. Comprueba que el archivo esté en una carpeta con permisos de escritura e inténtalo otra vez.';
                                    });
                                  }
                                },
                          icon: const Icon(Icons.download_rounded),
                          label: Text(english ? 'Install' : 'Instalar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );

    if (installedLater != true && showObsoleteBanner && context.mounted) {
      _showObsoleteBottomSheet(context, update);
    }
  }

  static Future<void> _showObsoleteBottomSheet(
    BuildContext context,
    AppUpdateInfo update,
  ) async {
    if (!context.mounted) return;
    final english = AppErrorMessages.isEnglish;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      english
                          ? 'Your version is outdated'
                          : 'Tu versión está obsoleta',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                english
                    ? 'Update Numination to version ${update.version} to receive the latest improvements and fixes.'
                    : 'Actualiza Numination a la versión ${update.version} para recibir las últimas mejoras y correcciones.',
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(english ? 'Later' : 'Luego'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(
                          _showUpdate(
                            context,
                            update,
                            showObsoleteBanner: false,
                          ),
                        );
                      },
                      icon: const Icon(Icons.system_update_alt_rounded),
                      label: Text(english ? 'Update now' : 'Actualizar ahora'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
        ),
        const SizedBox(width: 12),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
