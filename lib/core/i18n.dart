import 'package:flutter/widgets.dart';

import '../l10n/gen/app_localizations.dart';

class AppLocale {
  static BuildContext? _context;

  static const Map<String, Map<String, String>> _extraTranslations = {
  "en": {
    "project_name_required": "Enter a name for your project.",
    "folder_dialog_title": "Choose the project folder",
    "folder_open_error": "Could not open the selected folder:",
    "local_folder_required": "Choose a local folder first.",
    "local_import_partial": "The project was created, but some files could not be imported. Check your connection and import them again. Details:",
    "import_summary": "Imported {imported} files. Skipped {skipped} binary, sensitive, or oversized files.",
    "back": "Back",
    "previous_step": "Previous step",
    "coder_new_project": "Coder · New project",
    "workspace_eyebrow": "CODER WORKSPACE",
    "workspace_title": "Your space to build",
    "workspace_subtitle": "Project, files, and changes in one place.",
    "step_name": "Name",
    "step_type": "Type",
    "project_name_title": "Project name",
    "project_name_description": "Choose a name, then select where Coder should work.",
    "project_name_label": "Name",
    "project_name_hint": "My project",
    "project_type_title": "Project type",
    "project_type_description": "Choose where you want Coder to work.",
    "cloud_project": "In the cloud",
    "cloud_project_description": "Start a cloud project from scratch and open its Coder chat.",
    "local_project": "Local folder",
    "local_project_description": "Choose a folder that Numination can read and update.",
    "choose_local_folder": "Choose local folder",
    "change_folder": "Change folder",
    "local_folder_warning": "Coder can create, edit, and delete files inside this folder. Back up important files before continuing.",
    "local_sync_description": "Supported text files are copied into the workspace. Files Coder creates, updates, or deletes are synchronized back to this folder.",
    "create_project": "Create project",
    "next": "Next",
    "creating_project": "Creating project…",
    "importing_files": "Importing {count} files…",
    "wizard_footer": "Coder works with the files in its project workspace. You can manage them from the file panel.",
    "chat_one": "{count} chat",
    "chat_many": "{count} chats",
    "open_in_coder": "Open in Coder",
    "project_no_chats": "This project does not have any chats yet.",
    "memory_subtitle": "What Numination remembers from your chats",
    "email_preferences": "Numination emails",
    "email_preferences_subtitle": "Security alerts, product updates, and newsletter",
    "terms_of_use": "Terms of use",
    "terms_subtitle": "Conditions for using Numination",
    "privacy_web_policy": "Website privacy policy",
    "privacy_web_subtitle": "How we handle your data",
    "automatic_updates": "Automatic updates",
    "automatic_updates_subtitle": "Automatically check for and download new Numination versions",
    "credits": "Credits",
    "credits_subtitle": "Check your balance and get more credits",
    "subscriptions": "Subscriptions",
    "subscriptions_subtitle": "Plans, weekly credits, and benefits",
    "refresh_plans": "Refresh plans",
    "choose_plan": "Choose your plan",
    "plans_intro": "More credits for your conversations, projects, and AI tools.",
    "plans_load_failed": "We could not load the plans. Check your connection and try again.",
    "back_to_chats": "Back to your chats",
    "menu": "Menu",
    "undo_changes": "Undo changes",
    "hide_files": "Hide files",
    "show_files": "Show files",
    "download_project_zip": "Download project ZIP",
    "project_files": "PROJECT FILES",
    "project_no_files": "This project does not have any files yet.",
    "coder_prompt": "Describe what you want to build…",
    "stop_dictation": "Stop dictation",
    "dictate_message": "Dictate message",
    "stop": "Stop",
    "send": "Send",
    "local_sync_success": "Changes synced to the local folder: {written} file(s) updated, {deleted} deleted.",
    "local_sync_error": "Coder updated the workspace, but the local folder could not be synchronized:",
    "zip_saved": "ZIP saved:"
  },
  "es": {
    "project_name_required": "Escribe un nombre para el proyecto.",
    "folder_dialog_title": "Selecciona la carpeta del proyecto",
    "folder_open_error": "No se pudo abrir la carpeta seleccionada:",
    "local_folder_required": "Selecciona primero una carpeta local.",
    "local_import_partial": "El proyecto se creó, pero la importación quedó incompleta. Revisa tu conexión e importa de nuevo los archivos necesarios. Detalle:",
    "import_summary": "Se importaron {imported} archivos. Se omitieron {skipped} archivos binarios, sensibles o demasiado grandes.",
    "back": "Volver",
    "previous_step": "Paso anterior",
    "coder_new_project": "Coder · Nuevo proyecto",
    "workspace_eyebrow": "ESPACIO DE TRABAJO CODER",
    "workspace_title": "Tu espacio para construir",
    "workspace_subtitle": "Proyecto, archivos y cambios en un solo lugar.",
    "step_name": "Nombre",
    "step_type": "Tipo",
    "project_name_title": "Nombre del proyecto",
    "project_name_description": "Elige un nombre y después selecciona dónde trabajará Coder.",
    "project_name_label": "Nombre",
    "project_name_hint": "Mi proyecto",
    "project_type_title": "Tipo de proyecto",
    "project_type_description": "Selecciona dónde quieres que trabaje Coder.",
    "cloud_project": "En la nube",
    "cloud_project_description": "Crea un proyecto en la nube desde cero y abre su chat de Coder.",
    "local_project": "Carpeta local",
    "local_project_description": "Selecciona una carpeta que Numination pueda leer y actualizar.",
    "choose_local_folder": "Elegir carpeta local",
    "change_folder": "Cambiar carpeta",
    "local_folder_warning": "Coder puede crear, editar y eliminar archivos dentro de esta carpeta. Haz una copia de seguridad de lo importante antes de continuar.",
    "local_sync_description": "Los archivos de texto compatibles se copian al espacio de trabajo. Los archivos que Coder cree, actualice o elimine se sincronizarán con esta carpeta.",
    "create_project": "Crear proyecto",
    "next": "Siguiente",
    "creating_project": "Creando proyecto…",
    "importing_files": "Importando {count} archivos…",
    "wizard_footer": "Coder trabaja con los archivos de su espacio de proyecto. Puedes administrarlos desde el panel de archivos.",
    "chat_one": "{count} chat",
    "chat_many": "{count} chats",
    "open_in_coder": "Abrir en Coder",
    "project_no_chats": "Este proyecto todavía no tiene chats.",
    "memory_subtitle": "Lo que Numination recuerda de tus chats",
    "email_preferences": "Correos de Numination",
    "email_preferences_subtitle": "Alertas de seguridad, novedades y newsletter",
    "terms_of_use": "Términos de uso",
    "terms_subtitle": "Condiciones para usar Numination",
    "privacy_web_policy": "Política de privacidad web",
    "privacy_web_subtitle": "Cómo tratamos tus datos",
    "automatic_updates": "Actualizaciones automáticas",
    "automatic_updates_subtitle": "Detecta y descarga nuevas versiones de Numination automáticamente",
    "credits": "Créditos",
    "credits_subtitle": "Consulta tu saldo y consigue más créditos",
    "subscriptions": "Suscripciones",
    "subscriptions_subtitle": "Planes, créditos semanales y beneficios",
    "refresh_plans": "Actualizar planes",
    "choose_plan": "Elige tu plan",
    "plans_intro": "Más créditos para tus conversaciones, proyectos y herramientas de IA.",
    "plans_load_failed": "No pudimos cargar los planes. Comprueba tu conexión e inténtalo de nuevo.",
    "back_to_chats": "Volver a tus chats",
    "menu": "Menú",
    "undo_changes": "Deshacer cambios",
    "hide_files": "Ocultar archivos",
    "show_files": "Mostrar archivos",
    "download_project_zip": "Descargar proyecto ZIP",
    "project_files": "ARCHIVOS DEL PROYECTO",
    "project_no_files": "Este proyecto aún no tiene archivos.",
    "coder_prompt": "Describe qué quieres construir…",
    "stop_dictation": "Detener dictado",
    "dictate_message": "Dictar mensaje",
    "stop": "Detener",
    "send": "Enviar",
    "local_sync_success": "Cambios integrados en la carpeta local: {written} archivo(s) actualizado(s), {deleted} eliminado(s).",
    "local_sync_error": "Coder actualizó el espacio de trabajo, pero no se pudo sincronizar la carpeta local:",
    "zip_saved": "ZIP guardado:"
  },
  "fr": {
    "project_name_required": "Saisissez un nom pour votre projet.",
    "folder_dialog_title": "Choisissez le dossier du projet",
    "folder_open_error": "Impossible d’ouvrir le dossier sélectionné :",
    "local_folder_required": "Choisissez d’abord un dossier local.",
    "local_import_partial": "Le projet a été créé, mais certains fichiers n’ont pas été importés. Vérifiez votre connexion et réessayez. Détails :",
    "import_summary": "{imported} fichiers importés. {skipped} fichiers binaires, sensibles ou trop volumineux ignorés.",
    "back": "Retour",
    "previous_step": "Étape précédente",
    "coder_new_project": "Coder · Nouveau projet",
    "workspace_eyebrow": "ESPACE DE TRAVAIL CODER",
    "workspace_title": "Votre espace de création",
    "workspace_subtitle": "Projet, fichiers et modifications au même endroit.",
    "step_name": "Nom",
    "step_type": "Type",
    "project_name_title": "Nom du projet",
    "project_name_description": "Choisissez un nom, puis l’emplacement de travail de Coder.",
    "project_name_label": "Nom",
    "project_name_hint": "Mon projet",
    "project_type_title": "Type de projet",
    "project_type_description": "Choisissez l’emplacement de travail de Coder.",
    "cloud_project": "Dans le cloud",
    "cloud_project_description": "Créez un projet cloud et ouvrez sa discussion Coder.",
    "local_project": "Dossier local",
    "local_project_description": "Choisissez un dossier que Numination peut lire et mettre à jour.",
    "choose_local_folder": "Choisir un dossier local",
    "change_folder": "Changer de dossier",
    "local_folder_warning": "Coder peut créer, modifier et supprimer des fichiers dans ce dossier. Sauvegardez les fichiers importants avant de continuer.",
    "local_sync_description": "Les fichiers texte compatibles sont copiés dans l’espace de travail. Les fichiers créés, modifiés ou supprimés par Coder sont synchronisés dans ce dossier.",
    "create_project": "Créer le projet",
    "next": "Suivant",
    "creating_project": "Création du projet…",
    "importing_files": "Importation de {count} fichiers…",
    "wizard_footer": "Coder travaille avec les fichiers de son espace de projet. Gérez-les depuis le panneau des fichiers.",
    "chat_one": "{count} discussion",
    "chat_many": "{count} discussions",
    "open_in_coder": "Ouvrir dans Coder",
    "project_no_chats": "Ce projet ne contient pas encore de discussions.",
    "memory_subtitle": "Ce que Numination retient de vos discussions",
    "email_preferences": "E-mails de Numination",
    "email_preferences_subtitle": "Alertes de sécurité, actualités et newsletter",
    "terms_of_use": "Conditions d’utilisation",
    "terms_subtitle": "Conditions d’utilisation de Numination",
    "privacy_web_policy": "Politique de confidentialité du site",
    "privacy_web_subtitle": "Comment nous traitons vos données",
    "automatic_updates": "Mises à jour automatiques",
    "automatic_updates_subtitle": "Rechercher et télécharger automatiquement les nouvelles versions",
    "credits": "Crédits",
    "credits_subtitle": "Consultez votre solde et obtenez plus de crédits",
    "subscriptions": "Abonnements",
    "subscriptions_subtitle": "Offres, crédits hebdomadaires et avantages",
    "refresh_plans": "Actualiser les offres",
    "choose_plan": "Choisissez votre offre",
    "plans_intro": "Plus de crédits pour vos conversations, projets et outils d’IA.",
    "plans_load_failed": "Impossible de charger les offres. Vérifiez votre connexion et réessayez.",
    "back_to_chats": "Retour aux discussions",
    "menu": "Menu",
    "undo_changes": "Annuler les modifications",
    "hide_files": "Masquer les fichiers",
    "show_files": "Afficher les fichiers",
    "download_project_zip": "Télécharger le ZIP du projet",
    "project_files": "FICHIERS DU PROJET",
    "project_no_files": "Ce projet ne contient pas encore de fichiers.",
    "coder_prompt": "Décrivez ce que vous souhaitez créer…",
    "stop_dictation": "Arrêter la dictée",
    "dictate_message": "Dicter le message",
    "stop": "Arrêter",
    "send": "Envoyer",
    "local_sync_success": "Modifications synchronisées : {written} fichier(s) mis à jour, {deleted} supprimé(s).",
    "local_sync_error": "Coder a mis à jour l’espace de travail, mais le dossier local n’a pas pu être synchronisé :",
    "zip_saved": "ZIP enregistré :"
  },
  "pt": {
    "project_name_required": "Digite um nome para o projeto.",
    "folder_dialog_title": "Selecione a pasta do projeto",
    "folder_open_error": "Não foi possível abrir a pasta selecionada:",
    "local_folder_required": "Selecione primeiro uma pasta local.",
    "local_import_partial": "O projeto foi criado, mas a importação ficou incompleta. Verifique a conexão e importe os arquivos novamente. Detalhes:",
    "import_summary": "{imported} arquivos importados. {skipped} arquivos binários, confidenciais ou grandes demais foram ignorados.",
    "back": "Voltar",
    "previous_step": "Etapa anterior",
    "coder_new_project": "Coder · Novo projeto",
    "workspace_eyebrow": "ESPAÇO DE TRABALHO CODER",
    "workspace_title": "Seu espaço para construir",
    "workspace_subtitle": "Projeto, arquivos e alterações em um só lugar.",
    "step_name": "Nome",
    "step_type": "Tipo",
    "project_name_title": "Nome do projeto",
    "project_name_description": "Escolha um nome e depois selecione onde o Coder vai trabalhar.",
    "project_name_label": "Nome",
    "project_name_hint": "Meu projeto",
    "project_type_title": "Tipo de projeto",
    "project_type_description": "Selecione onde você quer que o Coder trabalhe.",
    "cloud_project": "Na nuvem",
    "cloud_project_description": "Crie um projeto na nuvem e abra o chat do Coder.",
    "local_project": "Pasta local",
    "local_project_description": "Selecione uma pasta que o Numination possa ler e atualizar.",
    "choose_local_folder": "Escolher pasta local",
    "change_folder": "Alterar pasta",
    "local_folder_warning": "O Coder pode criar, editar e excluir arquivos nesta pasta. Faça backup dos arquivos importantes antes de continuar.",
    "local_sync_description": "Arquivos de texto compatíveis são copiados para o espaço de trabalho. Os arquivos criados, atualizados ou excluídos pelo Coder são sincronizados de volta para esta pasta.",
    "create_project": "Criar projeto",
    "next": "Avançar",
    "creating_project": "Criando projeto…",
    "importing_files": "Importando {count} arquivos…",
    "wizard_footer": "O Coder trabalha com os arquivos do espaço do projeto. Você pode gerenciá-los no painel de arquivos.",
    "chat_one": "{count} conversa",
    "chat_many": "{count} conversas",
    "open_in_coder": "Abrir no Coder",
    "project_no_chats": "Este projeto ainda não tem conversas.",
    "memory_subtitle": "O que o Numination lembra das suas conversas",
    "email_preferences": "E-mails do Numination",
    "email_preferences_subtitle": "Alertas de segurança, novidades e newsletter",
    "terms_of_use": "Termos de uso",
    "terms_subtitle": "Condições para usar o Numination",
    "privacy_web_policy": "Política de privacidade do site",
    "privacy_web_subtitle": "Como tratamos seus dados",
    "automatic_updates": "Atualizações automáticas",
    "automatic_updates_subtitle": "Detectar e baixar novas versões do Numination automaticamente",
    "credits": "Créditos",
    "credits_subtitle": "Consulte seu saldo e obtenha mais créditos",
    "subscriptions": "Assinaturas",
    "subscriptions_subtitle": "Planos, créditos semanais e benefícios",
    "refresh_plans": "Atualizar planos",
    "choose_plan": "Escolha seu plano",
    "plans_intro": "Mais créditos para suas conversas, projetos e ferramentas de IA.",
    "plans_load_failed": "Não foi possível carregar os planos. Verifique sua conexão e tente novamente.",
    "back_to_chats": "Voltar às conversas",
    "menu": "Menu",
    "undo_changes": "Desfazer alterações",
    "hide_files": "Ocultar arquivos",
    "show_files": "Mostrar arquivos",
    "download_project_zip": "Baixar ZIP do projeto",
    "project_files": "ARQUIVOS DO PROJETO",
    "project_no_files": "Este projeto ainda não tem arquivos.",
    "coder_prompt": "Descreva o que você quer construir…",
    "stop_dictation": "Parar ditado",
    "dictate_message": "Ditado de mensagem",
    "stop": "Parar",
    "send": "Enviar",
    "local_sync_success": "Alterações sincronizadas: {written} arquivo(s) atualizado(s), {deleted} excluído(s).",
    "local_sync_error": "O Coder atualizou o espaço de trabalho, mas não foi possível sincronizar a pasta local:",
    "zip_saved": "ZIP salvo:"
  },
  "el": {
    "project_name_required": "Πληκτρολόγησε ένα όνομα για το έργο.",
    "folder_dialog_title": "Επίλεξε τον φάκελο του έργου",
    "folder_open_error": "Δεν ήταν δυνατό το άνοιγμα του επιλεγμένου φακέλου:",
    "local_folder_required": "Επίλεξε πρώτα έναν τοπικό φάκελο.",
    "local_import_partial": "Το έργο δημιουργήθηκε, αλλά η εισαγωγή ορισμένων αρχείων δεν ολοκληρώθηκε. Έλεγξε τη σύνδεσή σου και δοκίμασε ξανά. Λεπτομέρειες:",
    "import_summary": "Εισήχθησαν {imported} αρχεία. Παραλείφθηκαν {skipped} δυαδικά, ευαίσθητα ή υπερβολικά μεγάλα αρχεία.",
    "back": "Πίσω",
    "previous_step": "Προηγούμενο βήμα",
    "coder_new_project": "Coder · Νέο έργο",
    "workspace_eyebrow": "ΧΩΡΟΣ ΕΡΓΑΣΙΑΣ CODER",
    "workspace_title": "Ο χώρος δημιουργίας σου",
    "workspace_subtitle": "Έργο, αρχεία και αλλαγές σε ένα μέρος.",
    "step_name": "Όνομα",
    "step_type": "Τύπος",
    "project_name_title": "Όνομα έργου",
    "project_name_description": "Διάλεξε όνομα και μετά επίλεξε πού θα εργάζεται το Coder.",
    "project_name_label": "Όνομα",
    "project_name_hint": "Το έργο μου",
    "project_type_title": "Τύπος έργου",
    "project_type_description": "Επίλεξε πού θέλεις να εργάζεται το Coder.",
    "cloud_project": "Στο cloud",
    "cloud_project_description": "Δημιούργησε ένα έργο στο cloud και άνοιξε τη συνομιλία Coder.",
    "local_project": "Τοπικός φάκελος",
    "local_project_description": "Επίλεξε έναν φάκελο που το Numination μπορεί να διαβάζει και να ενημερώνει.",
    "choose_local_folder": "Επιλογή τοπικού φακέλου",
    "change_folder": "Αλλαγή φακέλου",
    "local_folder_warning": "Το Coder μπορεί να δημιουργεί, να επεξεργάζεται και να διαγράφει αρχεία σε αυτόν τον φάκελο. Δημιούργησε αντίγραφο ασφαλείας πριν συνεχίσεις.",
    "local_sync_description": "Τα συμβατά αρχεία κειμένου αντιγράφονται στον χώρο εργασίας. Τα αρχεία που δημιουργεί, ενημερώνει ή διαγράφει το Coder συγχρονίζονται ξανά σε αυτόν τον φάκελο.",
    "create_project": "Δημιουργία έργου",
    "next": "Επόμενο",
    "creating_project": "Δημιουργία έργου…",
    "importing_files": "Εισαγωγή {count} αρχείων…",
    "wizard_footer": "Το Coder εργάζεται με τα αρχεία του χώρου έργου. Μπορείς να τα διαχειριστείς από το πάνελ αρχείων.",
    "chat_one": "{count} συνομιλία",
    "chat_many": "{count} συνομιλίες",
    "open_in_coder": "Άνοιγμα στο Coder",
    "project_no_chats": "Αυτό το έργο δεν έχει ακόμη συνομιλίες.",
    "memory_subtitle": "Τι θυμάται το Numination από τις συνομιλίες σου",
    "email_preferences": "E-mail Numination",
    "email_preferences_subtitle": "Ειδοποιήσεις ασφαλείας, νέα και ενημερωτικό δελτίο",
    "terms_of_use": "Όροι χρήσης",
    "terms_subtitle": "Όροι χρήσης του Numination",
    "privacy_web_policy": "Πολιτική απορρήτου ιστοτόπου",
    "privacy_web_subtitle": "Πώς χειριζόμαστε τα δεδομένα σου",
    "automatic_updates": "Αυτόματες ενημερώσεις",
    "automatic_updates_subtitle": "Αυτόματος έλεγχος και λήψη νέων εκδόσεων Numination",
    "credits": "Μονάδες",
    "credits_subtitle": "Δες το υπόλοιπό σου και απόκτησε περισσότερες μονάδες",
    "subscriptions": "Συνδρομές",
    "subscriptions_subtitle": "Πλάνα, εβδομαδιαίες μονάδες και προνόμια",
    "refresh_plans": "Ανανέωση πλάνων",
    "choose_plan": "Επίλεξε πλάνο",
    "plans_intro": "Περισσότερες μονάδες για συνομιλίες, έργα και εργαλεία AI.",
    "plans_load_failed": "Δεν ήταν δυνατή η φόρτωση των πλάνων. Έλεγξε τη σύνδεσή σου και δοκίμασε ξανά.",
    "back_to_chats": "Επιστροφή στις συνομιλίες",
    "menu": "Μενού",
    "undo_changes": "Αναίρεση αλλαγών",
    "hide_files": "Απόκρυψη αρχείων",
    "show_files": "Εμφάνιση αρχείων",
    "download_project_zip": "Λήψη ZIP έργου",
    "project_files": "ΑΡΧΕΙΑ ΕΡΓΟΥ",
    "project_no_files": "Αυτό το έργο δεν έχει ακόμη αρχεία.",
    "coder_prompt": "Περιέγραψε τι θέλεις να δημιουργήσεις…",
    "stop_dictation": "Διακοπή υπαγόρευσης",
    "dictate_message": "Υπαγόρευση μηνύματος",
    "stop": "Διακοπή",
    "send": "Αποστολή",
    "local_sync_success": "Οι αλλαγές συγχρονίστηκαν: {written} αρχείο(α) ενημερώθηκε(αν), {deleted} διαγράφηκε(αν).",
    "local_sync_error": "Το Coder ενημέρωσε τον χώρο εργασίας, αλλά δεν ήταν δυνατός ο συγχρονισμός του τοπικού φακέλου:",
    "zip_saved": "Το ZIP αποθηκεύτηκε:"
  }
};

  static void bind(BuildContext context) {
    _context = context;
  }

  static String t(String key) {
    final context = _context;

    if (context == null) {
      return _fallback(key);
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final extra = _extraTranslations[languageCode]?[key];
    if (extra != null) return extra;

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
