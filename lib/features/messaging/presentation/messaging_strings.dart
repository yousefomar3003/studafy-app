import 'package:flutter/widgets.dart';

import '../../../core/failures.dart';
import '../../../core/studafy_localizations.dart';

/// Messaging copy, owned by this slice in both shipped locales. Lookup
/// falls back to English, then to the key, like StudafyLocalizations.
String messagingText(
  BuildContext context,
  String key, [
  Map<String, String> args = const {},
]) {
  final code = StudafyLocalizations.of(context).locale.languageCode;
  var value = _strings[code]?[key] ?? _strings['en']![key] ?? key;
  args.forEach((name, replacement) {
    value = value.replaceAll('{$name}', replacement);
  });
  return value;
}

/// A failure explained in the reader's language. Server text never shows.
String messagingFailureText(BuildContext context, Failure failure) {
  final key = 'error.${failure.code}';
  final value = messagingText(context, key);
  return value == key ? messagingText(context, 'error.UNKNOWN') : value;
}

const _strings = <String, Map<String, String>>{
  'en': {
    'title': 'Messages',
    'empty.title': 'No conversations yet',
    'empty.message': 'Start a conversation with your school.',
    'new': 'New message',
    'noSchool': 'Choose a school to see messages.',
    'retry': 'Try again',
    'error.title': 'Messages could not load',
    'compose.hint': 'Write a message',
    'send': 'Send',
    'sendFailed': 'Not sent. Tap send to try again.',
    'loadOlder': 'Load earlier messages',
    'you': 'You',
    'unknownPerson': 'Someone',
    'menu.reportConversation': 'Report conversation',
    'menu.reportPerson': 'Report {name}',
    'menu.blockPerson': 'Block {name}',
    'menu.blocked': 'Blocked people',
    'message.report': 'Report message',
    'report.title': 'Report',
    'report.intro':
        'Your report goes to your school\'s safeguarding team. The person you '
        'report is not told who reported them.',
    'report.reason': 'What is the problem?',
    'reason.harassment': 'Bullying or harassment',
    'reason.inappropriate': 'Inappropriate content',
    'reason.safety': 'I am worried about someone\'s safety',
    'reason.spam': 'Spam',
    'reason.other': 'Something else',
    'report.details': 'Tell us more (optional)',
    'report.consent': 'The school may contact me about this report',
    'report.alsoBlock': 'Also block this person',
    'report.submit': 'Send report',
    'report.sent': 'Report sent. Thank you for telling us.',
    'report.urgent':
        'If someone is in immediate danger, contact emergency services or a '
        'trusted adult now.',
    'block.title': 'Block {name}?',
    'block.message':
        'You will not be able to message each other. Messages already sent '
        'stay visible to the school.',
    'block.confirm': 'Block',
    'block.done': '{name} is blocked.',
    'cancel': 'Cancel',
    'blocked.title': 'Blocked people',
    'blocked.empty': 'You have not blocked anyone.',
    'unblock': 'Unblock',
    'unblock.done': 'Unblocked.',
    'blocked.banner':
        'You blocked someone in this conversation. Unblock them to send '
        'messages.',
    'new.title': 'New message',
    'new.empty': 'No one is available to message.',
    'new.search': 'Search people',
    'subject.hint': 'Subject (optional)',
    'start': 'Start conversation',
    'role.staff': 'School staff',
    'role.student': 'Student',
    'role.guardian': 'Parent or guardian',
    'guardianOf': 'Guardian of {names}',
    'error.MESSAGING_DISABLED': 'Your school has not turned on messaging yet.',
    'error.CONTACT_NOT_ALLOWED': 'You cannot message this person.',
    'error.FORBIDDEN':
        'You cannot send messages here. You may have blocked someone, or '
        'someone may have blocked you.',
    'error.NOT_FOUND': 'This conversation is no longer available.',
    'error.INVALID_STATE':
        'You already reported this in the last day. The school has it.',
    'error.WINDOW_CLOSED':
        'You have sent many reports today. Please contact the school '
        'directly.',
    'error.RATE_LIMITED': 'Too many attempts. Wait a moment and try again.',
    'error.NETWORK':
        'Studafy could not reach the school. Check your connection.',
    'error.UNAUTHORIZED': 'Please sign in again.',
    'error.VALIDATION': 'Write a message first.',
    'error.UNKNOWN': 'Something went wrong. Please try again.',
  },
  'ar': {
    'title': 'الرسائل',
    'empty.title': 'لا توجد محادثات بعد',
    'empty.message': 'ابدأ محادثة مع مدرستك.',
    'new': 'رسالة جديدة',
    'noSchool': 'اختر مدرسة لعرض الرسائل.',
    'retry': 'حاول مرة أخرى',
    'error.title': 'تعذر تحميل الرسائل',
    'compose.hint': 'اكتب رسالة',
    'send': 'إرسال',
    'sendFailed': 'لم يتم الإرسال. اضغط إرسال للمحاولة مرة أخرى.',
    'loadOlder': 'تحميل الرسائل السابقة',
    'you': 'أنت',
    'unknownPerson': 'شخص ما',
    'menu.reportConversation': 'الإبلاغ عن المحادثة',
    'menu.reportPerson': 'الإبلاغ عن {name}',
    'menu.blockPerson': 'حظر {name}',
    'menu.blocked': 'الأشخاص المحظورون',
    'message.report': 'الإبلاغ عن الرسالة',
    'report.title': 'إبلاغ',
    'report.intro':
        'يصل بلاغك إلى فريق الحماية في مدرستك. لن يعرف الشخص المبلَّغ عنه '
        'هوية المبلِّغ.',
    'report.reason': 'ما المشكلة؟',
    'reason.harassment': 'تنمر أو مضايقة',
    'reason.inappropriate': 'محتوى غير لائق',
    'reason.safety': 'أنا قلق على سلامة شخص ما',
    'reason.spam': 'رسائل مزعجة',
    'reason.other': 'سبب آخر',
    'report.details': 'أخبرنا بالمزيد (اختياري)',
    'report.consent': 'يمكن للمدرسة التواصل معي بشأن هذا البلاغ',
    'report.alsoBlock': 'حظر هذا الشخص أيضاً',
    'report.submit': 'إرسال البلاغ',
    'report.sent': 'تم إرسال البلاغ. شكراً لإخبارنا.',
    'report.urgent':
        'إذا كان أحد في خطر مباشر، اتصل بخدمات الطوارئ أو بشخص بالغ تثق به '
        'الآن.',
    'block.title': 'حظر {name}؟',
    'block.message':
        'لن تتمكنا من مراسلة بعضكما. تبقى الرسائل المرسلة سابقاً مرئية '
        'للمدرسة.',
    'block.confirm': 'حظر',
    'block.done': 'تم حظر {name}.',
    'cancel': 'إلغاء',
    'blocked.title': 'الأشخاص المحظورون',
    'blocked.empty': 'لم تقم بحظر أي شخص.',
    'unblock': 'إلغاء الحظر',
    'unblock.done': 'تم إلغاء الحظر.',
    'blocked.banner':
        'لقد حظرت شخصاً في هذه المحادثة. ألغِ الحظر لإرسال الرسائل.',
    'new.title': 'رسالة جديدة',
    'new.empty': 'لا يوجد أحد متاح للمراسلة.',
    'new.search': 'ابحث عن الأشخاص',
    'subject.hint': 'الموضوع (اختياري)',
    'start': 'بدء المحادثة',
    'role.staff': 'طاقم المدرسة',
    'role.student': 'طالب',
    'role.guardian': 'ولي أمر',
    'guardianOf': 'ولي أمر {names}',
    'error.MESSAGING_DISABLED': 'لم تقم مدرستك بتفعيل المراسلة بعد.',
    'error.CONTACT_NOT_ALLOWED': 'لا يمكنك مراسلة هذا الشخص.',
    'error.FORBIDDEN':
        'لا يمكنك إرسال رسائل هنا. ربما قمت بحظر شخص ما، أو قام أحدهم '
        'بحظرك.',
    'error.NOT_FOUND': 'هذه المحادثة لم تعد متاحة.',
    'error.INVALID_STATE':
        'لقد أبلغت عن هذا خلال اليوم الماضي. المدرسة تتابعه.',
    'error.WINDOW_CLOSED':
        'أرسلت عدداً كبيراً من البلاغات اليوم. يرجى التواصل مع المدرسة '
        'مباشرة.',
    'error.RATE_LIMITED': 'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.',
    'error.NETWORK': 'تعذر على Studafy الوصول إلى المدرسة. تحقق من اتصالك.',
    'error.UNAUTHORIZED': 'يرجى تسجيل الدخول مرة أخرى.',
    'error.VALIDATION': 'اكتب رسالة أولاً.',
    'error.UNKNOWN': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
  },
};

/// Every key in both locales, for the parity test.
Map<String, Set<String>> messagingStringKeys() => {
  for (final entry in _strings.entries) entry.key: entry.value.keys.toSet(),
};
