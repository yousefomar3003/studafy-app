/**
 * DL-053 channel copy. Email and push carry only this fixed text, chosen by
 * the notification's category and the recipient's language: never a name,
 * message, grade or other record detail. The app shows the real content
 * after sign-in.
 */
export interface ChannelCopy {
  title: string;
  body: string;
}

const copy: Record<"en" | "ar", Record<string, ChannelCopy>> = {
  en: {
    academic: {
      title: "New school update",
      body: "There is a new update about classwork or grades in Studafy.",
    },
    communications: {
      title: "New message",
      body: "You have a new message in Studafy.",
    },
    family: {
      title: "Family link update",
      body: "There is an update about a family link in Studafy.",
    },
    meetings: {
      title: "Meeting update",
      body: "There is an update about a school meeting in Studafy.",
    },
    billing: {
      title: "Subscription update",
      body: "There is an update about a subscription in Studafy.",
    },
    generic: {
      title: "Studafy",
      body: "You have a new notification in Studafy.",
    },
  },
  ar: {
    academic: {
      title: "تحديث مدرسي جديد",
      body: "يوجد تحديث جديد حول الواجبات أو الدرجات في Studafy.",
    },
    communications: {
      title: "رسالة جديدة",
      body: "لديك رسالة جديدة في Studafy.",
    },
    family: {
      title: "تحديث ربط عائلي",
      body: "يوجد تحديث حول ربط عائلي في Studafy.",
    },
    meetings: {
      title: "تحديث اجتماع",
      body: "يوجد تحديث حول اجتماع مدرسي في Studafy.",
    },
    billing: {
      title: "تحديث الاشتراك",
      body: "يوجد تحديث حول اشتراك في Studafy.",
    },
    generic: {
      title: "Studafy",
      body: "لديك إشعار جديد في Studafy.",
    },
  },
};

/**
 * Copy for particular templates, where the category's text would be too
 * vague to act on. Still fixed text: no plan name, price or amount, and it
 * points to the store for the receipt, which the store sends for every
 * charge.
 */
const templates: Record<"en" | "ar", Record<string, ChannelCopy>> = {
  en: {
    "billing.subscription_active": {
      title: "Subscription active",
      body:
        "Your Studafy subscription is active. Apple or Google Play emails your receipt.",
    },
    "billing.subscription_renewed": {
      title: "Subscription renewed",
      body:
        "Your Studafy subscription renewed. Apple or Google Play emails your receipt.",
    },
    "billing.payment_problem": {
      title: "Payment problem",
      body:
        "Your Studafy subscription could not be renewed. Check your payment method in the App Store or Google Play.",
    },
    "billing.subscription_ended": {
      title: "Subscription ended",
      body:
        "Your Studafy subscription has ended. You can subscribe again in the app.",
    },
    "system.push_test": {
      title: "Test notification",
      body: "Notifications from Studafy are working on this device.",
    },
    // Marks for paper work: which work and which mark are shown only in
    // the app, after sign-in.
    "academic.grades_published": {
      title: "New marks",
      body: "A teacher has published new marks in Studafy.",
    },
    "academic.grades_corrected": {
      title: "A mark was updated",
      body: "A teacher has corrected a published mark in Studafy.",
    },
    // DL-057: the warning a month before an inactive account is deleted.
    "account.inactive_deletion_warning": {
      title: "Your account will be deleted",
      body:
        "Your Studafy account has not been used for nearly two years, so it will be deleted in about a month. Open the app to keep it.",
    },
  },
  ar: {
    "billing.subscription_active": {
      title: "الاشتراك مفعّل",
      body:
        "اشتراكك في Studafy مفعّل. ترسل Apple أو Google Play الإيصال إلى بريدك الإلكتروني.",
    },
    "billing.subscription_renewed": {
      title: "تم تجديد الاشتراك",
      body:
        "تم تجديد اشتراكك في Studafy. ترسل Apple أو Google Play الإيصال إلى بريدك الإلكتروني.",
    },
    "billing.payment_problem": {
      title: "مشكلة في الدفع",
      body:
        "تعذّر تجديد اشتراكك في Studafy. تحقّق من طريقة الدفع في App Store أو Google Play.",
    },
    "billing.subscription_ended": {
      title: "انتهى الاشتراك",
      body: "انتهى اشتراكك في Studafy. يمكنك الاشتراك مرة أخرى من التطبيق.",
    },
    "system.push_test": {
      title: "إشعار تجريبي",
      body: "إشعارات Studafy تعمل على هذا الجهاز.",
    },
    "academic.grades_published": {
      title: "درجات جديدة",
      body: "نشر معلم درجات جديدة في Studafy.",
    },
    "academic.grades_corrected": {
      title: "تم تعديل درجة",
      body: "صحّح معلم درجة منشورة في Studafy.",
    },
    "account.inactive_deletion_warning": {
      title: "سيُحذف حسابك",
      body:
        "لم يُستخدم حسابك في Studafy منذ ما يقارب سنتين، لذلك سيُحذف بعد نحو شهر. افتح التطبيق للإبقاء عليه.",
    },
  },
};

export function channelCopy(templateKey: string, locale: string): ChannelCopy {
  const language = locale === "ar" ? "ar" : "en";
  const category = templateKey.split(".")[0] ?? "";
  return templates[language][templateKey] ?? copy[language][category] ??
    copy[language].generic!;
}

/** Every category exists in both languages; used by the parity test. */
export function channelCopyCategories(): Record<"en" | "ar", string[]> {
  return {
    en: Object.keys(copy.en).sort(),
    ar: Object.keys(copy.ar).sort(),
  };
}

/** Every template-specific copy exists in both languages. */
export function channelCopyTemplates(): Record<"en" | "ar", string[]> {
  return {
    en: Object.keys(templates.en).sort(),
    ar: Object.keys(templates.ar).sort(),
  };
}
