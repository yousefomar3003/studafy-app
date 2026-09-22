import 'package:flutter/widgets.dart';

import '../../../core/failures.dart';
import '../../../core/studafy_localizations.dart';

/// Guardian home copy in both shipped locales.
String familyText(
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

String familyFailureText(BuildContext context, Failure failure) {
  final key = 'error.${failure.code}';
  final value = familyText(context, key);
  return value == key ? familyText(context, 'error.UNKNOWN') : value;
}

const _strings = <String, Map<String, String>>{
  'en': {
    'title': 'My family',
    'children': 'My children',
    'empty.title': 'No children linked yet',
    'empty.message': 'Ask your child for their Studafy ID. They approve your request before you can follow their progress.',
    'link': 'Link a child',
    'link.title': 'Link a child',
    'link.hint': 'Studafy ID',
    'link.find': 'Find',
    'link.notFound': 'No student has that Studafy ID. Check it and try again.',
    'link.confirm': 'Request link to {name}',
    'link.sent': 'Request sent. {name} must approve it before you can see their records.',
    'status.pending': 'Waiting for your child',
    'status.verified': 'Linked',
    'status.declined': 'Request declined',
    'status.revoked': 'No longer linked',
    'view': 'View progress',
    'progress.title': '{name}\'s progress',
    'progress.average': 'Average of published grades',
    'progress.graded': '{count} published grades',
    'progress.attendance': 'Attendance',
    'progress.sessions': '{count} recorded sessions',
    'progress.none': 'No data yet',
    'progress.breakdown':
        'Present {present} · Late {late} · Absent {absent} · Excused {excused}',
    'progress.source':
        'Calculated from grades the school has published and attendance it '
        'has recorded. Ask the school if something looks wrong.',
    'approvals.title': 'Waiting for your approval',
    'approvals.detail': '{name} asked to subscribe to Student Notebook.',
    'approvals.approve': 'Approve',
    'approvals.decline': 'Decline',
    'approvals.done': 'Your decision was sent.',
    'retry': 'Try again',
    'cancel': 'Cancel',
    'error.title': 'Your family could not load',
    'error.REAUTH_REQUIRED':
        'For your security, sign out and sign in again, then approve.',
    'error.FORBIDDEN': 'You do not have access to this.',
    'error.NOT_FOUND': 'This is no longer available.',
    'error.INVALID_STATE': 'This request has already been decided.',
    'error.RATE_LIMITED': 'Too many attempts. Wait a moment and try again.',
    'error.NETWORK':
        'Studafy could not reach the school. Check your connection.',
    'error.UNAUTHORIZED': 'Please sign in again.',
    'error.VALIDATION': 'Enter the Studafy ID.',
    'error.UNKNOWN': 'Something went wrong. Please try again.',
  },
  'ar': {
    'title': 'عائلتي',
    'children': 'أطفالي',
    'empty.title': 'لم يتم ربط أي طفل بعد',
    'empty.message': 'اطلب من طفلك معرّف Studafy الخاص به. يجب أن يوافق على طلبك قبل أن تتمكن من متابعة تقدمه.',
    'link': 'ربط طفل',
    'link.title': 'ربط طفل',
    'link.hint': 'رقم Studafy',
    'link.find': 'بحث',
    'link.notFound': 'لا يوجد طالب بهذا الرقم. تحقق منه وحاول مرة أخرى.',
    'link.confirm': 'طلب الربط مع {name}',
    'link.sent':
        'تم إرسال الطلب. يجب أن يوافق {name} قبل أن تتمكن من رؤية سجلاته.',
    'status.pending': 'بانتظار موافقة طفلك',
    'status.verified': 'مرتبط',
    'status.declined': 'تم رفض الطلب',
    'status.revoked': 'لم يعد مرتبطاً',
    'view': 'عرض التقدم',
    'progress.title': 'تقدم {name}',
    'progress.average': 'متوسط الدرجات المنشورة',
    'progress.graded': '{count} درجات منشورة',
    'progress.attendance': 'الحضور',
    'progress.sessions': '{count} حصص مسجلة',
    'progress.none': 'لا توجد بيانات بعد',
    'progress.breakdown':
        'حاضر {present} · متأخر {late} · غائب {absent} · بعذر {excused}',
    'progress.source':
        'محسوب من الدرجات التي نشرتها المدرسة والحضور الذي سجلته. تواصل مع '
        'المدرسة إذا بدا شيء غير صحيح.',
    'approvals.title': 'بانتظار موافقتك',
    'approvals.detail': 'طلب {name} الاشتراك في دفتر الطالب.',
    'approvals.approve': 'موافقة',
    'approvals.decline': 'رفض',
    'approvals.done': 'تم إرسال قرارك.',
    'retry': 'حاول مرة أخرى',
    'cancel': 'إلغاء',
    'error.title': 'تعذر تحميل بيانات العائلة',
    'error.REAUTH_REQUIRED':
        'لحمايتك، سجّل الخروج ثم سجّل الدخول مرة أخرى، ثم وافق.',
    'error.FORBIDDEN': 'ليس لديك صلاحية الوصول إلى هذا.',
    'error.NOT_FOUND': 'لم يعد هذا متاحاً.',
    'error.INVALID_STATE': 'تم البت في هذا الطلب مسبقاً.',
    'error.RATE_LIMITED': 'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.',
    'error.NETWORK': 'تعذر على Studafy الوصول إلى المدرسة. تحقق من اتصالك.',
    'error.UNAUTHORIZED': 'يرجى تسجيل الدخول مرة أخرى.',
    'error.VALIDATION': 'أدخل رقم Studafy.',
    'error.UNKNOWN': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
  },
};

Map<String, Set<String>> familyStringKeys() => {
  for (final entry in _strings.entries) entry.key: entry.value.keys.toSet(),
};
