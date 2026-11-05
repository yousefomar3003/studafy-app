import type { Copy } from "../i18n";
import { config } from "../config";
import { Icon } from "../components/Icon";
import { SectionHead, Wrap } from "../components/Parts";

/**
 * The School Portal's page. Published only when `VITE_PORTAL_PUBLIC` is on
 * (plan section 11), so nothing advertises the portal before it exists.
 */
export function Schools({ copy }: { copy: Copy }) {
  const page = copy.schools;
  return (
    <>
      <section className="page-hero">
        <div className="hero-bg" aria-hidden="true" />
        <div className="wrap">
          <SectionHead section={page.hero} center as="h1" />
          <div className="hero-actions center reveal">
            <a className="button" href={config.portalUrl}>{page.hero.cta}</a>
            <a className="button ghost" href="#how">{page.hero.secondary}</a>
          </div>
        </div>
      </section>

      <Wrap id="how">
        <h2 className="faq-title reveal">{page.steps.title}</h2>
        <ol className="steps">
          {page.steps.list.map((step, index) => (
            <li key={step.title} className="card reveal">
              <span className="step-number">{index + 1}</span>
              <h3>{step.title}</h3>
              <p>{step.text}</p>
            </li>
          ))}
        </ol>
      </Wrap>

      <Wrap className="tint">
        <SectionHead section={page.sees} center />
        <ul className="grid three">
          {page.sees.cards.map((card) => (
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

      <Wrap>
        <div className="split">
          <SectionHead section={page.control} />
          <ul className="ticks reveal">
            {page.control.points.map((point) => (
              <li key={point}>
                <Icon name="check" />
                <span>{point}</span>
              </li>
            ))}
          </ul>
        </div>
      </Wrap>

      <Wrap className="ink">
        <SectionHead section={page.never} center />
        <ul className="never reveal">
          {page.never.list.map((item) => (
            <li key={item}>
              <Icon name="lock" />
              <span>{item}</span>
            </li>
          ))}
        </ul>
      </Wrap>

      <Wrap className="tint">
        <h2 className="faq-title reveal">{page.faq.title}</h2>
        <div className="faq">
          {page.faq.list.map((item) => (
            <details key={item.q} className="reveal">
              <summary>{item.q}</summary>
              <p>{item.a}</p>
            </details>
          ))}
        </div>
      </Wrap>

      <section className="band cta">
        <div className="wrap cta-inner reveal">
          <h2>{page.cta.title}</h2>
          <p className="lead">{page.cta.text}</p>
          <a className="button light" href={config.portalUrl}>
            {page.cta.button}
          </a>
        </div>
      </section>
    </>
  );
}
