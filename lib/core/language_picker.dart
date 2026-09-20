import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';
import 'locale_controller.dart';

/// Opens the interface-language chooser (MOB-070).
///
/// The sheet offers the device default alongside each shipped language.
/// "System default" has to be reachable: without it, a user who once chose a
/// language explicitly could never hand the decision back to the phone.
///
/// Both language names are written in their own language in every locale, so
/// a reader who cannot read the current interface can still find their own.
Future<void> showStudafyLanguagePicker(BuildContext context) async {
  final controller = LocaleScope.of(context);
  final selection = await showModalBottomSheet<_LanguageChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = AppL10n.of(sheetContext);
      return SafeArea(
        child: RadioGroup<_LanguageChoice>(
          groupValue: _LanguageChoice(controller.preference),
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  l10n.languagePickerTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(l10n.languagePickerSubtitle),
              ),
              RadioListTile<_LanguageChoice>(
                value: const _LanguageChoice(null),
                title: Text(l10n.languageSystemDefault),
                subtitle: Text(l10n.languageSystemDefaultDetail),
              ),
              RadioListTile<_LanguageChoice>(
                value: const _LanguageChoice(Locale('en')),
                title: Text(l10n.languageEnglish),
              ),
              RadioListTile<_LanguageChoice>(
                value: const _LanguageChoice(Locale('ar')),
                title: Text(l10n.languageArabic),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (selection != null) await controller.setLocale(selection.locale);
}

/// Wraps the nullable choice so "System default" is a selectable radio value
/// rather than an absence the group cannot represent.
@immutable
class _LanguageChoice {
  const _LanguageChoice(this.locale);

  final Locale? locale;

  @override
  bool operator ==(Object other) =>
      other is _LanguageChoice && other.locale == locale;

  @override
  int get hashCode => locale.hashCode;
}
