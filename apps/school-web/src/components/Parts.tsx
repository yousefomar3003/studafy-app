import type { ReactNode } from "react";
import { config } from "../config";
import type { Copy } from "../i18n";
import type { ScreenName, Section } from "../i18n/types";
import type { Lang } from "../routes";

/** A store screenshot in a phone frame. */
export function Phone(
  { lang, screen, alt, className, eager }: {
    lang: Lang;
    screen: ScreenName;
    alt: string;
    className?: string;
    /** The first picture on a page loads at once; the rest when scrolled to. */
    eager?: boolean;
  },
) {
  return (
    <figure className={`phone ${className ?? ""}`.trim()}>
      <img
        src={`/screens/${lang}/${screen}.webp`}
        alt={alt}
        width={600}
        height={1304}
        loading={eager ? "eager" : "lazy"}
        decoding="async"
        {...(eager ? { fetchPriority: "high" as const } : {})}
      />
    </figure>
  );
}

/**
 * The official store badges, once both store pages exist. Apple's badge
 * has no Arabic version in the repo yet, so Arabic pages use the English
 * one (see docs/deployment/studafy-web.md).
 */
export function StoreBadges({ copy, lang }: { copy: Copy; lang: Lang }) {
  if (!config.appStoreUrl || !config.playStoreUrl) {
    return <p className="store-soon">{copy.store.soon}</p>;
  }
  return (
    <div className="badges">
      <a href={config.appStoreUrl} rel="noopener">
        <img
          src="/badges/app-store-en.svg"
          alt={copy.store.appStoreAlt}
          width={150}
          height={50}
        />
      </a>
      <a href={config.playStoreUrl} rel="noopener">
        <img
          className="badge-play"
          src={`/badges/google-play-${lang}.png`}
          alt={copy.store.playAlt}
          width={168}
          height={65}
        />
      </a>
    </div>
  );
}

export function SectionHead(
  { section, center, as = "h2" }: {
    section: Section;
    center?: boolean;
    as?: "h1" | "h2";
  },
) {
  const Heading = as;
  return (
    <header className={`section-head reveal ${center ? "center" : ""}`.trim()}>
      <p className="eyebrow">{section.eyebrow}</p>
      <Heading>{section.title}</Heading>
      <p className="lead">{section.text}</p>
    </header>
  );
}

export function Wrap(
  { children, className, id }: {
    children: ReactNode;
    className?: string;
    id?: string;
  },
) {
  return (
    <section id={id} className={`band ${className ?? ""}`.trim()}>
      <div className="wrap">{children}</div>
    </section>
  );
}
