import type { Copy } from "../i18n";
import { config, legalUrl } from "../config";
import { Icon } from "../components/Icon";
import { SectionHead, Wrap } from "../components/Parts";
import type { Lang } from "../routes";

function mailto(subject: string): string {
  return `mailto:${config.contactEmail}?subject=${encodeURIComponent(subject)}`;
}

export function Contact({ copy, lang }: { copy: Copy; lang: Lang }) {
  const page = copy.contact;
  return (
    <>
      <section className="page-hero">
        <div className="hero-bg" aria-hidden="true" />
        <div className="wrap">
          <SectionHead section={page.hero} center as="h1" />
          <p className="center reveal">
            <a className="email" href={`mailto:${config.contactEmail}`}>
              {config.contactEmail}
            </a>
          </p>
        </div>
      </section>

      <Wrap>
        <ul className="grid four">
          {page.cards.map((card) => (
            <li key={card.title}>
              <a className="card link-card reveal" href={mailto(card.subject)}>
                <span className="tile-icon">
                  <Icon name={card.icon} />
                </span>
                <h2>{card.title}</h2>
                <p>{card.text}</p>
                <span className="arrow" aria-hidden="true">→</span>
              </a>
            </li>
          ))}
        </ul>
        <p className="fine center">{page.reply}</p>
        <p className="fine center">
          {page.legal}{" "}
          <a href={legalUrl("privacy", lang)}>{copy.footer.privacy}</a>
          {" · "}
          <a href={legalUrl("terms", lang)}>{copy.footer.terms}</a>
        </p>
      </Wrap>
    </>
  );
}
