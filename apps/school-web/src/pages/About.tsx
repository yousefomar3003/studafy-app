import type { Copy } from "../i18n";
import { Icon } from "../components/Icon";
import { SectionHead, Wrap } from "../components/Parts";
import { type Lang, pathFor } from "../routes";

export function About({ copy, lang }: { copy: Copy; lang: Lang }) {
  const page = copy.about;
  return (
    <>
      <section className="page-hero">
        <div className="hero-bg" aria-hidden="true" />
        <div className="wrap">
          <SectionHead section={page.hero} center as="h1" />
        </div>
      </section>

      <Wrap>
        <div className="mission reveal">
          <h2>{page.mission.title}</h2>
          <p>{page.mission.text}</p>
        </div>
      </Wrap>

      <Wrap className="tint">
        <SectionHead section={page.beliefs} center />
        <ul className="grid four">
          {page.beliefs.cards.map((card) => (
            <li key={card.title} className="card reveal">
              <span className="tile-icon">
                <Icon name={card.icon} />
              </span>
              <h3>{card.title}</h3>
              <p>{card.text}</p>
            </li>
          ))}
        </ul>
      </Wrap>

      <Wrap className="ink">
        <SectionHead section={page.how} center />
        <ul className="grid three">
          {page.how.cards.map((card) => (
            <li key={card.title} className="glass reveal">
              <span className="tile-icon">
                <Icon name={card.icon} />
              </span>
              <h3>{card.title}</h3>
              <p>{card.text}</p>
            </li>
          ))}
        </ul>
      </Wrap>

      <section className="band cta">
        <div className="wrap cta-inner reveal">
          <h2>{page.cta.title}</h2>
          <p className="lead">{page.cta.text}</p>
          <a className="button light" href={pathFor("contact", lang)}>
            {page.cta.button}
          </a>
        </div>
      </section>
    </>
  );
}
