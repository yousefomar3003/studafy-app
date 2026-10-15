import { describe, expect, test } from "bun:test";
import { type KnownName, nameRedactor } from "../src/index";

const people: KnownName[] = [
  { name: "Sara Haddad", kind: "self" },
  { name: "José Martínez", kind: "classmate" },
  { name: "Will Turner", kind: "classmate" },
  { name: "Grace Hopper", kind: "teacher" },
  { name: "Omar Haddad", kind: "parent" },
  { name: "Li Na", kind: "classmate" },
  { name: "مُحَمَّد أحمد الخطيب", kind: "classmate" },
  { name: "فاطمة الزهراء", kind: "self" },
  { name: "عبد الله نور", kind: "teacher" },
  { name: "ليلى سعيد", kind: "parent" },
];

const redact = (text: string) => nameRedactor(people).redact(text);

describe("names are replaced before anything reaches the AI provider", () => {
  test("full names, in any case, become their placeholder", () => {
    expect(redact("My name is Sara Haddad and I sit next to José Martínez."))
      .toBe("My name is [student] and I sit next to [classmate].");
    expect(redact("SARA HADDAD wrote this")).toBe("[student] wrote this");
    expect(redact("Ask Mrs Grace Hopper")).toBe("Ask Mrs [teacher]");
  });

  test("one word of a name is replaced on its own", () => {
    expect(redact("Sara and Omar went home")).toBe(
      "[student] and [parent] went home",
    );
    // The student's own name wins when a family name is shared.
    expect(redact("the Haddad family")).toBe("the [student] family");
  });

  test("accents and their absence match the same name", () => {
    expect(redact("Jose Martinez said so")).toBe("[classmate] said so");
    expect(redact("JOSÉ said so")).toBe("[classmate] said so");
    // A decomposed accent: "i" followed by a combining acute.
    expect(redact("Marti\u0301nez")).toBe("[classmate]");
  });

  test("only whole words: a longer word that contains a name stays", () => {
    expect(redact("Sarah and Saralyn are not Sara")).toBe(
      "Sarah and Saralyn are not [student]",
    );
    expect(redact("Haddadi")).toBe("Haddadi");
  });

  test("a possessive keeps its ending", () => {
    expect(redact("Sara's essay")).toBe("[student]'s essay");
  });

  test("short words are not replaced alone, but a whole short name is", () => {
    // "Li" and "Na" are under three letters: ordinary text keeps them.
    expect(redact("Na is sodium; Li is lithium")).toBe(
      "Na is sodium; Li is lithium",
    );
    expect(redact("I worked with Li Na today")).toBe(
      "I worked with [classmate] today",
    );
  });

  test("a common word that is also a name stays a word", () => {
    expect(redact("Will it rain? You will see.")).toBe(
      "Will it rain? You will see.",
    );
    expect(redact("I have faith and grace")).toBe("I have faith and grace");
    // Capitalised in the middle of a sentence, it is the name.
    expect(redact("I asked Will about it")).toBe(
      "I asked [classmate] about it",
    );
    expect(redact("Then Grace explained it.")).toBe(
      "Then [teacher] explained it.",
    );
    // At the start of a sentence it could be either: left alone.
    expect(redact("It is late. Grace is a virtue.")).toBe(
      "It is late. Grace is a virtue.",
    );
    // The full name is always replaced.
    expect(redact("will turner is here")).toBe("[classmate] is here");
  });

  test("Arabic names match without short vowels and with any alef", () => {
    expect(redact("سأل محمد أحمد الخطيب المعلم")).toBe(
      "سأل [classmate] المعلم",
    );
    expect(redact("قال مُحمّد")).toBe("قال [classmate]");
    expect(redact("قال احمد")).toBe("قال [classmate]");
    expect(redact("كتبت فاطمه الزهراء")).toBe("كتبت [student]");
    expect(redact("كتبت فاطمة")).toBe("كتبت [student]");
  });

  test("a one-letter Arabic prefix stays in front of the placeholder", () => {
    expect(redact("ذهبت مع فاطمة ومحمد")).toBe(
      "ذهبت مع [student] و[classmate]",
    );
    expect(redact("لفاطمة كتاب")).toBe("ل[student] كتاب");
  });

  test("Arabic words that are also names stay words; particles too", () => {
    // نور (light) and سعيد (happy) are names here, and words in lessons.
    expect(redact("الضوء نور والطالب سعيد")).toBe("الضوء نور والطالب سعيد");
    // عبد and الله are never replaced alone.
    expect(redact("بسم الله")).toBe("بسم الله");
    // The full names are.
    expect(redact("درّسنا عبد الله نور")).toBe("درّسنا [teacher]");
    expect(redact("أمي ليلى سعيد")).toBe("أمي [parent]");
    expect(redact("أمي ليلى")).toBe("أمي [parent]");
  });

  test("mixed Arabic and English text", () => {
    expect(redact("Sara قالت إن محمد يعرف")).toBe(
      "[student] قالت إن [classmate] يعرف",
    );
  });

  test("no names, or no text, changes nothing", () => {
    expect(nameRedactor([]).redact("Sara Haddad")).toBe("Sara Haddad");
    expect(redact("")).toBe("");
    expect(redact("Photosynthesis happens in chloroplasts."))
      .toBe("Photosynthesis happens in chloroplasts.");
  });

  test("a name that is only particles or digits is ignored", () => {
    const r = nameRedactor([
      { name: "Al", kind: "classmate" },
      { name: "12345", kind: "classmate" },
      { name: "   ", kind: "classmate" },
    ]);
    expect(r.redact("Al has 12345 apples")).toBe("Al has 12345 apples");
  });
});
