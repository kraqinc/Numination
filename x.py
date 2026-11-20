from pathlib import Path
import re

files = {
    "pubspec.yaml": Path("pubspec.yaml").read_text(),
    "lib/features/widgets/coder_preview_screen.dart":
        Path("lib/features/widgets/coder_preview_screen.dart").read_text(),
    ".github/workflows/build.yml":
        Path(".github/workflows/build.yml").read_text(),
    "lib/core/update_service.dart":
        Path("lib/core/update_service.dart").read_text(),
    "lib/features/widgets/update_bottom_sheets.dart":
        Path("lib/features/widgets/update_bottom_sheets.dart").read_text(),
}


def replace_once(path, pattern, replacement, description):
    matches = list(re.finditer(pattern, files[path]))

    if len(matches) != 1:
        raise RuntimeError(
            f"{path}: {description}: "
            f"se esperaba 1 coincidencia y aparecieron {len(matches)}."
        )

    match = matches[0]
    value = replacement(match) if callable(replacement) else replacement

    files[path] = (
        files[path][:match.start()]
        + value
        + files[path][match.end():]
    )


def replace_once_in_method(
    path, method_name, pattern, replacement, description
):
    content = files[path]

    declaration = re.compile(
        rf"(?m)^[ \t]*static\b[^\n]*\b{re.escape(method_name)}\s*\("
    )

    starts = list(declaration.finditer(content))

    if len(starts) != 1:
        raise RuntimeError(
            f"{path}: función {method_name}: "
            f"se esperaba 1 declaración y aparecieron {len(starts)}."
        )

    start = starts[0].end()

    next_method = re.search(
        r"(?m)^[ \t]{2}static\b",
        content[start:]
    )

    end = start + next_method.start() if next_method else len(content)

    section = content[start:end]
    matches = list(re.finditer(pattern, section))

    if len(matches) != 1:
        raise RuntimeError(
            f"{path}: {description} dentro de {method_name}: "
            f"se esperaba 1 coincidencia y aparecieron {len(matches)}."
        )

    match = matches[0]
    value = replacement(match) if callable(replacement) else replacement

    section = (
        section[:match.start()]
        + value
        + section[match.end():]
    )

    files[path] = content[:start] + section + content[end:]


# ============================================================
# 1. WEBVIEW MULTIPLATAFORMA
# ============================================================

replace_once(
    "pubspec.yaml",
    r"(?m)^([ \t]*)webview_flutter:[ \t]*\^4\.14\.1[ \t]*$",
    lambda m: m.group(1) + "webview_all: ^1.5.2",
    "Dependencia WebView",
)

replace_once(
    "lib/features/widgets/coder_preview_screen.dart",
    r"(?m)^import 'package:webview_flutter/webview_flutter\.dart';$",
    "import 'package:webview_all/webview_all.dart';",
    "Import WebView",
)


# ============================================================
# 2. DEPENDENCIAS NATIVAS DE LINUX
# ============================================================

workflow = ".github/workflows/build.yml"
dependency = "libgirepository1.0-dev imagemagick"

if files[workflow].count(dependency) != 1:
    raise RuntimeError(
        f"{workflow}: no se encontró exactamente una dependencia."
    )

files[workflow] = files[workflow].replace(
    dependency,
    dependency + " libwebkit2gtk-4.1-dev",
    1,
)


# ============================================================
# 3. HELPER DE VERSIÓN REAL DE ESCRITORIO
# ============================================================

service = "lib/core/update_service.dart"

if "static Future<String> installedDesktopVersion" in files[service]:
    raise RuntimeError(
        "installedDesktopVersion ya existe en update_service.dart."
    )

anchor_pattern = (
    r"(?m)^[ \t]*static Future<AppUpdateInfo\?> "
    r"getLatestDesktopRelease\(\) async \{\r?\n"
    r"[ \t]*if \(!Platform\.isWindows && !Platform\.isLinux\) "
    r"return null;\r?\n"
    r"[ \t]*return _checkLatest\(platform: _desktopPlatform\);\r?\n"
    r"[ \t]*\}"
)

