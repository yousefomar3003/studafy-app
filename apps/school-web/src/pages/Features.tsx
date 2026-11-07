import type { Copy } from "../i18n";
import { Icon } from "../components/Icon";
import { Phone, SectionHead, StoreBadges, Wrap } from "../components/Parts";
import type { Lang } from "../routes";

export function Features({ copy, lang }: { copy: Copy; lang: Lang }) {
  const page = copy.features;
  return (
    <>
      <section className="page-hero">
        <div className="hero-bg" aria-hidden="true" />
        <div className="wrap">
          <SectionHead section={page.hero} center as="h1" />
          <nav className="jump reveal" aria-label={page.hero.eyebrow}>
            {page.roles.map((role) => (
              <a key={role.key} href={`#${role.key}`}>{role.tab}</a>
            ))}
          </nav>
        </div>
      </section>

      {page.roles.map((role, index) => (
        <Wrap
          key={role.key}
          id={role.key}
          className={index % 2 === 1 ? "tint" : undefined}
        >
          <div className={`split ${index % 2 === 1 ? "reverse" : ""}`.trim()}>
            <div>
              <header className="section-head reveal">
                <p className="eyebrow">{role.tab}</p>
                <h2>{role.title}</h2>
                <p className="lead">{role.text}</p>
              </header>
              <ul className="ticks reveal">
                {[...role.points, ...role.more].map((point) => (
                  <li key={point}>
                    <Icon name="check" />
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
            </div>
            <div className="pair reveal">
              <Phone
                lang={lang}
                screen={role.screen}
                alt={role.screenAlt}
                eager={index === 0}
              />
              <Phone lang={lang} screen={role.screen2} alt={role.screen2Alt} />
            </div>
          </div>
        </Wrap>
      ))}

      <Wrap className="ink">
        <SectionHead section={page.ai} center />
        <ul className="duo">
          {page.ai.cards.map((card) => (
            <li key={card.title} className="glass reveal">
              <span className="tag">{card.tag}</span>
              <span className="tile-icon">
                <Icon name={card.icon} />
              </span>
              <h3>{card.title}</h3>
              <p>{card.text}</p>
            </li>
          ))}
        </ul>
        <p className="fine center reveal">{page.ai.note}</p>
      </Wrap>

      <Wrap>
        <SectionHead section={page.plans} center />
        <p className="free reveal">
          <Icon name="heart" />
          <span>{page.plans.free}</span>
        </p>
        <ul className="grid four plans">
          {page.plans.list.map((plan) => (
            <li key={plan.name} className="card reveal">
              <span className="tag">{plan.who}</span>
              <h3>
                <bdi>{plan.name}</bdi>
              </h3>
              <p>{plan.text}</p>
            </li>
          ))}
        </ul>
        <p className="fine center">{page.plans.note}</p>
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
          <h2>{copy.home.cta.title}</h2>
          <p className="lead">{copy.home.cta.text}</p>
          <StoreBadges copy={copy} lang={lang} />
        </div>
      </section>
    </>
  );
}
