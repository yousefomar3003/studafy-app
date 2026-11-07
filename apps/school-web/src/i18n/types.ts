import type { PageId } from "../routes";

/** Names of the line icons in `components/Icon.tsx`. */
export type IconName =
  | "book"
  | "clipboard"
  | "exam"
  | "chart"
  | "calendar"
  | "chat"
  | "sparkle"
  | "family"
  | "shield"
  | "globe"
  | "lock"
  | "download"
  | "school"
  | "eye"
  | "link"
  | "file"
  | "heart"
  | "check"
  | "mail"
  | "help";

/** File names under `public/screens/<lang>/`, without `.webp`. */
export type ScreenName =
  | "teacher-1-today"
  | "teacher-2-classes"
  | "teacher-3-lessons"
  | "teacher-4-grade-sheet"
  | "teacher-5-online-exam"
  | "student-3-homework"
  | "student-4-grades"
  | "student-5-exam"
  | "parent-1-today"
  | "parent-2-progress"
  | "parent-3-announcements";

export interface Card {
  icon: IconName;
  title: string;
  text: string;
}

export interface Role {
  key: "teachers" | "students" | "parents";
  tab: string;
  title: string;
  text: string;
  points: string[];
  screen: ScreenName;
  screenAlt: string;
}

export interface Plan {
  name: string;
  who: string;
  text: string;
}

export interface Question {
  q: string;
  a: string;
}

export interface Section {
  eyebrow: string;
  title: string;
  text: string;
}

/**
 * Every word on the public site, in one language. English and Arabic must
 * have the same shape (checked by the type and by `test/copy.test.ts`).
 */
export interface Copy {
  meta: Record<PageId, { title: string; description: string }>;
  nav: {
    skip: string;
    home: string;
    features: string;
    schools: string;
    about: string;
    contact: string;
    getApp: string;
    signIn: string;
    menu: string;
    otherLanguage: string;
    otherLanguageName: string;
  };
  store: {
    appStoreAlt: string;
    playAlt: string;
    soon: string;
  };
  footer: {
    tagline: string;
    product: string;
    company: string;
    legal: string;
    privacy: string;
    terms: string;
    rights: string;
  };
  home: {
    hero: {
      eyebrow: string;
      title: string;
      accent: string;
      text: string;
      secondary: string;
      chips: string[];
      floating: { published: string; attendance: string; homework: string };
      screenAlts: { teacher: string; student: string; parent: string };
    };
    roles: Section & { list: Role[] };
    everyday: Section & { cards: Card[] };
    marks: Section & { points: Card[]; screenAlt: string };
    ai: Section & { cards: (Card & { tag: string })[]; note: string };
    start: Section & { steps: { title: string; text: string }[] };
    bilingual: Section & { enAlt: string; arAlt: string };
    plans: Section & { free: string; list: Plan[]; note: string };
    cta: { title: string; text: string };
  };
  features: {
    hero: Section;
    roles:
      (Role & { more: string[]; screen2: ScreenName; screen2Alt: string })[];
    ai: Section & { cards: (Card & { tag: string })[]; note: string };
    plans: Section & { free: string; list: Plan[]; note: string };
    faq: { title: string; list: Question[] };
  };
  schools: {
    hero: Section & { cta: string; secondary: string };
    steps: { title: string; list: { title: string; text: string }[] };
    sees: Section & { cards: Card[] };
    control: Section & { points: string[] };
    never: Section & { list: string[] };
    faq: { title: string; list: Question[] };
    cta: { title: string; text: string; button: string };
  };
  about: {
    hero: Section;
    mission: { title: string; text: string };
    beliefs: Section & { cards: Card[] };
    how: Section & { cards: Card[] };
    cta: { title: string; text: string; button: string };
  };
  contact: {
    hero: Section;
    cards: (Card & { subject: string })[];
    reply: string;
    legal: string;
  };
  notFound: { title: string; text: string; home: string };
}
