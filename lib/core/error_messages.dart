import 'dart:ui' as ui;

class AppErrorMessages {
  static String _languageCode = ui.PlatformDispatcher.instance.locale.languageCode;

  static String get languageCode => _languageCode;
  static bool get isEnglish => _languageCode.toLowerCase().startsWith('en');

  static void setLanguageCode(String value) {
    final code = value.trim().toLowerCase();
    _languageCode = code.startsWith('en') ? 'en' : 'es';
  }

  static String get connectionFailure => isEnglish
      ? 'No connection to Numination. Check your internet connection and try again.'
      : 'No se pudo conectar con Numination. Revisa tu conexión a internet e inténtalo de nuevo.';
  static String get requestTimedOut => isEnglish
      ? 'The request took too long. Please try again.'
      : 'La solicitud tardó demasiado. Inténtalo de nuevo.';
  static String get configurationError => isEnglish
      ? 'Numination is not configured correctly. Contact support if the problem continues.'
      : 'Numination no está configurado correctamente. Contacta al equipo de soporte si el problema continúa.';
  static String get invalidResponse => isEnglish
      ? 'The server returned an unreadable response. Please try again.'
      : 'El servidor devolvió una respuesta que no se pudo leer. Inténtalo de nuevo.';
  static String get genericFailure => isEnglish
      ? 'Something went wrong. Please try again.'
      : 'Ocurrió un problema. Inténtalo de nuevo.';
  static String get serverUnavailable => isEnglish
      ? 'Numination is temporarily unavailable. Please try again shortly.'
      : 'Numination no está disponible temporalmente. Inténtalo de nuevo en unos segundos.';
  static String get aiUnavailable => isEnglish
      ? 'Numination could not get an AI response right now. Please try again shortly.'
      : 'Numination no pudo obtener una respuesta de IA en este momento. Inténtalo de nuevo en unos segundos.';
  static String get streamInterrupted => isEnglish
      ? 'The response was interrupted. Send your message again to retry.'
      : 'La respuesta se interrumpió. Envía tu mensaje otra vez para reintentarlo.';
  static String get filesLoadFailed => isEnglish
      ? 'Project files could not be loaded. Check your connection and try again.'
      : 'No se pudieron cargar los archivos del proyecto. Revisa tu conexión e inténtalo de nuevo.';
  static String get historyLoadFailed => isEnglish
      ? 'This conversation could not be loaded. Return to the chat list and try again.'
      : 'No se pudo cargar esta conversación. Vuelve a la lista de chats e inténtalo de nuevo.';
  static String get projectsLoadFailed => isEnglish
      ? 'Your projects could not be loaded. Please try again.'
      : 'No se pudieron cargar tus proyectos. Inténtalo de nuevo.';
  static String get memoriesLoadFailed => isEnglish
      ? 'Your saved memories could not be loaded. Please try again.'
      : 'No se pudieron cargar tus memorias guardadas. Inténtalo de nuevo.';
  static String get memorySaveFailed => isEnglish
      ? 'The memory could not be saved. Check your connection and try again.'
      : 'No se pudo guardar la memoria. Revisa tu conexión e inténtalo de nuevo.';
  static String get artifactsLoadFailed => isEnglish
      ? 'Your files and saved snippets could not be loaded. Please try again.'
      : 'No se pudieron cargar tus archivos y fragmentos guardados. Inténtalo de nuevo.';
  static String get artifactDeleteFailed => isEnglish
      ? 'The saved item could not be deleted. Please try again.'
      : 'No se pudo eliminar el elemento guardado. Inténtalo de nuevo.';
  static String get artifactOpenFailed => isEnglish
      ? 'The file could not be opened. Check that it is still available.'
      : 'No se pudo abrir el archivo. Comprueba que siga disponible.';
  static String get artifactLinkFailed => isEnglish
      ? 'A secure link for this file could not be created. Please try again.'
      : 'No se pudo generar un enlace seguro para este archivo. Inténtalo de nuevo.';
  static String get chatsDeleteFailed => isEnglish
      ? 'Your conversations could not be deleted. Please try again.'
      : 'No se pudieron eliminar tus conversaciones. Inténtalo de nuevo.';
  static String get ageConfirmationFailed => isEnglish
      ? 'Your age confirmation could not be saved. Please try again.'
      : 'No se pudo guardar la confirmación de edad. Inténtalo de nuevo.';
  static String get signInFailed => isEnglish
      ? 'Sign-in failed. Check your connection and try again.'
      : 'No se pudo iniciar sesión. Revisa tu conexión e inténtalo de nuevo.';
  static String get googleSignInFailed => isEnglish
      ? 'Google sign-in could not be completed. Please try again.'
      : 'No se pudo completar el inicio de sesión con Google. Inténtalo de nuevo.';
  static String get githubSignInFailed => isEnglish
      ? 'GitHub sign-in could not be completed. Please try again.'
      : 'No se pudo completar el inicio de sesión con GitHub. Inténtalo de nuevo.';
  static String get invalidCredentials => isEnglish
      ? 'That email and password do not match. Check them and try again.'
      : 'El correo y la contraseña no coinciden. Revísalos e inténtalo de nuevo.';
  static String get verifyEmail => isEnglish
      ? 'Confirm your email address before signing in.'
      : 'Confirma tu correo electrónico antes de iniciar sesión.';
  static String get authRateLimited => isEnglish
      ? 'Too many sign-in attempts. Wait a moment before trying again.'
      : 'Hubo demasiados intentos de inicio de sesión. Espera un momento e inténtalo de nuevo.';
  static String get projectCreateFailed => isEnglish
      ? 'The project could not be created. Check the name and try again.'
      : 'No se pudo crear el proyecto. Revisa el nombre e inténtalo de nuevo.';
  static String get undoFailed => isEnglish
      ? 'The changes could not be reverted. Please try again.'
      : 'No se pudieron deshacer los cambios. Inténtalo de nuevo.';
  static String get downloadFailed => isEnglish
      ? 'The project could not be downloaded. Check your connection and try again.'
      : 'No se pudo descargar el proyecto. Revisa tu conexión e inténtalo de nuevo.';
  static String get attachmentUnsupported => isEnglish
      ? 'This file type is not supported. Attach a text or source-code file instead.'
      : 'Este tipo de archivo no es compatible. Adjunta un archivo de texto o código.';
  static String get attachmentTooLarge => isEnglish
      ? 'The file is too large. Choose a smaller file (up to 1 MB).'
      : 'El archivo pesa demasiado. Elige uno más pequeño (máximo 1 MB).';
  static String get attachmentEmpty => isEnglish
      ? 'The selected file is empty.'
      : 'El archivo seleccionado está vacío.';
  static String get previewInvalidAddress => isEnglish
      ? 'The preview address is invalid. Go back to Coder and reopen the preview to generate a fresh link.'
      : 'La dirección de la vista previa no es válida. Vuelve a Coder y abre la vista previa para generar un enlace nuevo.';
  static String get previewExpired => isEnglish
      ? 'This preview link has expired. Go back to Coder and open the preview again.'
      : 'El enlace de la vista previa venció. Vuelve a Coder y abre la vista previa otra vez.';
  static String get previewProjectMissing => isEnglish
      ? 'This project could not be found. Return to your project list and open it again.'
      : 'No encontramos este proyecto. Vuelve a la lista de proyectos y ábrelo otra vez.';
  static String get previewDidNotRender => isEnglish
      ? 'The preview opened, but the project did not display any content. Ask Coder to check the app entry point and imports.'
      : 'La vista previa abrió, pero el proyecto no mostró contenido. Pídele a Coder que revise el archivo de entrada y los imports.';
  static String get previewLoadFailed => isEnglish
      ? 'The preview could not be loaded. Check your connection and try again.'
      : 'No se pudo cargar la vista previa. Revisa tu conexión e inténtalo de nuevo.';
  static String get previewRuntimeFailed => isEnglish
      ? 'The preview could not run this project. It may use a library that is not supported in the preview yet. Ask Coder to simplify or replace that dependency.'
      : 'La vista previa no pudo ejecutar este proyecto. Puede usar una librería que todavía no es compatible. Pídele a Coder que la reemplace o simplifique esa parte.';
  static String get previewNotReady => isEnglish
      ? 'Preview will be available when the project contains a supported web app.'
      : 'La vista previa estará disponible cuando el proyecto tenga una aplicación web compatible.';
  static String fromServer({required int statusCode, String? code, String? rawMessage}) {
    final detail = '${code ?? ''} ${rawMessage ?? ''}'.toLowerCase();



    if (detail.contains('requested path is invalid') || detail.contains('preview_invalid_path')) {
      return previewInvalidAddress;
    }
    if (detail.contains('preview') && (detail.contains('expired') || detail.contains('vencido') || detail.contains('no autorizado'))) {
      return previewExpired;
    }
    if (detail.contains('insufficient_credits') ||
        detail.contains('insufficient credits') ||
        detail.contains('créditos insuficientes') ||
        detail.contains('no hay créditos') ||
        detail.contains('sin créditos')) {
      return isEnglish
          ? 'You do not have enough AI credits for this request. Recharge your credits and try again.'
          : 'No tienes suficientes créditos de IA para esta solicitud. Recarga tus créditos e inténtalo de nuevo.';
    }
    if (detail.contains('fallback_not_sent') ||
        detail.contains('fallback_not_send') ||
        detail.contains('fallback not sent') ||
        detail.contains('fallback not send') ||
        detail.contains('provider_exhausted') ||
        detail.contains('provider unavailable') ||
        detail.contains('upstream') ||
        detail.contains('gemini') ||
        detail.contains('openrouter') ||
        detail.contains('pollinations') ||
        detail.contains('deepseek') ||
        detail.contains('codestral')) {
      return aiUnavailable;
    }
    if (detail.contains('cuenta bloqueada') || detail.contains('banned for age') || detail.contains('edad mínima')) {
      return isEnglish
          ? 'This account cannot use Numination because it does not meet the minimum age requirement.'
          : 'Esta cuenta no puede usar Numination porque no cumple el requisito de edad mínima.';
    }
    if (detail.contains('edad') || detail.contains('age verification') || statusCode == 428) {
      return isEnglish
          ? 'Please finish the age confirmation in your account to continue.'
          : 'Completa la confirmación de edad en tu cuenta para continuar.';
    }
    if (detail.contains('pro') && (detail.contains('require') || detail.contains('requiere'))) {
      return isEnglish
          ? 'This feature requires a Numination Pro plan.'
          : 'Esta función requiere un plan Numination Pro.';
    }
    if (statusCode < 0) return connectionFailure;
    if (statusCode == 401) {
      return isEnglish
          ? 'Your session may have expired. Sign in again and retry.'
          : 'Es posible que tu sesión haya vencido. Inicia sesión otra vez e inténtalo de nuevo.';
    }
    if (statusCode == 403) {
      return isEnglish
          ? 'You do not have permission to perform this action.'
          : 'No tienes permiso para realizar esta acción.';
    }
    if (statusCode == 404) {
      return isEnglish
          ? 'We could not find that item. Refresh the screen and try again.'
          : 'No encontramos ese elemento. Actualiza la pantalla e inténtalo de nuevo.';
    }
    if (statusCode == 409) {
      return isEnglish
          ? 'This action conflicts with the current project state. Refresh and try again.'
          : 'Esta acción entra en conflicto con el estado actual del proyecto. Actualiza e inténtalo de nuevo.';
    }
    if (statusCode == 413) {
      return attachmentTooLarge;
    }
    if (statusCode == 422 || statusCode == 400) {
      return isEnglish
          ? 'Some information is missing or invalid. Check the fields and try again.'
          : 'Falta información o hay datos inválidos. Revisa los campos e inténtalo de nuevo.';
    }
    if (statusCode == 408 || statusCode == 504) return requestTimedOut;
    if (statusCode == 429) {
      return isEnglish
          ? 'There are too many requests right now. Wait a moment and try again.'
          : 'Hay demasiadas solicitudes en este momento. Espera un momento e inténtalo de nuevo.';
    }
    if (statusCode >= 500) return serverUnavailable;
    return genericFailure;
  }

