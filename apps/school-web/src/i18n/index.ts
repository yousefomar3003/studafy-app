import type { Lang } from "../routes";
import { ar } from "./ar";
import { en } from "./en";
import type { Copy } from "./types";

const COPY: Record<Lang, Copy> = { en, ar };

export function copyFor(lang: Lang): Copy {
  return COPY[lang];
}

export type { Copy } from "./types";
