/**
 * The synthetic school the store screenshots show (launch plan A4), in
 * English and in Arabic. Every name is fictional. Weekdays are ISO
 * (1 = Monday ... 7 = Sunday); the school week is Sunday to Thursday, as in
 * Jordan. Student indexes refer to `students`; index 0 is the student whose
 * screens are captured, and the parent is linked to them.
 */
type Gender = "male" | "female";
type Slot = [weekday: number, startsAt: string, endsAt: string];

export interface Question {
  prompt: string;
  kind:
    | "single_choice"
    | "multiple_choice"
    | "true_false"
    | "short_answer"
    | "essay";
  maximumScore: number;
  preferredAnswer: string | null;
  options?: { id: string; text: string }[];
  correctOptionIds?: string[] | null;
  correctChoice?: boolean | null;
  acceptedAnswers?: string[] | null;
  markingGuidance?: string | null;
}

export interface SchoolContent {
  school: string;
  teacher: { name: string; gender: Gender };
  parent: { name: string; gender: Gender; relationship: string };
  students: { name: string; gender: Gender }[];
  classes: {
    key: string;
    name: string;
    grade: string;
    section: string;
    room: string | null;
    schedule: Slot[];
    students: number[];
    attendance: boolean;
  }[];
  lessons: {
    classKey: string;
    title: string;
    body: string;
    links?: { title: string; url: string }[];
  }[];
  homework: {
    classKey: string;
    title: string;
    instructions: string;
    dueInDays: number;
    handedInBy: number[];
  }[];
  exam: {
    classKey: string;
    title: string;
    category: string;
    questions: Question[];
  };
  paperTests: {
    classKey: string;
    title: string;
    category: string;
    maximumScore: number;
    weight: number | null;
    daysAgo: number;
    /** By student index. */
    scores: number[];
    /** For the main student. */
    feedback: string | null;
  }[];
  handInText: string;
  attendanceReason: string;
  wellbeing: { title: string; context: string };
  announcements: {
    classKey: string;
    title: string;
    body: string;
    important: boolean;
  }[];
  conversation: ["teacher" | "parent", string][];
  note: { title: string; body: string };
}

const all = [0, 1, 2, 3, 4, 5, 6, 7];
const mathsSlots: Slot[] = [[7, "08:00", "08:45"], [2, "08:00", "08:45"], [
  4,
  "09:00",
  "09:45",
]];
const scienceSlots: Slot[] = [[1, "08:50", "09:35"], [3, "08:50", "09:35"], [
  4,
  "11:00",
  "11:45",
]];
const clubSlots: Slot[] = [[2, "13:30", "14:15"]];

