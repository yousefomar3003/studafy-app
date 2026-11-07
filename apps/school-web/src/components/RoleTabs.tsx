import { type KeyboardEvent, useState } from "react";
import type { Role } from "../i18n/types";
import type { Lang } from "../routes";
import { Icon } from "./Icon";
import { Phone } from "./Parts";

/**
 * Teachers / Students / Parents. The first role is rendered on the server,
 * so the section reads well before the script loads; the tabs work once it
 * has. Arrow keys move between tabs (WAI-ARIA tabs pattern).
 */
export function RoleTabs({ roles, lang }: { roles: Role[]; lang: Lang }) {
  const [active, setActive] = useState(0);
  const role = roles[active] ?? roles[0];
  if (!role) return null;

  function onKey(event: KeyboardEvent<HTMLButtonElement>) {
    const forward = lang === "ar" ? "ArrowLeft" : "ArrowRight";
    const back = lang === "ar" ? "ArrowRight" : "ArrowLeft";
    if (event.key !== forward && event.key !== back) return;
    event.preventDefault();
    const step = event.key === forward ? 1 : -1;
    const next = (active + step + roles.length) % roles.length;
    setActive(next);
    document.getElementById(`role-tab-${roles[next]?.key}`)?.focus();
  }

  return (
    <div className="roles reveal">
      <div className="role-tabs" role="tablist">
        {roles.map((item, index) => (
          <button
            key={item.key}
            id={`role-tab-${item.key}`}
            type="button"
            role="tab"
            aria-selected={index === active}
            aria-controls="role-panel"
            tabIndex={index === active ? 0 : -1}
            onClick={() => setActive(index)}
            onKeyDown={onKey}
          >
            {item.tab}
          </button>
        ))}
      </div>
      <div
        id="role-panel"
        className="role-panel"
        role="tabpanel"
        aria-labelledby={`role-tab-${role.key}`}
        key={role.key}
      >
        <div className="role-copy">
          <h3>{role.title}</h3>
          <p>{role.text}</p>
          <ul className="ticks">
            {role.points.map((point) => (
              <li key={point}>
                <Icon name="check" />
                <span>{point}</span>
              </li>
            ))}
          </ul>
        </div>
        <div className="role-visual">
          <div className="glow" aria-hidden="true" />
          <Phone lang={lang} screen={role.screen} alt={role.screenAlt} />
        </div>
      </div>
    </div>
  );
}
