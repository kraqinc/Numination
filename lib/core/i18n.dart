import 'dart:ui';

    /// Sistema de idiomas propio, liviano (sin ARB/flutter_localizations).
/// Detecta el idioma del sistema operativo del usuario automáticamente
/// (sin preguntarle nada) y elige el diccionario más cercano. Si el
/// idioma del dispositivo no está soportado todavía, cae a español.
///
/// Para agregar un idioma nuevo: agregar su código a [_dictionaries] con
/// las mismas claves que el resto. Para agregar un texto nuevo: agregar
/// la clave a TODOS los diccionarios (o al menos a 'es' como fallback).
class AppLocale {
  static late String _languageCode;
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    final deviceLocale = PlatformDispatcher.instance.locale;
    final code = deviceLocale.languageCode.toLowerCase();
    _languageCode = _dictionaries.containsKey(code) ? code : 'es';
    _initialized = true;
  }

  static String get languageCode {
    if (!_initialized) init();
    return _languageCode;
  }

  /// Traduce [key]. Si falta en el idioma activo, cae a español; si
  /// tampoco existe ahí, devuelve la clave tal cual (nunca rompe la UI).
  static String t(String key) {
    if (!_initialized) init();
    return _dictionaries[_languageCode]?[key] ??
        _dictionaries['es']?[key] ??
        key;
  }

  static const Map<String, Map<String, String>> _dictionaries = {
    'es': {
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
    },
    'en': {
      'ask_something': 'Ask something...',
      'search_chats': 'Search chats',
      'search_hint': 'Type what you\'re looking for',
      'no_results': 'No results',
      'what_are_we_working_on': 'What are we working on today?',
      'new_chat': 'New chat',
      'sessions': 'Sessions',
      'projects': 'Projects',
      'artifacts': 'Artifacts',
      'connectors': 'Connectors',
      'settings': 'Settings',
      'profile': 'Profile',
      'memory': 'Memory',
      'notifications': 'Notifications',
      'privacy': 'Privacy',
      'coder_subscription': 'Coder subscription',
      'change_theme': 'Change theme',
      'log_out': 'Log out',
      'no_projects_title': 'You have no projects',
      'no_projects_subtitle': 'Create one and start chatting',
      'no_files_title': 'No files yet',
      'incognito_chat': 'Incognito chat',
      'incognito_notice': 'This chat is not saved and won\'t appear in your history.',
      'no_wifi': 'No WiFi connection. Connect and try again.',
      'save': 'Save',
      'cancel': 'Cancel',
      'create': 'Create',
      'name': 'Name',
      'pronouns': 'Pronouns',
    },
    'el': {
      'ask_something': 'Ρώτησε κάτι...',
      'search_chats': 'Αναζήτηση συνομιλιών',
      'search_hint': 'Γράψε τι ψάχνεις',
      'no_results': 'Κανένα αποτέλεσμα',
      'what_are_we_working_on': 'Τι δουλεύουμε σήμερα;',
      'new_chat': 'Νέα συνομιλία',
      'sessions': 'Συνεδρίες',
      'projects': 'Έργα',
      'artifacts': 'Αρχεία',
      'connectors': 'Συνδέσεις',
      'settings': 'Ρυθμίσεις',
      'profile': 'Προφίλ',
      'memory': 'Μνήμη',
      'notifications': 'Ειδοποιήσεις',
      'privacy': 'Απόρρητο',
      'coder_subscription': 'Συνδρομή Coder',
      'change_theme': 'Αλλαγή θέματος',
      'log_out': 'Αποσύνδεση',
      'no_projects_title': 'Δεν έχεις έργα',
      'no_projects_subtitle': 'Δημιούργησε ένα και ξεκίνα να συνομιλείς',
      'no_files_title': 'Δεν υπάρχουν αρχεία ακόμα',
      'incognito_chat': 'Ανώνυμη συνομιλία',
      'incognito_notice': 'Αυτή η συνομιλία δεν αποθηκεύεται ούτε εμφανίζεται στο ιστορικό σου.',
      'no_wifi': 'Δεν υπάρχει σύνδεση WiFi. Συνδέσου και δοκίμασε ξανά.',
      'save': 'Αποθήκευση',
      'cancel': 'Ακύρωση',
      'create': 'Δημιουργία',
      'name': 'Όνομα',
      'pronouns': 'Αντωνυμίες',
    },
    'pt': {
      'ask_something': 'Pergunte algo...',
      'search_chats': 'Buscar conversas',
      'search_hint': 'Digite o que procura',
      'no_results': 'Sem resultados',
      'what_are_we_working_on': 'No que vamos trabalhar hoje?',
      'new_chat': 'Nova conversa',
      'sessions': 'Sessões',
      'projects': 'Projetos',
      'artifacts': 'Artefatos',
      'connectors': 'Conectores',
      'settings': 'Configurações',
      'profile': 'Perfil',
      'memory': 'Memórias',
      'notifications': 'Notificações',
      'privacy': 'Privacidade',
      'coder_subscription': 'Assinatura Coder',
      'change_theme': 'Mudar tema',
      'log_out': 'Sair',
      'no_projects_title': 'Você não tem projetos',
      'no_projects_subtitle': 'Crie um e comece a conversar',
      'no_files_title': 'Ainda não há arquivos',
      'incognito_chat': 'Conversa incógnita',
      'incognito_notice': 'Esta conversa não é salva nem aparece no seu histórico.',
      'no_wifi': 'Sem conexão WiFi. Conecte-se e tente novamente.',
      'save': 'Salvar',
      'cancel': 'Cancelar',
      'create': 'Criar',
      'name': 'Nome',
      'pronouns': 'Pronomes',
    },
    'fr': {
      'ask_something': 'Demandez quelque chose...',
      'search_chats': 'Rechercher des discussions',
      'search_hint': 'Écrivez ce que vous cherchez',
      'no_results': 'Aucun résultat',
      'what_are_we_working_on': 'Sur quoi travaillons-nous aujourd\'hui ?',
      'new_chat': 'Nouvelle discussion',
      'sessions': 'Sessions',
      'projects': 'Projets',
      'artifacts': 'Artefacts',
      'connectors': 'Connecteurs',
      'settings': 'Paramètres',
      'profile': 'Profil',
      'memory': 'Mémoire',
      'notifications': 'Notifications',
      'privacy': 'Confidentialité',
      'coder_subscription': 'Abonnement Coder',
      'change_theme': 'Changer de thème',
      'log_out': 'Se déconnecter',
      'no_projects_title': 'Vous n\'avez aucun projet',
      'no_projects_subtitle': 'Créez-en un et commencez à discuter',
      'no_files_title': 'Aucun fichier pour le moment',
      'incognito_chat': 'Discussion incognito',
      'incognito_notice': 'Cette discussion n\'est pas enregistrée et n\'apparaîtra pas dans votre historique.',
      'no_wifi': 'Pas de connexion WiFi. Connectez-vous et réessayez.',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'create': 'Créer',
      'name': 'Nom',
      'pronouns': 'Pronoms',
    },
  };
}