const en: SchoolContent = {
  school: "Hillcrest School",
  teacher: { name: "Hannah Clarke", gender: "female" },
  parent: { name: "Rania Haddad", gender: "female", relationship: "Mother" },
  students: [
    { name: "Omar Haddad", gender: "male" },
    { name: "Mia Torres", gender: "female" },
    { name: "Yusuf Rahman", gender: "male" },
    { name: "Grace Lin", gender: "female" },
    { name: "Adam Novak", gender: "male" },
    { name: "Lina Saleh", gender: "female" },
    { name: "Noah Brooks", gender: "male" },
    { name: "Zara Malik", gender: "female" },
  ],
  classes: [
    {
      key: "maths",
      name: "Mathematics",
      grade: "8",
      section: "A",
      room: "Room 204",
      schedule: mathsSlots,
      students: all,
      attendance: true,
    },
    {
      key: "science",
      name: "Science",
      grade: "8",
      section: "A",
      room: "Lab 2",
      schedule: scienceSlots,
      students: all,
      attendance: true,
    },
    {
      key: "club",
      name: "Algebra Club",
      grade: "8",
      section: "A",
      room: "Library",
      schedule: clubSlots,
      students: [0, 2, 5],
      attendance: false,
    },
  ],
  lessons: [
    {
      classKey: "science",
      title: "States of matter",
      body:
        "Solids, liquids and gases are made of particles that move differently.\n\n• Solid: particles vibrate in fixed positions\n• Liquid: particles slide past each other\n• Gas: particles move freely and fill their container",
    },
    {
      classKey: "maths",
      title: "Solving two-step equations",
      body:
        "A two-step equation needs two inverse operations.\n\nExample: 3x + 5 = 20\nSubtract 5 from both sides: 3x = 15\nDivide both sides by 3: x = 5\n\nUndo addition or subtraction first, then multiplication or division.",
    },
    {
      classKey: "maths",
      title: "Equations with variables on both sides",
      body:
        "Collect the x terms on one side and the numbers on the other.\n\nExample: 5x + 3 = 2x + 12\n5x − 2x = 12 − 3\n3x = 9\nx = 3\n\nAlways check your answer by substituting it back into the original equation.",
      links: [{
        title: "Practice set",
        url: "https://example.com/maths/equations-practice",
      }],
    },
    {
      classKey: "science",
      title: "Changes of state",
      body:
        "Melting, freezing, evaporating, condensing and sublimating. At each change, energy is taken in or given out.",
    },
    {
      classKey: "maths",
      title: "Introduction to inequalities",
      body:
        "An inequality compares two values using <, >, ≤ or ≥.\n\nToday we will:\n• read and write inequalities\n• show solutions on a number line\n• solve one-step inequalities\n\nRemember: when you multiply or divide both sides by a negative number, flip the inequality sign.",
    },
  ],
  homework: [
    {
      classKey: "maths",
      title: "Number line practice",
      instructions:
        "Draw each inequality on a number line. Use open and closed circles correctly.",
      dueInDays: 1,
      handedInBy: [0, 1, 2, 3, 4, 5, 6],
    },
    {
      classKey: "maths",
      title: "Worksheet: two-step equations",
      instructions:
        "Complete questions 1–12 on the worksheet. Show every step of your working. You can type your answers or hand in a photo of your page.",
      dueInDays: 2,
      handedInBy: [1, 2, 3, 4],
    },
    {
      classKey: "science",
      title: "Lab report: melting ice",
      instructions:
        "Write up yesterday's experiment: aim, method, results table and conclusion. Add a photo of your graph.",
      dueInDays: 4,
      handedInBy: [2, 5],
    },
    {
      classKey: "maths",
      title: "Word problems: equations in real life",
      instructions:
        "Write and solve an equation for each of the five problems. Explain what your variable stands for.",
      dueInDays: 6,
      handedInBy: [1],
    },
  ],
  exam: {
    classKey: "maths",
    title: "Unit 3 quiz: linear equations",
    category: "Quiz",
    questions: [
      {
        prompt: "Solve 3x + 5 = 20. What is x?",
        kind: "single_choice",
        maximumScore: 2,
        preferredAnswer: null,
        options: [
          { id: "a", text: "x = 3" },
          { id: "b", text: "x = 5" },
          { id: "c", text: "x = 8" },
          { id: "d", text: "x = 15" },
        ],
        correctOptionIds: ["b"],
      },
      {
        prompt: "x = −2 is a solution of 2x + 4 = 0.",
        kind: "true_false",
        maximumScore: 1,
        preferredAnswer: null,
        correctChoice: true,
      },
      {
        prompt:
          "Which equations have x = 4 as a solution? Choose all that apply.",
        kind: "multiple_choice",
        maximumScore: 2,
        preferredAnswer: null,
        options: [
          { id: "a", text: "x + 3 = 7" },
          { id: "b", text: "2x = 6" },
          { id: "c", text: "5x − 4 = 16" },
          { id: "d", text: "x ÷ 2 = 3" },
        ],
        correctOptionIds: ["a", "c"],
      },
      {
        prompt: "Solve 4(x − 1) = 12.",
        kind: "short_answer",
        maximumScore: 2,
        preferredAnswer: "x = 4",
        acceptedAnswers: ["4", "x = 4", "x=4"],
      },
      {
        prompt: "Explain, step by step, how you would solve 7x − 2 = 3x + 10.",
        kind: "essay",
        maximumScore: 3,
        preferredAnswer:
          "Subtract 3x from both sides, add 2 to both sides, then divide by 4: x = 3.",
        markingGuidance:
          "1 mark for collecting the x terms, 1 for the numbers, 1 for x = 3 with a check.",
      },
    ],
  },
  paperTests: [
    {
      classKey: "maths",
      title: "Unit 2 test: fractions and decimals",
      category: "Test",
      maximumScore: 40,
      weight: 20,
      daysAgo: 9,
      scores: [34, 29, 37, 31, 25, 38, 33, 28],
      feedback:
        "Strong work on decimals. Review dividing fractions before the next unit.",
    },
    {
      classKey: "science",
      title: "Particles quiz",
      category: "Quiz",
      maximumScore: 20,
      weight: 10,
      daysAgo: 6,
      scores: [17, 15, 19, 12, 16, 18, 14, 13],
      feedback: "Excellent diagrams. Remember to label the particles.",
    },
    {
      classKey: "maths",
      title: "Mental maths check",
      category: "Quiz",
      maximumScore: 10,
      weight: 5,
      daysAgo: 4,
      scores: [9, 7, 8, 10, 6, 9, 8, 7],
      feedback: null,
    },
  ],
  handInText:
    "My working is in the photo. Answers: 1) x = 5  2) x = 7  3) x = −2 …",
  attendanceReason: "Copied from the paper register",
  wellbeing: {
    title: "Helped a classmate with equations",
    context:
      "Omar explained his method to a classmate during group work, clearly and patiently. A great example for the class.",
  },
  announcements: [
    {
      classKey: "club",
      title: "Algebra Club starts on Tuesday",
      body:
        "Algebra Club meets every Tuesday at 13:30 in the library. Everyone in Grade 8 is welcome; bring a pencil and a calculator.",
      important: false,
    },
    {
      classKey: "science",
      title: "Science fair: projects due 12 November",
      body:
        "Choose your topic by next Thursday. Projects can be done alone or in pairs. The guidelines are in this week's lesson.",
      important: true,
    },
  ],
  conversation: [
    [
      "parent",
      "Hello Ms Clarke, Omar was unwell on Sunday. Is there anything he should catch up on?",
    ],
    [
      "teacher",
      "Hello Mrs Haddad, thank you for letting me know. The lesson notes are in the app, and the worksheet is due on Saturday. He is welcome to ask me in class.",
    ],
    ["parent", "Thank you, we will go through the notes together tonight."],
  ],
  note: {
    title: "Inequalities: my summary",
    body:
      "Flip the sign when multiplying or dividing by a negative!\nOpen circle = < or >, closed circle = ≤ or ≥.",
  },
};