helper = r"""
  /// Devuelve la versión configurada durante la compilación
  /// de la aplicación de escritorio.
  static Future<String> installedDesktopVersion({
    String? fallbackVersion,
  }) async {
    final packageVersion = fallbackVersion ??
        (await PackageInfo.fromPlatform()).version.trim();

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
"""

replace_once(
    service,
    anchor_pattern,
    lambda m: m.group(0) + "\n\n" + helper.strip("\n"),
    "Inserción del helper",
)


# ============================================================
# 4. WINDOWS: SOLO SU PROPIA FUNCIÓN
# ============================================================

replace_once_in_method(
    service,
    "checkForWindowsUpdate",
    (
        r"(?m)^(?P<i>[ \t]*)final installed = "
        r"await PackageInfo\.fromPlatform\(\);[ \t]*\r?\n"
        r"(?:[ \t]*\r?\n)+"
        r"(?P=i)if \(!_isNewerVersion"
        r"\(update\.version, installed\.version\)\) \{"
    ),
    lambda m: (
        m.group("i")
        + "final installedVersion = await installedDesktopVersion();\n\n"
        + m.group("i")
        + "if (!_isNewerVersion(update.version, installedVersion)) {"
    ),
    "Comprobación de Windows",
)


# ============================================================
# 5. LINUX Y WINDOWS: ACTUALIZADOR DE ESCRITORIO
# ============================================================

replace_once_in_method(
    service,
    "checkForDesktopUpdate",
    (
        r"(?m)^(?P<i>[ \t]*)final installed = "
        r"await PackageInfo\.fromPlatform\(\);[ \t]*\r?\n"
        r"(?P=i)if \(!_isNewerVersion"
        r"\(update\.version, installed\.version\)\) return null;"
    ),
    lambda m: (
        m.group("i")
        + "final installedVersion = await installedDesktopVersion();\n"
        + m.group("i")
        + "if (!_isNewerVersion(update.version, installedVersion)) "
        + "return null;"
    ),
    "Comprobación del escritorio",
)


# ============================================================
# 6. ACERCA DE NUMINATION
# ============================================================

sheets = "lib/features/widgets/update_bottom_sheets.dart"

replace_once(
    sheets,
    (
        r"(?m)^(?P<i>[ \t]*)final installed = "
        r"await PackageInfo\.fromPlatform\(\);[ \t]*\r?\n"
        r"(?:[ \t]*\r?\n)?"
        r"(?P=i)if \(!context\.mounted\) return;"
    ),
    lambda m: (
        m.group("i")
        + "final installed = await PackageInfo.fromPlatform();\n"
        + m.group("i")
        + "final installedVersion = "
        + "await UpdateService.installedDesktopVersion(\n"
        + m.group("i")
        + "  fallbackVersion: installed.version,\n"
        + m.group("i")
        + ");\n"
        + m.group("i")
        + "if (!context.mounted) return;"
    ),
    "Versión instalada en Acerca de",
)

replace_once(
    sheets,
    r"(latest!\.version,\s*)installed\.version,",
    lambda m: m.group(1) + "installedVersion,",
    "Comparación de versiones",
)

replace_once(
    sheets,
    r"(?m)^([ \t]*value:[ \t]*)installed\.version,",
    lambda m: m.group(1) + "installedVersion,",
    "Visualización de versión",
)


# ============================================================
# 7. GUARDAR: SOLO DESPUÉS DE VALIDAR TODO
# ============================================================

for filename, content in files.items():
    Path(filename).write_text(content)

print("\nPARCHE APLICADO CORRECTAMENTE")
print("\nArchivos modificados:")

for filename in files:
    print(" -", filename)

print("\nTodas las coincidencias fueron validadas.")
