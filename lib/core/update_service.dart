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
  });

  final String version;
  final String tag;
  final String sha256;
  final int sizeBytes;
}

class UpdateService {
  static const MethodChannel _channel = MethodChannel('numination.updater');

  static const String _lastCheckKey = 'last_update_check';
  static const String _pendingApkPathKey = 'pending_apk_path';

  static const Duration _minimumCheckInterval = Duration(minutes: 30);

  static const int _maximumApkBytes = 250 * 1024 * 1024;

  static bool _checkInFlight = false;
  static bool _permissionPromptInFlight = false;
  static bool _permissionPromptedThisLaunch = false;
  static Timer? _automaticCheckTimer;

  /// Comprueba nuevas Releases cada 30 minutos mientras HomeScreen siga activo.
  static void startAutomaticChecks() {
    _automaticCheckTimer ??= Timer.periodic(
      const Duration(minutes: 30),
      (_) => unawaited(checkAndInstallIfEnabled()),
    );
  }

  static void stopAutomaticChecks() {
    _automaticCheckTimer?.cancel();
    _automaticCheckTimer = null;
  }

  static Uri _endpoint(String action, {Map<String, String> query = const {}}) {
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

    return Uri.parse(
      '$base/functions/v1/numination-updater',
    ).replace(queryParameters: {'action': action, ...query});
  }

  static Map<String, String> _headers({bool binary = false}) {
    final headers = <String, String>{
      'Accept': binary ? 'application/octet-stream' : 'application/json',
      'User-Agent': 'Numination-Android-Updater',
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

      return await _channel.invokeMethod<bool>('openUnknownSourcesSettings') ??
          false;
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

  /// Consulta la última Release estable y prepara la instalación
  /// únicamente si existe una versión más reciente.
  static Future<void> checkAndInstallIfEnabled() async {
    if (!Platform.isAndroid || kDebugMode || _checkInFlight) {
      return;
    }

    if (!await _enabled()) return;

    _checkInFlight = true;

    try {
      // Recupera primero una descarga pendiente de una ejecución
      // anterior, si existe.
      if (await _resumePendingInstall()) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now().millisecondsSinceEpoch;
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;

      if (now - lastCheck < _minimumCheckInterval.inMilliseconds) {
        return;
      }

      final update = await _checkLatest();

      // Registrar el momento solo después de una respuesta válida.
      await prefs.setInt(_lastCheckKey, now);

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
      if (kDebugMode) {
        debugPrint('[NuminationUpdater] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _checkInFlight = false;
    }
  }

  static Future<AppUpdateInfo?> _checkLatest() async {
    final client = http.Client();

    try {
      final response = await client
          .get(_endpoint('latest'), headers: _headers())
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

      if (size == null || size < 1 || size > _maximumApkBytes) {
        throw const FormatException('Invalid release APK size.');
      }

      return AppUpdateInfo(
        version: version,
        tag: tag,
        sha256: digest,
        sizeBytes: size,
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

  static Future<File> _downloadAndVerify(AppUpdateInfo update) async {
    final client = http.Client();
    File? partialFile;

    try {
      final request = http.Request(
        'GET',
        _endpoint('download', query: {'tag': update.tag}),
      )..headers.addAll(_headers(binary: true));

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        await response.stream.drain<void>();

        throw HttpException('APK download failed (${response.statusCode}).');
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      if (contentType.contains('application/json') ||
          contentType.contains('text/html')) {
        await response.stream.drain<void>();

        throw const FormatException(
          'The server returned metadata instead of an APK.',
        );
      }

      final supportDir = await getApplicationSupportDirectory();

      final updateDir = Directory('${supportDir.path}/updates');

      await updateDir.create(recursive: true);

      final safeTag = update.tag.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final targetFile = File('${updateDir.path}/Numination-$safeTag.apk');

      final partFile = File('${targetFile.path}.part');

      partialFile = partFile;

      if (await partFile.exists()) {
        await partFile.delete();
      }

      final output = partFile.openWrite();

      final digestSink = AccumulatorSink<Digest>();

      final hashInput = sha256.startChunkedConversion(digestSink);

      var totalBytes = 0;

      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          totalBytes += chunk.length;

          if (totalBytes > _maximumApkBytes || totalBytes > update.sizeBytes) {
            throw const FormatException(
              'Downloaded APK exceeds expected size.',
            );
          }

          output.add(chunk);
          hashInput.add(chunk);
        }
      } finally {
        hashInput.close();
        await output.flush();
        await output.close();
      }

      if (totalBytes != update.sizeBytes) {
        throw const FormatException(
          'Downloaded APK size does not match release metadata.',
        );
      }

      final actualDigest = digestSink.events.single.toString().toLowerCase();

      if (actualDigest != update.sha256) {
        throw const FormatException(
          'Downloaded APK SHA-256 verification failed.',
        );
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      return await partFile.rename(targetFile.path);
    } catch (_) {
      if (partialFile != null && await partialFile.exists()) {
        try {
          await partialFile.delete();
        } catch (_) {}
      }

      rethrow;
    } finally {
      client.close();
    }
  }

  /// Reintenta una instalación pendiente al regresar de Ajustes.
  static Future<void> resumeAfterInstallPermission() async {
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
