import type { IconName } from "../i18n/types";

/** 24px line icons, drawn with the current text colour. */
const PATHS: Record<IconName, string[]> = {
  book: [
    "M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5z",
    "M4 20.5A2.5 2.5 0 0 0 6.5 23H20v-5",
    "M9 8h7",
  ],
  clipboard: ["M9 4h6v3H9z", "M15 5h3v16H6V5h3", "M9 12l2 2 4-4"],
  exam: ["M5 3h14v18H5z", "M9 8h6", "M9 12h6", "M9 16h3"],
  chart: ["M4 20V4", "M4 20h16", "M8 16v-4", "M12 16V8", "M16 16v-6"],
  calendar: ["M4 6h16v15H4z", "M4 10h16", "M8 3v4", "M16 3v4", "M9 15l2 2 4-4"],
  chat: ["M4 5h16v11H9l-5 4z", "M8 9h8", "M8 12h5"],
  sparkle: [
    "M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z",
    "M19 16l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z",
  ],
  family: [
    "M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
    "M3 20a6 6 0 0 1 12 0",
    "M17 11a2.5 2.5 0 1 0 0-5",
    "M17 14a5 5 0 0 1 4 6",
  ],
  shield: [
    "M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6z",
    "M8.5 12l2.5 2.5 4.5-4.5",
  ],
  globe: [
    "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z",
    "M3 12h18",
    "M12 3c2.5 2.7 3.8 5.7 3.8 9s-1.3 6.3-3.8 9c-2.5-2.7-3.8-5.7-3.8-9S9.5 5.7 12 3z",
  ],
  lock: ["M6 11h12v10H6z", "M8.5 11V8a3.5 3.5 0 0 1 7 0v3", "M12 15v2"],
  download: ["M12 4v11", "M7 10l5 5 5-5", "M5 20h14"],
  school: ["M3 10l9-5 9 5-9 5z", "M7 12v5c3 2 7 2 10 0v-5", "M21 10v6"],
  eye: [
    "M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z",
    "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
  ],
  link: [
    "M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1",
    "M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1",
  ],
  file: ["M6 3h8l4 4v14H6z", "M14 3v4h4", "M9 13h6", "M9 17h4"],
  heart: [
    "M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z",
  ],
  check: ["M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z", "M8 12l3 3 5-6"],
  mail: ["M3 6h18v12H3z", "M3 7l9 6 9-6"],
  help: [
    "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z",
    "M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6",
    "M12 17h.01",
  ],
};

export function Icon(
  { name, className }: { name: IconName; className?: string },
) {
  return (
    <svg
      className={className ?? "icon"}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {PATHS[name].map((d) => <path key={d} d={d} />)}
    </svg>
  );
}
