import 'package:flutter/material.dart';

enum StudafyCalendarPreference { gregorian, hijri }

class StudafyLocaleController extends ChangeNotifier {
  StudafyLocaleController._();
  static final instance = StudafyLocaleController._();

  Locale locale = const Locale('en');
  StudafyCalendarPreference calendar = StudafyCalendarPreference.gregorian;

  void setLocale(Locale value) {
    if (locale == value) return;
    locale = value;
    notifyListeners();
  }

  void setCalendar(StudafyCalendarPreference value) {
    if (calendar == value) return;
    calendar = value;
    notifyListeners();
  }
}

Future<void> showStudafyLanguagePicker(BuildContext context) async {
  final controller = StudafyLocaleController.instance;
  final selection = await showModalBottomSheet<Locale>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: RadioGroup<Locale>(
        groupValue: controller.locale,
        onChanged: (value) => Navigator.pop(context, value),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'App language',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('The interface direction changes automatically.'),
            ),
            RadioListTile<Locale>(value: Locale('en'), title: Text('English')),
            RadioListTile<Locale>(value: Locale('ar'), title: Text('العربية')),
          ],
        ),
      ),
    ),
  );
  if (selection != null) controller.setLocale(selection);
}

class StudafyLocalizations {
  StudafyLocalizations(this.locale);

  final Locale locale;

  static StudafyLocalizations of(BuildContext context) =>
      Localizations.of<StudafyLocalizations>(context, StudafyLocalizations) ??
      StudafyLocalizations(const Locale('en'));

  static const LocalizationsDelegate<StudafyLocalizations> delegate =
      _StudafyLocalizationsDelegate();

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static const _values = <String, Map<String, String>>{
    'en': {
      'today': 'Today',
      'classes': 'Classes',
      'teaching': 'Teaching',
      'gradebook': 'Gradebook',
      'inbox': 'Inbox',
      'learning': 'Learning',
      'insights': 'Insights+',
      'updates': 'Updates',
      'messages': 'Messages',
      'notebook': 'Notebook',
      'work': 'Work',
      'grades': 'Grades',
      'coach': 'Study Coach',
    },
    'ar': {
      'today': 'اليوم',
      'classes': 'الفصول',
      'teaching': 'التدريس',
      'gradebook': 'سجل الدرجات',
      'inbox': 'الوارد',
      'learning': 'التعلّم',
      'insights': 'رؤى+',
      'updates': 'التحديثات',
      'messages': 'الرسائل',
      'notebook': 'دفتر الدروس',
      'work': 'الأعمال',
      'grades': 'الدرجات',
      'coach': 'مدرب الدراسة',
    },
  };

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
}

class _StudafyLocalizationsDelegate
    extends LocalizationsDelegate<StudafyLocalizations> {
  const _StudafyLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => StudafyLocalizations.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<StudafyLocalizations> load(Locale locale) async =>
      StudafyLocalizations(locale);

  @override
  bool shouldReload(_StudafyLocalizationsDelegate old) => false;
}
