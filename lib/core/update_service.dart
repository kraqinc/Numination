import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateInfo {
  final String version;
  final String tag;
  final String downloadUrl;
  final String sha256;

  const AppUpdateInfo({
    required this.version,
    required this.tag,
    required this.downloadUrl,
    required this.sha256,
  });
}

class UpdateService {
  static const _channel = MethodChannel('numination.updater');

  static const _repoApi =
      'https://api.github.com/repos/kraqinc/Numination/releases/latest';

  static const _lastCheckKey = 'last_update_check';
  static const _pendingApkPathKey = 'pending_apk_path';

  static bool _checkedThisLaunch = false;

  static Future<bool> _enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_update_apk') ?? true;
  }

  static Future<void> checkAndInstallIfEnabled() async {
    if (!Platform.isAndroid) return;
    if (kDebugMode) return;
    if (_checkedThisLaunch) return;

    final enabled = await _enabled();

    if (!enabled) return;

    _checkedThisLaunch = true;

    await resumeAfterInstallPermission();

    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Evita consultar GitHub demasiadas veces.
    if (now - lastCheck < const Duration(minutes: 15).inMilliseconds) {
      return;
    }

    await prefs.setInt(_lastCheckKey, now);

    try {
      final update = await _checkLatest();

      if (update == null) return;

      final packageInfo = await PackageInfo.fromPlatform();

      if (!_isNewerVersion(update.version, packageInfo.version)) {
        return;
      }

      final apk = await _downloadAndVerify(update);

      final canInstall =
          await _channel.invokeMethod<bool>('canInstallPackages') ?? false;

      if (!canInstall) {
        await prefs.setString(_pendingApkPathKey, apk.path);
        await _channel.invokeMethod('openUnknownSourcesSettings');
        return;
      }

      await _channel.invokeMethod('installApk', <String, dynamic>{
        'path': apk.path,
      });

      await prefs.remove(_pendingApkPathKey);
    } catch (_) {
      // Una actualización fallida no debe bloquear la aplicación.
    }
  }

  static Future<AppUpdateInfo?> _checkLatest() async {
    final response = await http
        .get(
          Uri.parse(_repoApi),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2026-03-10',
            'User-Agent': 'Numination-Android',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body);

    if (json is! Map) {
      return null;
    }

    final tag = json['tag_name']?.toString() ?? '';

    if (tag.isEmpty) {
      return null;
    }

    final assets = json['assets'];

    if (assets is! List) {
      return null;
    }

    Map<String, dynamic>? apkAsset;

    for (final raw in assets) {
      if (raw is! Map) continue;

      final name = raw['name']?.toString();

      if (name == 'Numination.apk') {
        apkAsset = Map<String, dynamic>.from(raw);
        break;
      }
    }

    if (apkAsset == null) {
      return null;
    }

    final downloadUrl = apkAsset['browser_download_url']?.toString() ?? '';

    final digest = apkAsset['digest']?.toString() ?? '';

    if (downloadUrl.isEmpty || digest.isEmpty) {
      return null;
    }

    if (!digest.startsWith('sha256:')) {
      return null;
    }

    final version = tag.startsWith('v') ? tag.substring(1) : tag;

    return AppUpdateInfo(
      version: version,
      tag: tag,
      downloadUrl: downloadUrl,
      sha256: digest.substring('sha256:'.length).toLowerCase(),
    );
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
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(version);

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

    try {
      final request = http.Request('GET', Uri.parse(update.downloadUrl));

      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw Exception('APK download failed');
      }

      final tempDir = await getTemporaryDirectory();

      final apk = File('${tempDir.path}/Numination.apk');

      if (await apk.exists()) {
        await apk.delete();
      }

      final output = apk.openWrite();

      final digestSink = AccumulatorSink<Digest>();
      final hashInput = sha256.startChunkedConversion(digestSink);

      var totalBytes = 0;

      try {
        await for (final chunk in response.stream) {
          totalBytes += chunk.length;

          // Protección contra archivos absurdamente grandes.
          if (totalBytes > 250 * 1024 * 1024) {
            throw Exception('APK demasiado grande');
          }

          output.add(chunk);
          hashInput.add(chunk);
        }
      } finally {
        hashInput.close();

        await output.flush();
        await output.close();
      }

      final actualDigest = digestSink.events.single.toString().toLowerCase();

      if (actualDigest != update.sha256) {
        await apk.delete();

        throw Exception('SHA-256 mismatch');
      }

      return apk;
    } finally {
      client.close();
    }
  }

  static Future<void> resumeAfterInstallPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pendingApkPathKey);
    if (path == null || path.isEmpty) return;

    final apk = File(path);
    if (!await apk.exists()) {
      await prefs.remove(_pendingApkPathKey);
      return;
    }

    try {
      final canInstall =
          await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
      if (!canInstall) return;

      await _channel.invokeMethod('installApk', <String, dynamic>{
        'path': apk.path,
      });
      await prefs.remove(_pendingApkPathKey);
    } catch (_) {}
  }

}
