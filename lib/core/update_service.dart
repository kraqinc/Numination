import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.tag,
    required this.sha256,
    required this.sizeBytes,
    required this.assetName,
  });

  final String version;
  final String tag;
  final String sha256;
  final int sizeBytes;
  final String assetName;
}

class UpdateService {
  static const MethodChannel _channel = MethodChannel('numination.updater');

  static const String _lastCheckKey = 'last_update_check';
  static const String _desktopLastCheckKey = 'last_desktop_update_check';
  static const String _windowsLastCheckKey = 'last_windows_update_check';
  static const String _pendingApkPathKey = 'pending_apk_path';

  static const Duration _minimumCheckInterval = Duration(minutes: 2);

  static const int _maximumApkBytes = 250 * 1024 * 1024;
  static const int _maximumDesktopAssetBytes = 500 * 1024 * 1024;

  static bool _checkInFlight = false;
  static bool _desktopCheckInFlight = false;
  static bool _windowsCheckInFlight = false;
  static bool _permissionPromptInFlight = false;
  static bool _permissionPromptedThisLaunch = false;
  static Timer? _automaticCheckTimer;

  /// Una comprobación como máximo cada dos minutos.
  static void startAutomaticChecks() {
    if (!Platform.isAndroid || _automaticCheckTimer != null) return;

    _automaticCheckTimer = Timer.periodic(
      _minimumCheckInterval,
      (_) => unawaited(checkAndInstallIfEnabled()),
    );
  }

  static void stopAutomaticChecks() {
    _automaticCheckTimer?.cancel();
    _automaticCheckTimer = null;
  }

  static Uri _endpoint(
    String action, {
    String platform = 'android',
    Map<String, String> query = const {},
  }) {
    final parsedBase = Uri.tryParse(Env.supabaseUrl.trim());
    if (parsedBase == null ||
        parsedBase.scheme != 'https' ||
        parsedBase.host.isEmpty ||
        parsedBase.userInfo.isNotEmpty ||
        parsedBase.hasQuery ||
        parsedBase.hasFragment) {
      throw const FormatException(
        'Numination updater requires a valid HTTPS Supabase URL.',
      );
    }
    final base = parsedBase.toString().replaceFirst(RegExp(r'/+$'), '');

    return Uri.parse('$base/functions/v1/numination-updater').replace(
      queryParameters: {'action': action, 'platform': platform, ...query},
    );
  }

  static Map<String, String> _headers({bool binary = false}) {
    final headers = <String, String>{
      'Accept': binary ? 'application/octet-stream' : 'application/json',
      'User-Agent': 'Numination-Updater',
    };

    final publishableKey = Env.supabasePublishableKey.trim();

    if (publishableKey.isNotEmpty) {
      headers['apikey'] = publishableKey;
    }

    // El endpoint protegido necesita la sesión autenticada
    // del usuario. Nunca se incluye el token de GitHub aquí.
    try {
      final accessToken =
          Supabase.instance.client.auth.currentSession?.accessToken;

      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[NuminationUpdater] No hay sesión disponible: $error');
      }
    }

