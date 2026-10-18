import 'dart:async';

import 'api.dart';

class ModuleWarmup {
  ModuleWarmup._();

  static const List<String> _paths = <String>[
    '/auth/me',
    '/credits',
    '/modes',
    '/projects',
    '/chats',
    '/memory',
    '/notifications',
    '/integrations',
    '/artifacts',
  ];

  static Future<void> start() async {
    await Future.wait<void>(_paths.map(_warm));
  }

  static Future<void> _warm(String path) async {
    try {
      ApiClient.decode(await ApiClient.get(path));
    } catch (_) {
      // Un módulo desconectado o sin permisos no bloquea los demás.
    }
  }
}
