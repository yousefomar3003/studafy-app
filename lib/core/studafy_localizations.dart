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
      'notifications.title': 'Notifications',
      'notifications.markAllRead': 'Mark all read',
      'notifications.errorTitle': "Couldn't load notifications",
      'notifications.retry': 'Try again',
      'notifications.offlineBanner':
          'Showing your last saved notifications — reconnect to update.',
      'notifications.emptyTitle': 'No notifications yet',
      'notifications.emptyMessage': "You'll see updates here as they happen.",
      'notifications.loading': 'Loading…',
      'notifications.loadMore': 'Load more',
      'notification.academic.assessment_published.title':
          'Assessment published',
      'notification.academic.assessment_published.detail':
          'A new assessment is ready for one of your classes.',
      'notification.academic.assignment_published.title':
          'Assignment published',
      'notification.academic.assignment_published.detail':
          'A new assignment is ready for one of your classes.',
      'notification.academic.grade_published.title': 'New grade',
      'notification.academic.grade_published.detail':
          'A grade was published. Open Grades to view it.',
      'notification.academic.resource_published.title': 'New class material',
      'notification.academic.resource_published.detail':
          'Your teacher shared new material for one of your classes.',
      'notification.academic.wellbeing_shared.title': 'Wellbeing note shared',
      'notification.academic.wellbeing_shared.detail':
          'A wellbeing note was shared with you.',
      'notification.billing.purchase_approval_requested.title':
          'Purchase approval needed',
      'notification.billing.purchase_approval_requested.detail':
          'Your child asked you to approve a subscription.',
      'notification.billing.purchase_approval_approved.title':
          'Purchase approved',
      'notification.billing.purchase_approval_approved.detail':
          'A guardian approved your subscription request.',
      'notification.billing.purchase_approval_declined.title':
          'Purchase declined',
      'notification.billing.purchase_approval_declined.detail':
          'A guardian declined your subscription request.',
      'notification.meetings.scheduled.title': 'Meeting confirmed',
      'notification.meetings.scheduled.detail':
          'A meeting was scheduled. Check your calendar for the invitation.',
      'notification.meetings.failed.title': 'Meeting not scheduled',
      'notification.meetings.failed.detail':
          'A meeting you requested could not be scheduled. Please try again.',
      'notification.communications.announcement_created.title':
          'New announcement',
      'notification.communications.announcement_created.detail':
          'A new announcement was posted.',
      'notification.communications.message_sent.title': 'New message',
      'notification.communications.message_sent.detail':
          'You received a new message.',
      'notification.family.guardian_link_requested.title': 'Connection request',
      'notification.family.guardian_link_requested.detail':
          'Someone requested to connect as a guardian.',
      'notification.family.guardian_link_revoked.title': 'Connection removed',
      'notification.family.guardian_link_revoked.detail':
          'A family connection was removed.',
      'notification.family.guardian_link_verified.title': 'Connection verified',
      'notification.family.guardian_link_verified.detail':
          'A family connection was verified.',
      'notification.invitations.issued.title': 'Invitation sent',
      'notification.invitations.issued.detail': 'An invitation was issued.',
      'notification.meetings.cancelled.title': 'Meeting cancelled',
      'notification.meetings.cancelled.detail':
          'A scheduled meeting was cancelled.',
      'notification.meetings.requested.title': 'Meeting requested',
      'notification.meetings.requested.detail': 'A meeting was requested.',
      'notification.school_admin.classroom_staff_assigned.title':
          'Staff assigned',
      'notification.school_admin.classroom_staff_assigned.detail':
          'A staff member was assigned to a class.',
      'notification.school_admin.classroom_staff_removed.title':
          'Staff removed',
      'notification.school_admin.classroom_staff_removed.detail':
          'A staff member was removed from a class.',
      'notification.school_admin.membership_granted.title': 'Access granted',
      'notification.school_admin.membership_granted.detail':
          'School access was granted.',
      'notification.school_admin.student_enrolled.title': 'Student enrolled',
      'notification.school_admin.student_enrolled.detail':
          'A student was enrolled.',
      'notification.school_admin.student_transferred.title':
          'Student transferred',
      'notification.school_admin.student_transferred.detail':
          'A student was transferred between classes.',
      'notification.school_admin.student_withdrawn.title': 'Student withdrawn',
      'notification.school_admin.student_withdrawn.detail':
          'A student was withdrawn.',
      'notification.support_access.approved.title': 'Support access approved',
      'notification.support_access.approved.detail':
          'A support access request was approved.',
      'notification.support_access.requested.title': 'Support access requested',
      'notification.support_access.requested.detail':
          'Support access was requested.',
      'notification.support_access.revoked.title': 'Support access revoked',
      'notification.support_access.revoked.detail':
          'Support access was revoked.',
      'notification.support_access.started.title': 'Support session started',
      'notification.support_access.started.detail':
          'A support session has started.',
      'notification.generic.title': 'Notification',
      'notification.generic.detail': 'You have a new update.',
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
      'notifications.title': 'الإشعارات',
      'notifications.markAllRead': 'تعليم الكل كمقروء',
      'notifications.errorTitle': 'تعذّر تحميل الإشعارات',
      'notifications.retry': 'إعادة المحاولة',
      'notifications.offlineBanner':
          'يتم عرض آخر الإشعارات المحفوظة — أعد الاتصال للتحديث.',
      'notifications.emptyTitle': 'لا توجد إشعارات بعد',
      'notifications.emptyMessage': 'ستظهر هنا التحديثات فور حدوثها.',
      'notifications.loading': 'جارٍ التحميل…',
      'notifications.loadMore': 'تحميل المزيد',
      'notification.academic.assessment_published.title': 'تم نشر التقييم',
      'notification.academic.assessment_published.detail':
          'أصبح تقييم جديد متاحًا لأحد فصولك.',
      'notification.academic.assignment_published.title': 'تم نشر الواجب',
      'notification.academic.assignment_published.detail':
          'أصبح واجب جديد متاحًا لأحد فصولك.',
      'notification.academic.grade_published.title': 'درجة جديدة',
      'notification.academic.grade_published.detail':
          'تم نشر درجة جديدة. افتح الدرجات للاطلاع عليها.',
      'notification.academic.resource_published.title': 'مادة دراسية جديدة',
      'notification.academic.resource_published.detail':
          'شارك معلمك مادة جديدة لأحد فصولك.',
      'notification.academic.wellbeing_shared.title': 'ملاحظة رفاهية',
      'notification.academic.wellbeing_shared.detail':
          'تمت مشاركة ملاحظة متعلقة بالرفاهية معك.',
      'notification.billing.purchase_approval_requested.title':
          'مطلوب الموافقة على شراء',
      'notification.billing.purchase_approval_requested.detail':
          'طلب طفلك موافقتك على اشتراك.',
      'notification.billing.purchase_approval_approved.title':
          'تمت الموافقة على الشراء',
      'notification.billing.purchase_approval_approved.detail':
          'وافق ولي الأمر على طلب اشتراكك.',
      'notification.billing.purchase_approval_declined.title': 'تم رفض الشراء',
      'notification.billing.purchase_approval_declined.detail':
          'رفض ولي الأمر طلب اشتراكك.',
      'notification.meetings.scheduled.title': 'تم تأكيد الاجتماع',
      'notification.meetings.scheduled.detail':
          'تمت جدولة اجتماع. تحقق من تقويمك لرؤية الدعوة.',
      'notification.meetings.failed.title': 'لم تتم جدولة الاجتماع',
      'notification.meetings.failed.detail':
          'تعذرت جدولة اجتماع طلبته. يرجى المحاولة مرة أخرى.',
      'notification.communications.announcement_created.title': 'إعلان جديد',
      'notification.communications.announcement_created.detail':
          'تم نشر إعلان جديد.',
      'notification.communications.message_sent.title': 'رسالة جديدة',
      'notification.communications.message_sent.detail': 'وصلتك رسالة جديدة.',
      'notification.family.guardian_link_requested.title': 'طلب ربط عائلي',
      'notification.family.guardian_link_requested.detail':
          'طلب أحدهم الربط كولي أمر.',
      'notification.family.guardian_link_revoked.title': 'إزالة ربط عائلي',
      'notification.family.guardian_link_revoked.detail':
          'تمت إزالة ربط عائلي.',
      'notification.family.guardian_link_verified.title':
          'تم تأكيد الربط العائلي',
      'notification.family.guardian_link_verified.detail':
          'تم تأكيد ربط عائلي.',
      'notification.invitations.issued.title': 'تم إرسال دعوة',
      'notification.invitations.issued.detail': 'تم إصدار دعوة.',
      'notification.meetings.cancelled.title': 'تم إلغاء الاجتماع',
      'notification.meetings.cancelled.detail': 'تم إلغاء اجتماع مجدول.',
      'notification.meetings.requested.title': 'طلب اجتماع',
      'notification.meetings.requested.detail': 'تم طلب اجتماع.',
      'notification.school_admin.classroom_staff_assigned.title': 'تعيين موظف',
      'notification.school_admin.classroom_staff_assigned.detail':
          'تم تعيين موظف لأحد الفصول.',
      'notification.school_admin.classroom_staff_removed.title': 'إزالة موظف',
      'notification.school_admin.classroom_staff_removed.detail':
          'تمت إزالة موظف من أحد الفصول.',
      'notification.school_admin.membership_granted.title': 'تم منح الصلاحية',
      'notification.school_admin.membership_granted.detail':
          'تم منح صلاحية الوصول للمدرسة.',
      'notification.school_admin.student_enrolled.title': 'تسجيل طالب',
      'notification.school_admin.student_enrolled.detail':
          'تم تسجيل طالب جديد.',
      'notification.school_admin.student_transferred.title': 'نقل طالب',
      'notification.school_admin.student_transferred.detail':
          'تم نقل طالب بين الفصول.',
      'notification.school_admin.student_withdrawn.title': 'انسحاب طالب',
      'notification.school_admin.student_withdrawn.detail': 'تم سحب طالب.',
      'notification.support_access.approved.title': 'تمت الموافقة على الدعم',
      'notification.support_access.approved.detail':
          'تمت الموافقة على طلب وصول الدعم.',
      'notification.support_access.requested.title': 'طلب وصول للدعم',
      'notification.support_access.requested.detail':
          'تم طلب وصول الدعم الفني.',
      'notification.support_access.revoked.title': 'تم إلغاء وصول الدعم',
      'notification.support_access.revoked.detail':
          'تم إلغاء وصول الدعم الفني.',
      'notification.support_access.started.title': 'بدأت جلسة الدعم',
      'notification.support_access.started.detail': 'بدأت جلسة دعم فني.',
      'notification.generic.title': 'إشعار',
      'notification.generic.detail': 'لديك تحديث جديد.',
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
