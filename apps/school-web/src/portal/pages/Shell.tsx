import type { ReactNode } from "react";
import type { Org } from "../api";
import { signOut } from "../auth";
import { useCopy } from "../i18n";
import { hrefFor, navigate, type Route } from "../router";

type Section = "dashboard" | "teachers" | "classes" | "reports" | "settings";

/** Side menu on a computer, bottom menu on a phone (plan 5). */
export function Shell({ org, orgs, section, onLanguage, children }: {
  org: Org;
  orgs: Org[];
  section: Section;
  onLanguage: () => void;
  children: ReactNode;
}) {
  const copy = useCopy();
  const items: { key: Section; route: Route; icon: string }[] = [
    {
      key: "dashboard",
      route: { name: "dashboard", org: org.id },
      icon: "M4 13h6V4H4zm0 7h6v-5H4zm10 0h6v-9h-6zm0-16v5h6V4z",
    },
    {
      key: "teachers",
      route: { name: "teachers", org: org.id },
      icon: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm-7 8a7 7 0 0 1 14 0",
    },
    {
      key: "classes",
      route: { name: "classes", org: org.id },
      icon: "M3 9l9-5 9 5-9 5zm4 2v5c3 2 7 2 10 0v-5",
    },
    {
      key: "reports",
      route: { name: "reports", org: org.id },
      icon: "M4 20V4M4 20h16M8 16v-4M12 16V8M16 16v-6",
    },
    {
      key: "settings",
      route: { name: "settings", org: org.id },
      icon:
        "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm8-3l2-1-2-4-2 1-2-1V5h-4v2l-2 1-2-1-2 4 2 1v2l-2 1 2 4 2-1 2 1v2h4v-2l2-1 2 1 2-4-2-1z",
    },
  ];
  return (
    <div className="portal">
      <aside className="side">
        <a
          className="side-logo"
          href={hrefFor({ name: "dashboard", org: org.id })}
          onClick={(e) => {
            e.preventDefault();
            navigate({ name: "dashboard", org: org.id });
          }}
        >
          <img src="/brand/logo.svg" alt="Studafy" width={112} height={35} />
        </a>
        <nav className="side-nav" aria-label={copy.product}>
          {items.map((item) => (
            <a
              key={item.key}
              href={hrefFor(item.route)}
              aria-current={item.key === section ? "page" : undefined}
              onClick={(e) => {
                e.preventDefault();
                navigate(item.route);
              }}
            >
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d={item.icon} />
              </svg>
              <span>{copy.nav[item.key]}</span>
            </a>
          ))}
        </nav>
      </aside>
      <div className="main">
        <header className="topbar">
          <div className="school">
            {orgs.length > 1
              ? (
                <select
                  aria-label={copy.product}
                  value={org.id}
                  onChange={(e) =>
                    navigate({ name: "dashboard", org: e.target.value })}
                >
                  {orgs.map((o) => (
                    <option key={o.id} value={o.id}>{o.name}</option>
                  ))}
                </select>
              )
              : <strong dir="auto">{org.name}</strong>}
            <span
              className={`pill ${org.status === "active" ? "good" : "warn"}`}
            >
              {copy.dashboard.status[org.status]}
            </span>
          </div>
          <div className="topbar-actions">
            <button
              type="button"
              className="btn ghost small"
              onClick={onLanguage}
            >
              {copy.otherLanguage}
            </button>
            <button
              type="button"
              className="btn ghost small"
              onClick={async () => {
                await signOut();
                navigate({ name: "home" }, true);
              }}
            >
              {copy.signOut}
            </button>
          </div>
        </header>
        <main className="content" id="main">{children}</main>
      </div>
    </div>
  );
}