const ar: SchoolContent = {
  school: "مدرسة التلال",
  teacher: { name: "هبة الخطيب", gender: "female" },
  parent: { name: "رنا حداد", gender: "female", relationship: "الأم" },
  students: [
    { name: "عمر حداد", gender: "male" },
    { name: "سارة يوسف", gender: "female" },
    { name: "كريم منصور", gender: "male" },
    { name: "ليان ناصر", gender: "female" },
    { name: "يزن حمدان", gender: "male" },
    { name: "مريم سليمان", gender: "female" },
    { name: "آدم سمير", gender: "male" },
    { name: "جود عيسى", gender: "female" },
  ],
  classes: [
    {
      key: "maths",
      name: "الرياضيات",
      grade: "الثامن",
      section: "أ",
      room: "غرفة 204",
      schedule: mathsSlots,
      students: all,
      attendance: true,
    },
    {
      key: "science",
      name: "العلوم",
      grade: "الثامن",
      section: "أ",
      room: "المختبر 2",
      schedule: scienceSlots,
      students: all,
      attendance: true,
    },
    {
      key: "club",
      name: "نادي الجبر",
      grade: "الثامن",
      section: "أ",
      room: "المكتبة",
      schedule: clubSlots,
      students: [0, 2, 5],
      attendance: false,
    },
  ],
  lessons: [
    {
      classKey: "science",
      title: "حالات المادة",
      body:
        "تتكوّن المواد الصلبة والسائلة والغازية من جسيمات تتحرك بطرق مختلفة.\n\n• الصلب: تهتز الجسيمات في أماكن ثابتة\n• السائل: تنزلق الجسيمات بعضها فوق بعض\n• الغاز: تتحرك الجسيمات بحرية وتملأ الوعاء",
    },
    {
      classKey: "maths",
      title: "حل المعادلات ذات الخطوتين",
      body:
        "المعادلة ذات الخطوتين تحتاج إلى عمليتين عكسيتين.\n\nمثال: ٣س + ٥ = ٢٠\nنطرح ٥ من الطرفين: ٣س = ١٥\nنقسم الطرفين على ٣: س = ٥\n\nنبدأ بعكس الجمع أو الطرح، ثم الضرب أو القسمة.",
    },
    {
      classKey: "maths",
      title: "معادلات فيها المتغير في الطرفين",
      body:
        "نجمع حدود س في طرف والأعداد في الطرف الآخر.\n\nمثال: ٥س + ٣ = ٢س + ١٢\n٥س − ٢س = ١٢ − ٣\n٣س = ٩\nس = ٣\n\nتحقّق دائمًا من الحل بالتعويض في المعادلة الأصلية.",
      links: [{
        title: "تمارين إضافية",
        url: "https://example.com/maths/equations-practice",
      }],
    },
    {
      classKey: "science",
      title: "تحولات حالة المادة",
      body:
        "الانصهار والتجمد والتبخر والتكاثف والتسامي. في كل تحوّل تُمتصّ طاقة أو تنطلق.",
    },
    {
      classKey: "maths",
      title: "مقدمة في المتباينات",
      body:
        "المتباينة تقارن بين قيمتين باستخدام الرموز < أو > أو ≤ أو ≥.\n\nسنتعلم اليوم:\n• قراءة المتباينات وكتابتها\n• تمثيل الحلول على خط الأعداد\n• حل المتباينات ذات الخطوة الواحدة\n\nتذكّر: عند الضرب أو القسمة على عدد سالب نعكس إشارة المتباينة.",
    },
  ],
  homework: [
    {
      classKey: "maths",
      title: "تدريب على خط الأعداد",
      instructions:
        "مثّل كل متباينة على خط الأعداد، واستخدم الدائرة المفتوحة والمغلقة بشكل صحيح.",
      dueInDays: 1,
      handedInBy: [0, 1, 2, 3, 4, 5, 6],
    },
    {
      classKey: "maths",
      title: "ورقة عمل: معادلات ذات خطوتين",
      instructions:
        "حلّ الأسئلة من ١ إلى ١٢ في ورقة العمل، واكتب خطوات الحل كاملة. يمكنك كتابة الإجابات أو تسليم صورة لصفحتك.",
      dueInDays: 2,
      handedInBy: [1, 2, 3, 4],
    },
    {
      classKey: "science",
      title: "تقرير المختبر: انصهار الجليد",
      instructions:
        "اكتب تقرير تجربة الأمس: الهدف وطريقة العمل وجدول النتائج والاستنتاج، وأرفق صورة للرسم البياني.",
      dueInDays: 4,
      handedInBy: [2, 5],
    },
    {
      classKey: "maths",
      title: "مسائل كلامية: المعادلات في حياتنا",
      instructions:
        "اكتب معادلة لكل مسألة من المسائل الخمس وحلّها، ووضّح ماذا يمثّل المتغير.",
      dueInDays: 6,
      handedInBy: [1],
    },
  ],
  exam: {
    classKey: "maths",
    title: "اختبار الوحدة الثالثة: المعادلات الخطية",
    category: "اختبار قصير",
    questions: [
      {
        prompt: "حلّ المعادلة ٣س + ٥ = ٢٠. ما قيمة س؟",
        kind: "single_choice",
        maximumScore: 2,
        preferredAnswer: null,
        options: [
          { id: "a", text: "س = ٣" },
          { id: "b", text: "س = ٥" },
          { id: "c", text: "س = ٨" },
          { id: "d", text: "س = ١٥" },
        ],
        correctOptionIds: ["b"],
      },
      {
        prompt: "س = −٢ حلٌّ للمعادلة ٢س + ٤ = ٠.",
        kind: "true_false",
        maximumScore: 1,
        preferredAnswer: null,
        correctChoice: true,
      },
      {
        prompt: "أيّ المعادلات التالية حلّها س = ٤؟ اختر كل الإجابات الصحيحة.",
        kind: "multiple_choice",
        maximumScore: 2,
        preferredAnswer: null,
        options: [
          { id: "a", text: "س + ٣ = ٧" },
          { id: "b", text: "٢س = ٦" },
          { id: "c", text: "٥س − ٤ = ١٦" },
          { id: "d", text: "س ÷ ٢ = ٣" },
        ],
        correctOptionIds: ["a", "c"],
      },
      {
        prompt: "حلّ المعادلة ٤(س − ١) = ١٢.",
        kind: "short_answer",
        maximumScore: 2,
        preferredAnswer: "س = ٤",
        acceptedAnswers: ["٤", "4", "س = ٤", "س=٤"],
      },
      {
        prompt: "اشرح خطوة بخطوة كيف تحلّ المعادلة ٧س − ٢ = ٣س + ١٠.",
        kind: "essay",
        maximumScore: 3,
        preferredAnswer:
          "نطرح ٣س من الطرفين، ثم نضيف ٢ إلى الطرفين، ثم نقسم على ٤: س = ٣.",
        markingGuidance:
          "درجة لجمع حدود س، ودرجة للأعداد، ودرجة للحل س = ٣ مع التحقق.",
      },
    ],
  },
  paperTests: [
    {
      classKey: "maths",
      title: "اختبار الوحدة الثانية: الكسور والأعداد العشرية",
      category: "اختبار",
      maximumScore: 40,
      weight: 20,
      daysAgo: 9,
      scores: [34, 29, 37, 31, 25, 38, 33, 28],
      feedback:
        "عمل ممتاز في الأعداد العشرية. راجع قسمة الكسور قبل الوحدة القادمة.",
    },
    {
      classKey: "science",
      title: "اختبار الجسيمات",
      category: "اختبار قصير",
      maximumScore: 20,
      weight: 10,
      daysAgo: 6,
      scores: [17, 15, 19, 12, 16, 18, 14, 13],
      feedback: "رسومات ممتازة. لا تنسَ تسمية الجسيمات.",
    },
    {
      classKey: "maths",
      title: "اختبار الحساب الذهني",
      category: "اختبار قصير",
      maximumScore: 10,
      weight: 5,
      daysAgo: 4,
      scores: [9, 7, 8, 10, 6, 9, 8, 7],
      feedback: null,
    },
  ],
  handInText: "خطوات الحل في الصورة. الإجابات: ١) س = ٥  ٢) س = ٧  ٣) س = −٢ …",
  attendanceReason: "منقول من سجل الحضور الورقي",
  wellbeing: {
    title: "ساعد زميله في حل المعادلات",
    context:
      "شرح عمر طريقته لزميله أثناء العمل الجماعي بوضوح وصبر. مثال رائع للصف.",
  },
  announcements: [
    {
      classKey: "club",
      title: "نادي الجبر يبدأ يوم الثلاثاء",
      body:
        "يجتمع نادي الجبر كل ثلاثاء الساعة 13:30 في المكتبة. الدعوة مفتوحة لجميع طلاب الصف الثامن، أحضروا قلمًا وآلة حاسبة.",
      important: false,
    },
    {
      classKey: "science",
      title: "معرض العلوم: تسليم المشاريع في 12 نوفمبر",
      body:
        "اختر موضوع مشروعك قبل الخميس القادم. يمكن العمل فرديًا أو في مجموعات من طالبين. التعليمات في درس هذا الأسبوع.",
      important: true,
    },
  ],
  conversation: [
    [
      "parent",
      "مرحبًا أستاذة هبة، كان عمر مريضًا يوم الأحد. هل هناك ما يجب أن يعوّضه؟",
    ],
    [
      "teacher",
      "أهلًا أم عمر، شكرًا لإخباري. ملاحظات الدرس موجودة في التطبيق، وموعد تسليم ورقة العمل يوم السبت. ويمكنه أن يسألني في الحصة.",
    ],
    ["parent", "شكرًا جزيلًا، سنراجع الملاحظات معًا الليلة."],
  ],
  note: {
    title: "المتباينات: ملخصي",
    body:
      "نعكس الإشارة عند الضرب أو القسمة على عدد سالب!\nالدائرة المفتوحة = < أو >، والمغلقة = ≤ أو ≥.",
  },
};

export const CONTENT = { en, ar } as const;
