/**
 * Names out of everything sent to the AI provider (ADR-0043, DPIA D1).
 *
 * Privacy policy 1.4 says names are never sent to the AI provider. Studafy
 * never adds one, but a student can type a classmate's name into a question,
 * and a teacher's file can carry a class list. Before any model call, the
 * names of the people the student can see in Studafy - their own, their
 * classmates' and teachers' in the classes they are in, and their parents' -
 * are replaced with a neutral placeholder: "[student]", "[classmate]",
 * "[teacher]" or "[parent]".
 *
 * Matching is on whole words, after folding case and diacritics (Latin
 * accents, Arabic short vowels and tatweel, the forms of alef, alef maqsura,
 * taa marbuta). A full name is replaced wherever its words appear together;
 * one word of a name on its own only when it has at least three letters, is
 * not a particle such as "bin" or "عبد", and is not a common word that is
 * also a name ("Will", "Grace", "نور", "أمل"). Such a common word is
 * replaced on its own only in Latin script, when it is written with a
 * capital in the middle of a sentence ("I asked Will"), never at the start
 * of one ("Will it rain?"). An Arabic one never is: Arabic has no capitals
 * to tell the name from the word.
 *
 * Not a guarantee: a nickname, a misspelling or a name Studafy does not know
 * still goes through, and nothing here can see into a photo.
 */

export type NameKind = "self" | "parent" | "teacher" | "classmate";

/** A person the student can see, by the name Studafy has for them. */
export interface KnownName {
  name: string;
  kind: NameKind;
}

export const NAME_PLACEHOLDERS: Record<NameKind, string> = {
  self: "[student]",
  parent: "[parent]",
  teacher: "[teacher]",
  classmate: "[classmate]",
};

/** The fewest letters one word of a name needs to be replaced alone. */
export const NAME_MIN_LETTERS = 3;

// Which placeholder wins when one word is in several names: the student's
// own name first, then the people closest to them.
const PRIORITY: Record<NameKind, number> = {
  self: 0,
  parent: 1,
  teacher: 2,
  classmate: 3,
};

/** Parts of names that are not names on their own. */
const PARTICLES = new Set([
  // Latin script.
  "al",
  "el",
  "bin",
  "bint",
  "ibn",
  "abu",
  "abd",
  "abdul",
  "de",
  "da",
  "di",
  "del",
  "della",
  "der",
  "den",
  "van",
  "von",
  "le",
  "la",
  "du",
  "mc",
  "mac",
  "st",
  // Arabic script, folded (see fold()).
  "بن",
  "بنت",
  "ابن",
  "ابو",
  "ابي",
  "ام",
  "ال",
  "عبد",
  "الله",
  "الدين",
  "الرحمن",
  "الرحيم",
]);

/**
 * Words that are names and also ordinary words. Folded forms: lower case,
 * no diacritics, Arabic alef and taa marbuta normalised.
 */
const COMMON_WORDS = new Set([
  // English.
  "will",
  "may",
  "mark",
  "bill",
  "jack",
  "frank",
  "grace",
  "hope",
  "faith",
  "joy",
  "rose",
  "lily",
  "ivy",
  "iris",
  "violet",
  "daisy",
  "holly",
  "june",
  "april",
  "august",
  "dawn",
  "summer",
  "autumn",
  "amber",
  "ruby",
  "pearl",
  "honey",
  "angel",
  "sunny",
  "sky",
  "river",
  "rain",
  "storm",
  "star",
  "king",
  "prince",
  "young",
  "white",
  "brown",
  "green",
  "black",
  "gray",
  "grey",
  "long",
  "little",
  "small",
  "page",
  "hall",
  "wood",
  "stone",
  "rich",
  "love",
  "chase",
  "hunter",
  "baker",
  "cook",
  "mason",
  "bell",
  "hill",
  "park",
  "lane",
  "field",
  "ford",
  "case",
  "earl",
  "duke",
  "major",
  "penny",
  "sandy",
  "rusty",
  "guy",
  "gene",
  "glen",
  "cliff",
  "dale",
  "wade",
  "art",
  "sue",
  "pat",
  "rob",
  "ray",
  "max",
  "kit",
  "don",
  "ben",
  "victor",
  "sage",
  "reed",
  "miles",
  "hazel",
  "olive",
  "jade",
  "crystal",
  "sterling",
  "west",
  "north",
  // Arabic, folded.
  "نور",
  "امل",
  "سعيد",
  "كريم",
  "جميل",
  "حسن",
  "فرح",
  "سلام",
  "هدي",
  "ايمان",
  "رحمه",
  "سماء",
  "قمر",
  "شمس",
  "بدر",
  "نجم",
  "ورد",
  "زهره",
  "عادل",
  "امين",
  "سالم",
  "عزيز",
  "حياه",
  "وفاء",
  "سعاده",
  "جمال",
  "كامل",
  "صالح",
  "ربيع",
  "دنيا",
  "صفاء",
  "ضياء",
  "رجاء",
  "منير",
  "لطيف",
  "حكيم",
  "نبيل",
  "فاضل",
  "طاهر",
  "باسم",
  "هادي",
  "سليم",
  "مالك",
  "ناصر",
  "شريف",
  "عالم",
  "منصور",
  "راشد",
]);

