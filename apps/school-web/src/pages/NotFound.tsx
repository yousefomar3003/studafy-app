import type { Copy } from "../i18n";
import { type Lang, pathFor } from "../routes";

export function NotFound({ copy, lang }: { copy: Copy; lang: Lang }) {
  return (
    <section className="page-hero not-found">
      <div className="hero-bg" aria-hidden="true" />
      <div className="wrap center">
        <p className="big-404" aria-hidden="true">404</p>
        <h1>{copy.notFound.title}</h1>
        <p className="lead">{copy.notFound.text}</p>
        <a className="button" href={pathFor("home", lang)}>
          {copy.notFound.home}
        </a>
      </div>
    </section>
  );
}
