import type { Copy } from "../i18n";
import { Icon } from "../components/Icon";
import { Phone, SectionHead, StoreBadges, Wrap } from "../components/Parts";
import { RoleTabs } from "../components/RoleTabs";
import { type Lang, pathFor } from "../routes";

export function Home({ copy, lang }: { copy: Copy; lang: Lang }) {
  const home = copy.home;
  const hero = home.hero;
  return (
    <>
      <section className="hero">
        <div className="hero-bg" aria-hidden="true" />
        <div className="wrap hero-grid">
          <div className="hero-copy">
            <p className="eyebrow rise d1">{hero.eyebrow}</p>
            <h1 className="rise d2">
              {hero.title} <span className="accent">{hero.accent}</span>
            </h1>
            <p className="lead rise d3">{hero.text}</p>
            <div className="hero-actions rise d4">
              <StoreBadges copy={copy} lang={lang} />
              <a className="button ghost" href={pathFor("features", lang)}>
                {hero.secondary}
              </a>
            </div>
            <ul className="chips rise d5">
              {hero.chips.map((chip) => <li key={chip}>{chip}</li>)}
            </ul>
          </div>
          <div className="hero-visual">
            <Phone
              lang={lang}
              screen="student-3-homework"
              alt={hero.screenAlts.student}
              className="side side-start"
            />
            <Phone
              lang={lang}
              screen="teacher-1-today"
              alt={hero.screenAlts.teacher}
              className="front"
              eager
            />
            <Phone
              lang={lang}
              screen="parent-1-today"
              alt={hero.screenAlts.parent}
              className="side side-end"
            />
            <p className="float f1" aria-hidden="true">
              <Icon name="check" />
              {hero.floating.published}
            </p>
            <p className="float f2" aria-hidden="true">
              <Icon name="calendar" />
              {hero.floating.attendance}
            </p>
            <p className="float f3" aria-hidden="true">
              <Icon name="clipboard" />
              {hero.floating.homework}
            </p>
          </div>
        </div>
      </section>

      <Wrap id="roles">
        <SectionHead section={home.roles} center />
        <RoleTabs roles={home.roles.list} lang={lang} />
      </Wrap>

      <Wrap className="tint">
        <SectionHead section={home.everyday} center />
        <ul className="bento">
          {home.everyday.cards.map((card, index) => (
            <li
              key={card.title}
              className={`tile reveal ${index < 2 ? "wide" : ""}`.trim()}
            >
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
          <div>
            <SectionHead section={home.marks} />
            <ul className="points">
              {home.marks.points.map((point) => (
                <li key={point.title} className="reveal">
                  <span className="tile-icon">
                    <Icon name={point.icon} />
                  </span>
                  <div>
                    <h3>{point.title}</h3>
                    <p>{point.text}</p>
                  </div>
                </li>
              ))}
            </ul>
          </div>
          <div className="split-visual reveal">
            <div className="glow" aria-hidden="true" />
            <Phone
              lang={lang}
              screen="student-4-grades"
              alt={home.marks.screenAlt}
            />
          </div>
        </div>
      </Wrap>

      <Wrap className="ink">
        <SectionHead section={home.ai} center />
        <ul className="duo">
          {home.ai.cards.map((card) => (
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
        <p className="fine center reveal">{home.ai.note}</p>
      </Wrap>

      <Wrap>
        <SectionHead section={home.start} center />
        <ol className="grid three steps">
          {home.start.steps.map((step, index) => (
            <li key={step.title} className="card reveal">
              <span className="step-num" aria-hidden="true">{index + 1}</span>
              <h3>{step.title}</h3>
              <p>{step.text}</p>
            </li>
          ))}
        </ol>
      </Wrap>

      <Wrap className="tint">
        <div className="split reverse">
          <SectionHead section={home.bilingual} />
          <div className="pair reveal">
            <Phone
              lang="en"
              screen="teacher-4-grade-sheet"
              alt={home.bilingual.enAlt}
            />
            <Phone
              lang="ar"
              screen="teacher-4-grade-sheet"
              alt={home.bilingual.arAlt}
            />
          </div>
        </div>
      </Wrap>

      <Wrap>
        <SectionHead section={home.plans} center />
        <p className="free reveal">
          <Icon name="heart" />
          <span>{home.plans.free}</span>
        </p>
        <ul className="grid four plans">
          {home.plans.list.map((plan) => (
            <li key={plan.name} className="card reveal">
              <span className="tag">{plan.who}</span>
              <h3>
                <bdi>{plan.name}</bdi>
              </h3>
              <p>{plan.text}</p>
            </li>
          ))}
        </ul>
        <p className="fine center">{home.plans.note}</p>
      </Wrap>

      <section id="get" className="band cta">
        <div className="wrap cta-inner reveal">
          <h2>{home.cta.title}</h2>
          <p className="lead">{home.cta.text}</p>
          <StoreBadges copy={copy} lang={lang} />
        </div>
      </section>
    </>
  );
}
