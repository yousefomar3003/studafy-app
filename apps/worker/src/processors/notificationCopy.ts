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

export function channelCopy(templateKey: string, locale: string): ChannelCopy {
  const language = locale === "ar" ? "ar" : "en";
  const category = templateKey.split(".")[0] ?? "";
  return copy[language][category] ?? copy[language].generic!;
}

/** Every category exists in both languages; used by the parity test. */
export function channelCopyCategories(): Record<"en" | "ar", string[]> {
  return {
    en: Object.keys(copy.en).sort(),
    ar: Object.keys(copy.ar).sort(),
  };
}
