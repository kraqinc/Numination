import 'package:flutter/widgets.dart';

import '../l10n/gen/app_localizations.dart';

class AppLocale {
  static BuildContext? _context;

  static void bind(BuildContext context) {
    _context = context;
  }

  static String t(String key) {
    final context = _context;

    if (context == null) {
      return _fallback(key);
    }

    final l10n = AppLocalizations.of(context);

    if (l10n == null) {
      return _fallback(key);
    }

    switch (key) {
      case 'ask_something':
        return l10n.askSomething;
      case 'search_chats':
        return l10n.searchChats;
      case 'search_hint':
        return l10n.searchHint;
      case 'no_results':
        return l10n.noResults;
      case 'what_are_we_working_on':
        return l10n.whatAreWeWorkingOn;
      case 'new_chat':
        return l10n.newChat;
      case 'sessions':
        return l10n.sessions;
      case 'projects':
        return l10n.projects;
      case 'artifacts':
        return l10n.artifacts;
      case 'connectors':
        return l10n.connectors;
      case 'settings':
        return l10n.settings;
      case 'profile':
        return l10n.profile;
      case 'memory':
        return l10n.memory;
      case 'notifications':
        return l10n.notifications;
      case 'privacy':
        return l10n.privacy;
      case 'coder_subscription':
        return l10n.coderSubscription;
      case 'change_theme':
        return l10n.changeTheme;
      case 'log_out':
        return l10n.logOut;
      case 'no_projects_title':
        return l10n.noProjectsTitle;
      case 'no_projects_subtitle':
        return l10n.noProjectsSubtitle;
      case 'no_files_title':
        return l10n.noFilesTitle;
      case 'incognito_chat':
        return l10n.incognitoChat;
      case 'incognito_notice':
        return l10n.incognitoNotice;
      case 'no_wifi':
        return l10n.noWifi;
      case 'save':
        return l10n.save;
      case 'cancel':
        return l10n.cancel;
      case 'create':
        return l10n.create;
      case 'name':
        return l10n.name;
      case 'pronouns':
        return l10n.pronouns;
      default:
        return key;
    }
  }

  static String _fallback(String key) {
    const values = <String, String>{
      'ask_something': 'Pregunta algo...',
      'search_chats': 'Buscar chats',
      'search_hint': 'Escribe lo que buscas',
      'no_results': 'Sin resultados',
      'what_are_we_working_on': '¿En qué trabajamos hoy?',
      'new_chat': 'Nuevo chat',
      'sessions': 'Sesiones',
      'projects': 'Proyectos',
      'artifacts': 'Artefactos',
      'connectors': 'Conectores',
      'settings': 'Ajustes',
      'profile': 'Perfil',
      'memory': 'Memorias',
      'notifications': 'Notificaciones',
      'privacy': 'Privacidad',
      'coder_subscription': 'Suscripción Coder',
      'change_theme': 'Cambiar tema',
      'log_out': 'Cerrar sesión',
      'no_projects_title': 'No tienes proyectos',
      'no_projects_subtitle': 'Crea uno y empieza a chatear',
      'no_files_title': 'No tienes archivos todavía',
      'incognito_chat': 'Chat incógnito',
      'incognito_notice': 'Este chat no se guarda ni aparece en tu historial.',
      'no_wifi': 'No tienes conexión a WiFi. Conéctate e intenta de nuevo.',
      'save': 'Guardar',
      'cancel': 'Cancelar',
      'create': 'Crear',
      'name': 'Nombre',
      'pronouns': 'Pronombres',
    };

    return values[key] ?? key;
  }
}
