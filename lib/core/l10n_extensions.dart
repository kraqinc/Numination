import 'package:flutter/widgets.dart';

import '../l10n/gen/app_localizations.dart';
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}