    return headers;
  }

  static Future<bool> _enabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool('auto_update_apk') ?? true;
  }

  static Future<bool> _canInstallPackages() async {
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  /// Muestra el aviso al abrir el Home si Android todavía
  /// no permite instalar paquetes desde Numination.
  ///
  /// Devuelve true cuando abrió los ajustes. En ese caso,
  /// el chequeo de versiones se hará al regresar a la app.
  static Future<bool> promptForAutoUpdatesPermission(
    BuildContext context,
  ) async {
    if (!Platform.isAndroid || !await _enabled()) {
      return false;
    }

    if (_permissionPromptedThisLaunch || _permissionPromptInFlight) {
      return false;
    }

    _permissionPromptInFlight = true;

    try {
      final allowed = await _canInstallPackages();

      if (allowed || !context.mounted) {
        return false;
      }

      _permissionPromptedThisLaunch = true;

      final activate = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(LucideIcons.refreshCw, size: 30),
            title: const Text(
              'Activa las actualizaciones automáticas',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Para mantener Numination al día y recibir '
              'mejoras de rendimiento y seguridad, activa '
              'el permiso de instalación para Numination.\n\n'
              'En los ajustes de Android, habilita '
              '«Permitir desde esta fuente».\n\n'
              'Android seguirá solicitando confirmación '
              'para instalar cada actualización.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Activar permiso'),
              ),
            ],
          );
        },
      );

      if (activate != true || !context.mounted) {
        return false;
      }

      // Evita que el intervalo anterior impida consultar
      // las versiones al regresar de Ajustes.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastCheckKey);

      final opened =
          await _channel.invokeMethod<bool>('openUnknownSourcesSettings') ??
          false;

      if (!opened && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('No se pudieron abrir los ajustes de instalación.'),
          ),
        );
      }

      return opened;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[NuminationUpdater] Error mostrando el permiso: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      return false;
    } finally {
      _permissionPromptInFlight = false;
    }
  }

  /// Comprueba si hay una versión más reciente para Windows.
  static Future<AppUpdateInfo?> checkForWindowsUpdate() async {
    if (!Platform.isWindows || kDebugMode || _windowsCheckInFlight) {
      return null;
    }

    _windowsCheckInFlight = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastCheck = prefs.getInt(_windowsLastCheckKey) ?? 0;

      if (now - lastCheck < _minimumCheckInterval.inMilliseconds) {
        return null;
      }

      await prefs.setInt(_windowsLastCheckKey, now);

      final update = await _checkLatest(platform: 'windows');

      if (update == null) {
        return null;
      }

      final installedVersion = await installedDesktopVersion();

      if (!_isNewerVersion(update.version, installedVersion)) {
        return null;
      }

      return update;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[NuminationUpdater:Windows] $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      return null;
    } finally {
      _windowsCheckInFlight = false;
    }
  }

  /// Consulta la última Release estable y prepara la instalación
  /// únicamente si existe una versión más reciente.
  static Future<void> checkAndInstallIfEnabled({
    bool force = false,
    ValueChanged<Object>? onError,
  }) async {
    if (!Platform.isAndroid || kDebugMode || _checkInFlight) {
      return;
    }

    _checkInFlight = true;

    try {
      if (!await _enabled()) return;
      // Recupera primero una descarga pendiente de una ejecución
      // anterior, si existe.
      if (Platform.isAndroid && await _resumePendingInstall()) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now().millisecondsSinceEpoch;
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;

      if (!force && now - lastCheck < _minimumCheckInterval.inMilliseconds) {
        return;
      }

      // Registrar únicamente después de recibir correctamente la respuesta.
      final update = await _checkLatest();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      if (update == null) return;

      final installed = await PackageInfo.fromPlatform();

      if (!_isNewerVersion(update.version, installed.version)) {
        return;
      }

      // Si falta el permiso, no descargar el APK todavía.
      // El aviso se muestra desde HomeScreen.
      if (!await _canInstallPackages()) {
        return;
      }

      final apk = await _downloadAndVerify(update);

      // Comprobar otra vez antes de abrir el instalador.
      if (!await _canInstallPackages()) {
        await prefs.setString(_pendingApkPathKey, apk.path);
        return;
      }

      await _channel.invokeMethod<void>('installApk', <String, dynamic>{
        'path': apk.path,
      });

      await prefs.remove(_pendingApkPathKey);
    } catch (error, stackTrace) {
      // Un fallo de actualización nunca debe impedir utilizar
      // el resto de la aplicación.
      debugPrint('[NuminationUpdater] $error');
      debugPrintStack(stackTrace: stackTrace);

      try {
        onError?.call(error);
      } catch (_) {
        // Un error de presentación no debe romper el actualizador.
      }
    } finally {
      _checkInFlight = false;
    }
  }

  static Future<bool> automaticUpdatesEnabled() => _enabled();

  static String get _desktopPlatform =>
      Platform.isWindows ? 'windows' : 'linux';

  static bool isNewerVersion(String remote, String local) =>
      _isNewerVersion(remote, local);

  static Future<AppUpdateInfo?> getLatestDesktopRelease() async {
    if (!Platform.isWindows && !Platform.isLinux) return null;
    return _checkLatest(platform: _desktopPlatform);
  }

  /// Devuelve la versión configurada durante la compilación
  /// de la aplicación de escritorio.
  static Future<String> installedDesktopVersion({
    String? fallbackVersion,
  }) async {
    final packageVersion =
        fallbackVersion ?? (await PackageInfo.fromPlatform()).version.trim();

    if (!Platform.isWindows && !Platform.isLinux) {
      return packageVersion;
    }

    final configuredVersion = Env.appVersion.trim();

    if (RegExp(r'^\d+\.\d+\.\d+$').hasMatch(configuredVersion)) {
      if (packageVersion.isNotEmpty &&
          packageVersion != configuredVersion &&
          kDebugMode) {
        debugPrint(
          '[NuminationUpdater] Version mismatch: '
          'APP_VERSION=$configuredVersion, '
          'PackageInfo=$packageVersion',
        );
      }

      return configuredVersion;
    }

    return packageVersion;
  }

  static Future<AppUpdateInfo?> checkForDesktopUpdate({
    bool force = false,
  }) async {
    if ((!Platform.isWindows && !Platform.isLinux) ||
        kDebugMode ||
        _desktopCheckInFlight) {
      return null;
    }

    _desktopCheckInFlight = true;
    try {
      if (!await _enabled()) return null;

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final key = '${_desktopLastCheckKey}_$_desktopPlatform';
      final lastCheck = prefs.getInt(key) ?? 0;
      if (!force && now - lastCheck < _minimumCheckInterval.inMilliseconds) {
        return null;
      }

      final update = await _checkLatest(platform: _desktopPlatform);
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);

      if (update == null) return null;

      final installedVersion = await installedDesktopVersion();
      if (!_isNewerVersion(update.version, installedVersion)) return null;
      return update;
    } finally {
      _desktopCheckInFlight = false;
    }
  }

  static Future<AppUpdateInfo?> _checkLatest({
    String platform = 'android',
  }) async {
    final client = http.Client();

    try {
      final response = await client
          .get(_endpoint('latest', platform: platform), headers: _headers())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 404) {
        return null;
      }

      if (response.statusCode != 200) {
        throw HttpException(
          'Update metadata request failed '
          '(${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException('Invalid updater metadata.');
      }

      final data = Map<String, dynamic>.from(decoded);
      final tag = data['tag']?.toString() ?? '';

      final tagMatch = RegExp(r'^v?(\d+\.\d+\.\d+)$').firstMatch(tag);

      if (tagMatch == null) {
        throw const FormatException('Invalid release tag.');
      }

      final version = data['version']?.toString() ?? tagMatch.group(1)!;

      if (version != tagMatch.group(1)) {
        throw const FormatException('Release version and tag do not match.');
      }

      final digest = data['sha256']?.toString().toLowerCase() ?? '';

      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
        throw const FormatException('Invalid release SHA-256.');
      }

      final sizeValue = data['sizeBytes'];

      final size = sizeValue is num
          ? sizeValue.toInt()
          : int.tryParse('$sizeValue');

      final maximumSize = platform == 'android'
          ? _maximumApkBytes
          : _maximumDesktopAssetBytes;

      if (size == null || size < 1 || size > maximumSize) {
        throw const FormatException('Invalid release asset size.');
      }

      final assetName = data['assetName']?.toString() ?? '';
      final expectedAssetName = switch (platform) {
        'android' => 'Numination.apk',
        'windows' => 'Numination-Setup.exe',
        'linux' => 'Numination-x86_64.AppImage',
        _ => '',
      };

      if (assetName != expectedAssetName) {
        throw const FormatException('Invalid release asset name.');
      }

      return AppUpdateInfo(
        version: version,
        tag: tag,
        sha256: digest,
        sizeBytes: size,
        assetName: assetName,
      );
    } finally {
      client.close();
    }
  }

  static bool _isNewerVersion(String remote, String local) {
    final a = _parseVersion(remote);
    final b = _parseVersion(local);

    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }

    return false;
  }

  static List<int> _parseVersion(String version) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version);

    if (match == null) {
      return const [0, 0, 0];
    }

    return [
      int.tryParse(match.group(1)!) ?? 0,
      int.tryParse(match.group(2)!) ?? 0,
      int.tryParse(match.group(3)!) ?? 0,
    ];
  }

  static Future<File> _downloadAndVerify(
    AppUpdateInfo update, {
    String platform = 'android',
    ValueChanged<double>? onProgress,
  }) async {
    final client = http.Client();

    try {
      final maximumDownloadBytes = platform == 'android'
          ? _maximumApkBytes
          : _maximumDesktopAssetBytes;

      if (update.sizeBytes < 1 ||
          update.sizeBytes > maximumDownloadBytes) {
        throw const FormatException(
          'Release asset exceeds allowed size.',
        );
      }

      final supportDir = await getApplicationSupportDirectory();
      final updateDir = Directory('${supportDir.path}/updates');
      await updateDir.create(recursive: true);

      final safeTag = update.tag.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );

      final extension = switch (platform) {
        'windows' => 'exe',
        'linux' => 'AppImage',
        _ => 'apk',
      };

      final targetFile = File(
        '${updateDir.path}/Numination-$safeTag.$extension',
      );
      final partFile = File('${targetFile.path}.part');

      if (await partFile.exists()) {
        await partFile.delete();
      }

      final request = http.Request(
        'GET',
        _endpoint(
          'download',
          platform: platform,
          query: {'tag': update.tag},
        ),
      );

      request.headers.addAll(_headers(binary: true));

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        var detail = '';

        try {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            detail = (
              decoded['error'] ??
              decoded['message'] ??
              decoded['details'] ??
              ''
            ).toString();
          }
        } catch (_) {
          detail = body.trim().replaceAll(RegExp(r'\s+'), ' ');
        }

        if (detail.length > 240) {
          detail = detail.substring(0, 240);
        }

        throw HttpException(
          'Supabase updater download failed '
          '(${response.statusCode})'
          '${detail.isEmpty ? '' : ': $detail'}',
        );
      }

      final contentType =
          response.headers['content-type']?.toLowerCase() ?? '';

      if (contentType.contains('application/json') ||
          contentType.contains('text/html')) {
        await response.stream.drain<void>();
        throw const FormatException(
          'Supabase returned a response instead of the release binary.',
        );
      }

      final contentLength = int.tryParse(
        response.headers['content-length'] ?? '',
      );

      if (contentLength != null &&
          contentLength != update.sizeBytes) {
        await response.stream.drain<void>();
        throw const FormatException(
          'Supabase download size does not match release metadata.',
        );
      }

      final digestSink = AccumulatorSink<Digest>();
      final hashInput = sha256.startChunkedConversion(digestSink);
      final output = partFile.openWrite(mode: FileMode.write);

      var totalBytes = 0;

      try {
        onProgress?.call(0);

        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          totalBytes += chunk.length;

          if (totalBytes > maximumDownloadBytes ||
              totalBytes > update.sizeBytes) {
            throw const FormatException(
              'Downloaded asset exceeds expected size.',
            );
          }

          output.add(chunk);
          hashInput.add(chunk);

          onProgress?.call(
            (totalBytes / update.sizeBytes)
                .clamp(0.0, 1.0)
                .toDouble(),
          );
        }
      } finally {
        hashInput.close();
        await output.flush();
        await output.close();
      }

      if (totalBytes != update.sizeBytes) {
        throw const FormatException(
          'Download incomplete. Retry the download.',
        );
      }

      final actualDigest =
          digestSink.events.single.toString().toLowerCase();

      if (actualDigest != update.sha256) {
        await partFile.delete();
        throw const FormatException(
          'Downloaded asset SHA-256 verification failed.',
        );
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      return await partFile.rename(targetFile.path);
    } finally {
      client.close();
    }
  }

  /// Descarga, verifica e inicia el instalador de Windows.
  static Future<void> installWindowsUpdate(
    AppUpdateInfo update, {
    required ValueChanged<double> onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows installer is only available on Windows.');
    }

    final installer = await _downloadAndVerify(
      update,
      platform: 'windows',
      onProgress: onProgress,
    );

    // Inno Setup cierra Numination y reemplaza los archivos instalados.
    await Process.start(installer.path, const [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ], mode: ProcessStartMode.detached);

    // El instalador no puede reemplazar el ejecutable mientras está abierto.
    exit(0);
  }

  static Future<void> installDesktopUpdate(
    AppUpdateInfo update, {
    required ValueChanged<double> onProgress,
  }) async {
    if (Platform.isWindows) {
      final installer = await _downloadAndVerify(
        update,
        platform: 'windows',
        onProgress: onProgress,
      );
      await Process.start(installer.path, const [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
      exit(0);
    }

    if (Platform.isLinux) {
      final appImagePath = Platform.environment['APPIMAGE']?.trim() ?? '';
      if (appImagePath.isEmpty) {
        throw StateError(
          'Abre Numination desde su archivo .AppImage para actualizarlo desde la aplicación.',
        );
      }

      final target = File(appImagePath).absolute;
      if (!await target.exists()) {
        throw StateError(
          'No se encontró el AppImage que está ejecutando Numination.',
        );
      }

      final writable = await Process.run('/usr/bin/test', [
        '-w',
        target.parent.path,
      ]);
      if (writable.exitCode != 0) {
        throw StateError(
          'No tienes permiso para reemplazar el AppImage. Muévelo a una carpeta de tu usuario e inténtalo otra vez.',
        );
      }

      final replacement = await _downloadAndVerify(
        update,
        platform: 'linux',
        onProgress: onProgress,
      );
      final supportDir = await getApplicationSupportDirectory();
      final scriptFile = File(
        '${supportDir.path}/numination-appimage-update.sh',
      );
      final script = <String>[
        r'#!/bin/sh',
        r'set -eu',
        'TARGET=${_shellQuote(target.path)}',
        'SOURCE=${_shellQuote(replacement.path)}',
        r'APP_PID="$PPID"',
        r'while kill -0 "$APP_PID" 2>/dev/null; do',
        r'  sleep 1',
        r'done',
        r'TEMP="${TARGET}.numination-update.$$"',
        r'cp -- "$SOURCE" "$TEMP"',
        r'chmod 755 "$TEMP"',
        r'mv -f -- "$TEMP" "$TARGET"',
        r'rm -f -- "$SOURCE"',
        r'nohup "$TARGET" >/dev/null 2>&1 &',
        r'rm -f -- "$0"',
      ].join('\n');

      await scriptFile.writeAsString(script, flush: true);
      await Process.run('chmod', ['700', scriptFile.path]);
      await Process.start('/bin/sh', [
        scriptFile.path,
      ], mode: ProcessStartMode.detached);
      exit(0);
    }

    throw UnsupportedError(
      'Las actualizaciones de escritorio no están disponibles en esta plataforma.',
    );
  }

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  /// Reintenta una instalación pendiente al regresar de Ajustes.
  static Future<void> resumeAfterInstallPermission() async {
    if (!Platform.isAndroid) return;

    try {
      await _resumePendingInstall();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[NuminationUpdater] Resume install failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<bool> _resumePendingInstall() async {
    final prefs = await SharedPreferences.getInstance();

    final path = prefs.getString(_pendingApkPathKey);

    if (path == null || path.isEmpty) {
      return false;
    }

    final apk = File(path);

    if (!await apk.exists()) {
      await prefs.remove(_pendingApkPathKey);
      return false;
    }

    if (!await _canInstallPackages()) {
      return true;
    }

    await _channel.invokeMethod<void>('installApk', <String, dynamic>{
      'path': apk.path,
    });

    await prefs.remove(_pendingApkPathKey);

    return true;
  }
}
