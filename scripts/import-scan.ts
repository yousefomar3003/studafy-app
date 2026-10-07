/**
 * The module specifiers a TypeScript source imports or re-exports.
 *
 * Read from tokens, not from the raw text: matching patterns over the text
 * took the word "from" inside a comment or a string ("Made from") for an
 * import, and reported a package nobody imports. Here comments are skipped
 * and a string is one token, so only real statements count:
 *
 *   import x from "a";   import type { T } from "a";   import "a";
 *   export { x } from "a";   export * from "a";   import("a")
 */

type Token =
  | { kind: "word"; value: string }
  | { kind: "string"; value: string }
  | { kind: "punct"; value: string };

/** Words after which a `/` starts a regular expression, not a division. */
const REGEX_AFTER_WORD = new Set([
  "return",
  "typeof",
  "case",
  "do",
  "else",
  "in",
  "of",
  "new",
  "delete",
  "void",
  "throw",
  "yield",
  "await",
]);

function tokenize(source: string): Token[] {
  const tokens: Token[] = [];
  let i = 0;
  const n = source.length;
  const regexAllowed = () => {
    const last = tokens.at(-1);
    if (!last) return true;
    if (last.kind === "punct") return !")]}".includes(last.value);
    if (last.kind === "word") return REGEX_AFTER_WORD.has(last.value);
    return false;
  };
  // Skips a template literal from its opening backtick, nested ${} included.
  const skipTemplate = () => {
    i++;
    while (i < n && source[i] !== "`") {
      if (source[i] === "\\") {
        i += 2;
      } else if (source[i] === "$" && source[i + 1] === "{") {
        i += 2;
        let depth = 1;
        while (i < n && depth > 0) {
          const c = source[i]!;
          if (c === "{") depth++;
          else if (c === "}") depth--;
          else if (c === "`") {
            skipTemplate();
            continue;
          } else if (c === '"' || c === "'") {
            readString(c);
            continue;
          }
          i++;
        }
      } else {
        i++;
      }
    }
    i++;
  };
  const readString = (quote: string): string => {
    let value = "";
    i++;
    while (i < n && source[i] !== quote && source[i] !== "\n") {
      if (source[i] === "\\") {
        value += source[i + 1] ?? "";
        i += 2;
      } else {
        value += source[i];
        i++;
      }
    }
    i++;
    return value;
  };
  while (i < n) {
    const c = source[i]!;
    const next = source[i + 1];
    if (/\s/.test(c)) {
      i++;
    } else if (c === "/" && next === "/") {
      while (i < n && source[i] !== "\n") i++;
    } else if (c === "/" && next === "*") {
      const end = source.indexOf("*/", i + 2);
      i = end < 0 ? n : end + 2;
    } else if (c === '"' || c === "'") {
      tokens.push({ kind: "string", value: readString(c) });
    } else if (c === "`") {
      skipTemplate();
      tokens.push({ kind: "punct", value: "`" });
    } else if (c === "/" && regexAllowed()) {
      i++;
      let inClass = false;
      while (i < n && source[i] !== "\n") {
        const r = source[i]!;
        if (r === "\\") {
          i += 2;
          continue;
        }
        if (r === "[") inClass = true;
        else if (r === "]") inClass = false;
        else if (r === "/" && !inClass) break;
        i++;
      }
      i++;
      while (i < n && /[a-z]/i.test(source[i]!)) i++;
      tokens.push({ kind: "punct", value: "regex" });
    } else if (/[A-Za-z_$]/.test(c)) {
      let j = i + 1;
      while (j < n && /[\w$]/.test(source[j]!)) j++;
      tokens.push({ kind: "word", value: source.slice(i, j) });
      i = j;
    } else {
      tokens.push({ kind: "punct", value: c });
      i++;
    }
  }
  return tokens;
}

/** Every module specifier in [source], each once. */
export function extractImports(source: string): string[] {
  const tokens = tokenize(source);
  const specifiers = new Set<string>();
  const at = (k: number) => tokens[k];
  for (let k = 0; k < tokens.length; k++) {
    const token = at(k)!;
    if (token.kind !== "word") continue;
    const previous = at(k - 1);
    // `x.import` or `{ import: ... }` is a property, not a statement.
    if (previous?.kind === "punct" && previous.value === ".") continue;
    if (token.value === "import") {
      const next = at(k + 1);
      if (next?.kind === "string") {
        specifiers.add(next.value);
      } else if (next?.kind === "punct" && next.value === "(") {
        const arg = at(k + 2);
        if (arg?.kind === "string") specifiers.add(arg.value);
      } else if (!(next?.kind === "punct" && next.value === ".")) {
        const from = fromClause(tokens, k + 1);
        if (from) specifiers.add(from);
      }
    } else if (token.value === "export") {
      const next = at(k + 1);
      const reExport = next?.kind === "punct"
        ? next.value === "{" || next.value === "*"
        : next?.kind === "word" && next.value === "type" &&
          at(k + 2)?.kind === "punct" &&
          (at(k + 2)!.value === "{" || at(k + 2)!.value === "*");
      if (reExport) {
        const from = fromClause(tokens, k + 1);
        if (from) specifiers.add(from);
      }
    }
  }
  return [...specifiers];
}

/** The specifier of the `from "..."` ending a clause, if it has one. */
function fromClause(tokens: Token[], start: number): string | null {
  for (let k = start; k < tokens.length; k++) {
    const token = tokens[k]!;
    if (token.kind === "punct" && token.value === ";") return null;
    if (
      token.kind === "word" &&
      (token.value === "import" || token.value === "export")
    ) {
      return null;
    }
    const next = tokens[k + 1];
    if (
      token.kind === "word" && token.value === "from" && next?.kind === "string"
    ) {
      return next.value;
    }
  }
  return null;
}