  static String fromException(Object error, {String? fallback}) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('timeoutexception') || lower.contains('timed out') || lower.contains('timeout')) {
      return requestTimedOut;
    }
    if (lower.contains('socketexception') || lower.contains('failed host lookup') ||
        lower.contains('connection reset') || lower.contains('network is unreachable') ||
        lower.contains('clientexception')) {
      return connectionFailure;
    }
    if (lower.contains('por ahora coder admite') || lower.contains('not supported') || lower.contains('tipo de archivo')) {
      return attachmentUnsupported;
    }
    if (lower.contains('debe pesar entre') || lower.contains('1 mb') || lower.contains('demasiado grande') || lower.contains('too large')) {
      return attachmentTooLarge;
    }
    if (lower.contains('archivo está vacío') || lower.contains('file is empty')) return attachmentEmpty;
    if (lower.contains('permission denied')) {
      return isEnglish ? 'You do not have permission to perform this action.' : 'No tienes permiso para realizar esta acción.';
    }
    return fallback ?? genericFailure;
  }

  static String fromAuthError(String raw, {String? fallback}) {
    final value = raw.toLowerCase();
    if (value.contains('invalid login credentials') || value.contains('invalid credentials') ||
        value.contains('email or password') || value.contains('wrong password')) {
      return invalidCredentials;
    }
    if (value.contains('email not confirmed') || value.contains('email_not_confirmed') ||
        value.contains('confirm your email')) {
      return verifyEmail;
    }
    if (value.contains('too many requests') || value.contains('rate limit') || value.contains('over_request_rate_limit')) {
      return authRateLimited;
    }
    if (value.contains('network') || value.contains('socketexception') || value.contains('timeout')) {
      return connectionFailure;
    }
    return fallback ?? signInFailed;
  }

  static String fromPreviewRuntime(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('requested path is invalid')) return previewInvalidAddress;
    if (value.contains('preview no autorizado') || value.contains('expired')) return previewExpired;
    if (value.contains('proyecto no encontrado') || value.contains('project not found')) return previewProjectMissing;
    return previewRuntimeFailed;
  }
}