/** Arabic letters a word can start with that are a separate word. */
const ARABIC_PREFIXES = new Set(["و", "ف", "ب", "ل", "ك"]);

const LETTER_OR_DIGIT = /[\p{L}\p{N}]/u;
const MARK = /\p{M}/u;
const TATWEEL = "ـ";
const ARABIC_LETTER = /[؀-ۿ]/;

/** One character as it is compared: case, accents and Arabic forms folded. */
function foldChar(ch: string): string {
  switch (ch) {
    case "أ":
    case "إ":
    case "آ":
    case "ٱ":
      return "ا";
    case "ى":
      return "ي";
    case "ة":
      return "ه";
    case "ؤ":
      return "و";
    case "ئ":
      return "ي";
  }
  return ch.toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
}

/** One word of the text, with where it is. */
interface Word {
  /** UTF-16 offsets in the original text. */
  start: number;
  end: number;
  /** Where each folded character came from, for an Arabic prefix. */
  charStarts: number[];
  folded: string;
  /** The original first character is upper case. */
  capital: boolean;
}

function words(text: string): Word[] {
  const found: Word[] = [];
  let current: Word | null = null;
  let offset = 0;
  for (const ch of text) {
    const at = offset;
    offset += ch.length;
    if (MARK.test(ch) || ch === TATWEEL) {
      // Inside a word, a short vowel or a kashida is part of it.
      if (current) current.end = offset;
      continue;
    }
    if (LETTER_OR_DIGIT.test(ch)) {
      const folded = foldChar(ch);
      if (!current) {
        current = {
          start: at,
          end: offset,
          charStarts: [],
          folded: "",
          capital: ch !== ch.toLowerCase(),
        };
        found.push(current);
      }
      for (const _ of folded) current.charStarts.push(at);
      current.folded += folded;
      current.end = offset;
      continue;
    }
    current = null;
  }
  return found;
}

/** The folded words of a name. */
function nameWords(name: string): string[] {
  return words(name).map((word) => word.folded).filter((w) => w.length > 0);
}

function letters(word: string): number {
  return [...word].length;
}

