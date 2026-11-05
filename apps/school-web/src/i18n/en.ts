import type { Copy } from "./types";

/**
 * English copy. Every claim about the app comes from the store listing
 * (`docs/store/listing-copy.md`): only what the code does, no "best" or
 * "#1", no prices, no competitor names.
 */
export const en: Copy = {
  meta: {
    home: {
      title: "Studafy: lessons, homework, marks and attendance in one app",
      description:
        "Studafy brings lessons, homework, online exams, marks and attendance together for teachers, students and parents, in English and Arabic.",
    },
    features: {
      title: "Features · Studafy",
      description:
        "Everything Studafy does for teachers, students and parents: lessons, homework, online exams, a gradebook, attendance, messages and study help.",
    },
    schools: {
      title: "Studafy School Portal",
      description:
        "A read-only view of your school's classes on Studafy: students, work, marks and attendance, shared by the teachers who choose to link.",
    },
    about: {
      title: "About · Studafy",
      description:
        "Studafy makes the everyday work of a class simpler for teachers, clearer for students and easier to follow for parents.",
    },
    contact: {
      title: "Contact · Studafy",
      description:
        "Questions, schools, privacy or help with the app: write to hello@studafy.com.",
    },
    notFound: {
      title: "Page not found · Studafy",
      description: "This page does not exist.",
    },
  },
  nav: {
    skip: "Skip to content",
    home: "Home",
    features: "Features",
    schools: "For schools",
    about: "About",
    contact: "Contact",
    getApp: "Get the app",
    menu: "Menu",
    otherLanguage: "Arabic",
    otherLanguageName: "العربية",
  },
  store: {
    appStoreAlt: "Download on the App Store",
    playAlt: "Get it on Google Play",
    soon: "Coming soon to the App Store and Google Play",
  },
  footer: {
    tagline: "One app for a class's everyday work.",
    product: "Product",
    company: "Company",
    legal: "Legal",
    privacy: "Privacy Policy",
    terms: "Terms of Use",
    rights: "All rights reserved.",
  },
  home: {
    hero: {
      eyebrow: "For teachers, students and parents",
      title: "The whole class,",
      accent: "in one app.",
      text:
        "Studafy brings lessons, homework, online exams, marks and attendance together, so teachers teach, students know what's next, and parents stay close. In English and Arabic.",
      secondary: "Explore features",
      chips: ["Free at its core", "No ads, ever", "English and العربية"],
      floating: {
        published: "Marks published",
        attendance: "Attendance taken",
        homework: "New homework",
      },
      screenAlts: {
        teacher: "A teacher's Today screen with classes and quick actions",
        student: "A student's homework list",
        parent: "A parent's overview of their child's day",
      },
    },
    roles: {
      eyebrow: "One app, three views",
      title: "Everyone sees what they need.",
      text:
        "Studafy shapes itself around who is signed in, so every screen is relevant and nothing is cluttered.",
      list: [
        {
          key: "teachers",
          tab: "Teachers",
          title: "Run your classes without the paperwork.",
          text:
            "Create a class in moments, share lessons, set homework and keep every mark in one gradebook.",
          points: [
            "Invite students with a class code or link",
            "Online exams that mark set answers for you",
            "Marks stay private until you publish them",
            "Attendance in a few taps",
          ],
          screen: "teacher-4-grade-sheet",
          screenAlt: "A teacher's grade sheet for a class",
        },
        {
          key: "students",
          tab: "Students",
          title: "Know what's due, and how you're doing.",
          text:
            "Lessons by date, homework with a clear due date, exams on your phone and every published mark in one place.",
          points: [
            "Hand in typed answers, photos or documents",
            "Take online exams on your phone",
            "See feedback as soon as it's published",
            "Study help with the AI Tutor",
          ],
          screen: "student-3-homework",
          screenAlt: "A student's homework list with due dates",
        },
        {
          key: "parents",
          tab: "Parents",
          title: "Follow your child's progress, calmly.",
          text:
            "See published marks, homework and attendance, read announcements and message teachers when it matters.",
          points: [
            "Link with your child's Studafy ID",
            "Your child approves every link",
            "Accounts for younger children without email",
            "Family+ for a deeper weekly view",
          ],
          screen: "parent-2-progress",
          screenAlt: "A parent's view of their child's progress",
        },
      ],
    },
    everyday: {
      eyebrow: "Everything in one place",
      title: "Built for the everyday work of a class.",
      text:
        "The tools a class uses every day, designed to work together instead of living in five different apps.",
      cards: [
        {
          icon: "book",
          title: "Lessons",
          text:
            "Notes, files and links, organised by date. PDF, Word, PowerPoint and images open right in the app.",
        },
        {
          icon: "clipboard",
          title: "Homework",
          text:
            "Due dates, hand-ins as text, photos or documents, extra time when someone needs it.",
        },
        {
          icon: "exam",
          title: "Online exams",
          text:
            "Single and multiple answer, true or false, short answer and essay. Set answers mark themselves.",
        },
        {
          icon: "chart",
          title: "Gradebook",
          text:
            "Paper tests and online work in one place, published only when the teacher is ready.",
        },
        {
          icon: "calendar",
          title: "Attendance",
          text: "Present, absent, late or excused, recorded for every lesson.",
        },
        {
          icon: "chat",
          title: "Messages",
          text:
            "Announcements to a class and conversations between teachers, students and parents.",
        },
      ],
    },
    marks: {
      eyebrow: "Trust built in",
      title: "Marks belong to the teacher until they're ready.",
      text:
        "Students and families see a mark only after it's published, and every correction leaves a clear record.",
      points: [
        {
          icon: "lock",
          title: "Private until published",
          text: "Draft marks are visible only to the teacher.",
        },
        {
          icon: "file",
          title: "Every change on record",
          text: "A corrected mark keeps the change and the reason.",
        },
        {
          icon: "check",
          title: "The teacher decides",
          text: "AI can suggest a mark. Only the teacher can give one.",
        },
      ],
      screenAlt: "A student's published marks with teacher feedback",
    },
    ai: {
      eyebrow: "Study help",
      title: "AI that helps, and knows its place.",
      text:
        "Useful where it saves time, careful with what it sees, and never in charge.",
      cards: [
        {
          icon: "sparkle",
          tag: "For students",
          title: "AI Tutor",
          text:
            "Ask about your lessons and your own notes, turn a lesson or a photo of the board into study notes, and practise with quizzes and flashcards.",
        },
        {
          icon: "check",
          tag: "For teachers",
          title: "Studafy AI Marking",
          text:
            "Suggested marks for written answers and hand-ins, checked against your own model answer. You review, adjust and decide every mark.",
        },
      ],
      note:
        "AI answers can be wrong, so check them. Email addresses and marks are never sent to the AI service, and names are replaced first.",
    },
    privacy: {
      eyebrow: "Privacy",
      title: "Private by design.",
      text: "A class's work is personal. We treat it that way.",
      cards: [
        {
          icon: "shield",
          title: "No ads. No selling data.",
          text: "Studafy is paid for by optional plans, never by advertising.",
        },
        {
          icon: "lock",
          title: "Stored in Frankfurt",
          text: "Your data is stored in Frankfurt, Germany.",
        },
        {
          icon: "download",
          title: "Yours to take or delete",
          text:
            "Download a copy of your data or delete your account from inside the app.",
        },
        {
          icon: "family",
          title: "Children come first",
          text:
            "Students approve every parent link, and parents can create accounts for younger children.",
        },
      ],
    },
    bilingual: {
      eyebrow: "English and العربية",
      title: "Truly bilingual.",
      text:
        "Every screen works in English and in Arabic, with a right-to-left layout written for Arabic readers, not machine-translated. Switch at any time.",
      enAlt: "Studafy's grade sheet in English",
      arAlt: "Studafy's grade sheet in Arabic",
    },
    plans: {
      eyebrow: "Plans",
      title: "Free at its core.",
      text:
        "Everything a class needs to run is free. Optional subscriptions add more for the people who want it.",
      free:
        "Lessons, homework, online exams, marks, attendance and messages are free for everyone.",
      list: [
        {
          name: "Studafy Plus",
          who: "Students",
          text:
            "Photos in questions, study notes from lessons and photos, notebooks with highlights.",
        },
        {
          name: "Studafy Max",
          who: "Students",
          text:
            "Everything in Plus, with quizzes and flashcards made from your lessons and notes.",
        },
        {
          name: "Family+",
          who: "Parents",
          text:
            "What to focus on this week, marks over time, missing work and missed tests.",
        },
        {
          name: "Studafy AI Marking",
          who: "Teachers",
          text:
            "Suggested marks for written work, against your own model answer.",
        },
      ],
      note:
        "Prices are shown in the App Store and Google Play. Cancel at any time.",
    },
    cta: {
      title: "Bring your class to Studafy.",
      text:
        "Download the app, create a class and invite your students with a code.",
    },
  },
  features: {
    hero: {
      eyebrow: "Features",
      title: "Everything Studafy does.",
      text: "One app for the whole class. Here is what each person gets.",
    },
    roles: [
      {
        key: "teachers",
        tab: "Teachers",
        title: "For teachers",
        text:
          "Everything you need to run a class, from the first lesson to the final mark.",
        points: [
          "Create classes, set the timetable and invite students with a class code or link",
          "Share lessons with notes, files (PDF, Word, PowerPoint and images) and links",
          "Set homework with a due date, see who has handed in, and give extra time",
          "Build online exams with single-answer, multiple-answer, true or false, short-answer and essay questions",
        ],
        more: [
          "Questions with a set answer are marked automatically; you mark the rest",
          "Choose when students see the correct answers",
          "One gradebook for paper tests and online work, private until you publish",
          "Attendance, wellbeing notes, announcements and messages",
        ],
        screen: "teacher-5-online-exam",
        screenAlt: "Building an online exam",
        screen2: "teacher-3-lessons",
        screen2Alt: "A class's lessons by date",
      },
      {
        key: "students",
        tab: "Students",
        title: "For students",
        text:
          "Your classes, your work and your marks, with study help when you want it.",
        points: [
          "Join a class with a code from your teacher, or start on your own",
          "Read lessons by date and keep your own notes",
          "Hand in homework as typed answers, photos or documents",
          "Take online exams on your phone",
        ],
        more: [
          "See published marks, your teacher's feedback and your attendance",
          "Message your teachers",
          "Ask the AI Tutor about your lessons and notes",
          "Quizzes and flashcards made from your lessons (Studafy Max)",
        ],
        screen: "student-5-exam",
        screenAlt: "A student taking an online exam",
        screen2: "student-4-grades",
        screen2Alt: "A student's published marks",
      },
      {
        key: "parents",
        tab: "Parents",
        title: "For parents",
        text:
          "Stay close to your child's school day without chasing anyone for updates.",
        points: [
          "Link to your child with their Studafy ID; your child approves on their own device",
          "Follow published marks, homework and attendance",
          "Read class announcements and message teachers",
          "Create an account for a younger child who has no email, and switch between accounts on one phone",
        ],
        more: [
          "Family+: what to focus on this week",
          "Family+: marks over time and each class at a glance",
          "Family+: missing work and missed tests",
        ],
        screen: "parent-1-today",
        screenAlt: "A parent's Today screen",
        screen2: "parent-3-announcements",
        screen2Alt: "Class announcements for parents",
      },
    ],
    ai: {
      eyebrow: "Study help",
      title: "AI, with the teacher in charge.",
      text: "Optional, clearly labelled, and careful with personal data.",
      cards: [
        {
          icon: "sparkle",
          tag: "Students · Studafy Plus and Max",
          title: "AI Tutor",
          text:
            "Ask about your lessons and your own notes, in a class or on your own. Plus adds photos in questions, study notes and notebooks with highlights and bookmarks. Max adds quizzes and flashcards.",
        },
        {
          icon: "check",
          tag: "Teachers · Studafy AI Marking",
          title: "Suggested marks",
          text:
            "AI suggests marks for written answers and hand-ins against your own model answer. Only teachers see suggestions, and you decide every mark.",
        },
      ],
      note:
        "AI answers can be wrong, so check them. Email addresses and marks are never sent to the AI service, and names are replaced first.",
    },
    plans: {
      eyebrow: "Plans",
      title: "Free at its core.",
      text:
        "Optional monthly subscriptions, bought in the app, renew until you cancel.",
      free:
        "Lessons, homework, online exams, marks, attendance and messages are free.",
      list: [
        {
          name: "Studafy Plus",
          who: "Students",
          text:
            "Photos in questions, study notes from a lesson or a photo, notebooks with highlights and bookmarks.",
        },
        {
          name: "Studafy Max",
          who: "Students",
          text:
            "Everything in Plus, with quizzes and flashcards made from your lessons and notes.",
        },
        {
          name: "Family+",
          who: "Parents",
          text:
            "What to focus on this week, marks over time, each class at a glance, missing work and missed tests.",
        },
        {
          name: "Studafy AI Marking",
          who: "Teachers",
          text:
            "Suggested marks for written answers and hand-ins, against your own model answer.",
        },
      ],
      note: "Prices are shown in the App Store and Google Play.",
    },
    faq: {
      title: "Questions",
      list: [
        {
          q: "Is Studafy free?",
          a: "Yes. Lessons, homework, online exams, marks, attendance and messages are free. Studafy Plus, Studafy Max, Family+ and Studafy AI Marking are optional subscriptions.",
        },
        {
          q: "Which languages does it support?",
          a: "English and Arabic, across the whole app, with a right-to-left layout in Arabic. You can switch at any time.",
        },
        {
          q: "Can a student use Studafy without a class?",
          a: "Yes. A student can start on their own with the AI Tutor and their own notes, and join a class later with a code.",
        },
        {
          q: "How does a parent link to their child?",
          a: "The parent enters the child's Studafy ID, and the child approves the request on their own device.",
        },
        {
          q: "Which devices does it work on?",
          a: "iPhone and Android phones.",
        },
        {
          q: "Where is my data stored?",
          a: "In Frankfurt, Germany. We never show ads and never sell your data. You can download or delete it from inside the app.",
        },
      ],
    },
  },
  schools: {
    hero: {
      eyebrow: "Studafy School Portal",
      title: "See your school's classes in one place.",
      text:
        "A read-only view, on the web, of the classes your teachers run on Studafy: students, lessons, work, marks and attendance.",
      cta: "Open the School Portal",
      secondary: "How it works",
    },
    steps: {
      title: "How it works",
      list: [
        {
          title: "Create your school's page",
          text:
            "Sign in with Apple, Google or Microsoft and add your school's details.",
        },
        {
          title: "Ask your teachers to link",
          text:
            "Enter a teacher's Studafy ID. The teacher accepts the request in the app.",
        },
        {
          title: "See every linked class",
          text:
            "Classes, students, work, marks and attendance, always up to date.",
        },
      ],
    },
    sees: {
      eyebrow: "What you can see",
      title: "The whole picture, read-only.",
      text:
        "Once a teacher accepts, every one of their classes appears in the portal.",
      cards: [
        {
          icon: "school",
          title: "Classes and students",
          text:
            "Every student, with their email and Studafy ID, and the parents linked to them.",
        },
        {
          icon: "book",
          title: "Lessons and files",
          text:
            "What each teacher has shared with their classes, and class announcements.",
        },
        {
          icon: "clipboard",
          title: "Homework and exams",
          text: "Hand-ins and exam answers, opened securely.",
        },
        {
          icon: "chart",
          title: "Marks",
          text: "Every mark, including those not yet published.",
        },
        {
          icon: "calendar",
          title: "Attendance",
          text: "Each student's record, day by day.",
        },
        {
          icon: "heart",
          title: "Wellbeing notes",
          text: "Teachers' notes on students' strengths and concerns.",
        },
      ],
    },
    control: {
      eyebrow: "Teachers decide",
      title: "Nothing is visible until a teacher accepts.",
      text:
        "Linking works like a parent linking to a student: one side asks, the other approves.",
      points: [
        "The teacher sees who is asking and exactly what the school will see",
        "A teacher can unlink at any time, and the school stops seeing their classes at once",
        "The portal is read-only: it can never change a mark, a class or a record",
        "Every page an administrator opens is recorded",
      ],
    },
    never: {
      eyebrow: "Never shown",
      title: "Some things stay private.",
      text: "The portal never shows:",
      list: [
        "Messages between teachers, students and parents",
        "Students' AI Tutor conversations",
        "Students' own notebooks, notes, flashcards and quizzes",
      ],
    },
    faq: {
      title: "Questions",
      list: [
        {
          q: "Can the school change marks?",
          a: "No. The portal is read-only.",
        },
        {
          q: "Can the school read messages?",
          a: "No. Messages are never shown in the portal.",
        },
        {
          q: "What if a teacher leaves the school?",
          a: "They unlink in the app, and the school stops seeing their classes at once.",
        },
        {
          q: "Which accounts can I sign in with?",
          a: "Apple, Google or Microsoft, including Outlook, Hotmail and Microsoft 365 school accounts.",
        },
        {
          q: "Do students or parents need to do anything?",
          a: "No. They keep using the Studafy app as they do now.",
        },
        { q: "How many administrators can a school have?", a: "Up to three." },
      ],
    },
    cta: {
      title: "Bring your school together.",
      text: "Create your school's page and invite your teachers to link.",
      button: "Open the School Portal",
    },
  },
  about: {
    hero: {
      eyebrow: "About Studafy",
      title: "Making the everyday work of a class simple.",
      text:
        "Studafy is one app for teachers, students and parents, built in English and Arabic.",
    },
    mission: {
      title: "Our mission",
      text:
        "We make the everyday work of a class simpler for teachers, clearer for students and easier to follow for parents. A class has a lot to keep track of: lessons, homework, exams, marks and attendance. We bring it into one calm, dependable place, so everyone can spend less time on admin and more time on learning.",
    },
    beliefs: {
      eyebrow: "What we believe",
      title: "Principles we build by.",
      text: "Each of these is a promise the app already keeps.",
      cards: [
        {
          icon: "check",
          title: "Teachers decide",
          text:
            "Marks stay private until a teacher publishes them, and AI only ever suggests.",
        },
        {
          icon: "shield",
          title: "Privacy first",
          text:
            "No ads, no selling data, and only what's needed to make the app work.",
        },
        {
          icon: "globe",
          title: "Two languages, done properly",
          text:
            "English and Arabic, written by people, with a real right-to-left layout.",
        },
        {
          icon: "heart",
          title: "Free where it matters",
          text:
            "Lessons, homework, marks and attendance are free for every class.",
        },
      ],
    },
    how: {
      eyebrow: "How we work",
      title: "Built to be trusted.",
      text: "A class's work deserves the same care as any other personal data.",
      cards: [
        {
          icon: "lock",
          title: "Secure by default",
          text:
            "Every request is checked on our servers, every file is scanned, and data is stored in Frankfurt, Germany.",
        },
        {
          icon: "family",
          title: "Families in control",
          text:
            "Students approve parent links, and anyone can download or delete their data from inside the app.",
        },
        {
          icon: "sparkle",
          title: "Careful with AI",
          text:
            "Email addresses and marks never reach the AI service, names are replaced first, and its answers are always labelled.",
        },
      ],
    },
    cta: {
      title: "Talk to us.",
      text:
        "Questions, ideas or a school that wants to join: we'd love to hear from you.",
      button: "Contact us",
    },
  },
  contact: {
    hero: {
      eyebrow: "Contact",
      title: "Get in touch.",
      text:
        "We read every message. Write to us at hello@studafy.com, or pick a topic below.",
    },
    cards: [
      {
        icon: "help",
        title: "Help with the app",
        text: "Something not working, or not sure how to do something?",
        subject: "Help with the app",
      },
      {
        icon: "school",
        title: "Schools",
        text: "Bringing Studafy to your school or your teachers.",
        subject: "Studafy for my school",
      },
      {
        icon: "shield",
        title: "Privacy",
        text: "Questions about your data, or a privacy request.",
        subject: "Privacy request",
      },
      {
        icon: "mail",
        title: "Everything else",
        text: "Partnerships, press and anything else.",
        subject: "Hello Studafy",
      },
    ],
    reply: "We aim to reply within two working days.",
    legal: "How we handle your data:",
  },
  notFound: {
    title: "This page doesn't exist.",
    text: "The link may be old, or the address may have a typo.",
    home: "Back to the home page",
  },
};