/** What may sit between two words of one name: a space, a hyphen, a dot. */
const NAME_GAP = /^[ \t \-'’.]{1,3}$/;

interface Sequence {
  words: string[];
  kind: NameKind;
}

interface Single {
  kind: NameKind;
  common: boolean;
}

/** Replaces the names it was built with. Build once per request. */
export class NameRedactor {
  readonly #sequences = new Map<string, Sequence[]>();
  readonly #singles = new Map<string, Single>();
  readonly size: number;

  constructor(names: readonly KnownName[]) {
    let size = 0;
    for (const { name, kind } of names) {
      if (!(kind in NAME_PLACEHOLDERS)) continue;
      const parts = nameWords(String(name ?? ""));
      if (parts.length === 0) continue;
      size += 1;
      if (parts.length > 1) {
        const first = parts[0]!;
        const list = this.#sequences.get(first) ?? [];
        list.push({ words: parts, kind });
        this.#sequences.set(first, list);
      }
      for (const part of parts) {
        if (letters(part) < NAME_MIN_LETTERS || PARTICLES.has(part)) continue;
        if (/^\p{N}+$/u.test(part)) continue;
        const existing = this.#singles.get(part);
        if (!existing || PRIORITY[kind] < PRIORITY[existing.kind]) {
          this.#singles.set(part, { kind, common: COMMON_WORDS.has(part) });
        }
      }
    }
    // Longest names first, so "Sara Al Ahmad" wins over "Sara Al".
    for (const list of this.#sequences.values()) {
      list.sort((a, b) =>
        b.words.length - a.words.length || PRIORITY[a.kind] - PRIORITY[b.kind]
      );
    }
    this.size = size;
  }

  /** [text] with every known name replaced by its placeholder. */
  redact(text: string): string {
    if (this.size === 0 || text.length === 0) return text;
    const found = words(text);
    if (found.length === 0) return text;
    const replacements: { start: number; end: number; with: string }[] = [];
    let i = 0;
    while (i < found.length) {
      const match = this.#matchAt(text, found, i);
      if (match) {
        replacements.push({
          start: match.start,
          end: found[i + match.length - 1]!.end,
          with: NAME_PLACEHOLDERS[match.kind],
        });
        i += match.length;
        continue;
      }
      i += 1;
    }
    if (replacements.length === 0) return text;
    let out = "";
    let at = 0;
    for (const r of replacements) {
      out += text.slice(at, r.start) + r.with;
      at = r.end;
    }
    return out + text.slice(at);
  }

  #matchAt(
    text: string,
    found: Word[],
    i: number,
  ): { length: number; kind: NameKind; start: number } | null {
    const word = found[i]!;
    // The word as written, and without a one-letter Arabic prefix ("and",
    // "by", "for", "like"), which stays in the text.
    const forms: { key: string; start: number }[] = [
      { key: word.folded, start: word.start },
    ];
    const first = [...word.folded][0];
    if (
      first && ARABIC_PREFIXES.has(first) && ARABIC_LETTER.test(first) &&
      letters(word.folded) > NAME_MIN_LETTERS
    ) {
      forms.push({
        key: [...word.folded].slice(1).join(""),
        start: word.charStarts[1] ?? word.start,
      });
    }
    for (const form of forms) {
      for (const sequence of this.#sequences.get(form.key) ?? []) {
        if (this.#continues(text, found, i, sequence.words)) {
          return {
            length: sequence.words.length,
            kind: sequence.kind,
            start: form.start,
          };
        }
      }
    }
    for (const form of forms) {
      const single = this.#singles.get(form.key);
      if (!single) continue;
      if (single.common && !commonWordIsName(text, word, form.start)) {
        continue;
      }
      return { length: 1, kind: single.kind, start: form.start };
    }
    return null;
  }

  #continues(
    text: string,
    found: Word[],
    i: number,
    sequence: string[],
  ): boolean {
    if (i + sequence.length > found.length) return false;
    for (let k = 1; k < sequence.length; k++) {
      const previous = found[i + k - 1]!;
      const next = found[i + k]!;
      if (next.folded !== sequence[k]) return false;
      if (!NAME_GAP.test(text.slice(previous.end, next.start))) return false;
    }
    return true;
  }
}

/**
 * A common word is taken for a name only in Latin script, capitalised, and
 * not where any word would be capitalised: the start of the text, a line or
 * a sentence.
 */
function commonWordIsName(text: string, word: Word, start: number): boolean {
  if (start !== word.start) return false; // An Arabic word with a prefix.
  if (ARABIC_LETTER.test(word.folded)) return false;
  if (!word.capital) return false;
  const before = text.slice(0, start);
  if (/(^|\n)[ \t]*["'“‘(\[]*$/u.test(before)) return false;
  return !/[.!?:؟]["'”’)\]]*\s+["'“‘(\[]*$/u.test(before);
}

/** A redactor for [names]; one with no names returns text unchanged. */
export function nameRedactor(names: readonly KnownName[]): NameRedactor {
  return new NameRedactor(names);
}
