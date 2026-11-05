import { useEffect, useState } from "react";

export type ClassTab =
  | "students"
  | "lessons"
  | "assignments"
  | "tests"
  | "marks"
  | "attendance"
  | "wellbeing";

export const CLASS_TABS: readonly ClassTab[] = [
  "students",
  "lessons",
  "assignments",
  "tests",
  "marks",
  "attendance",
  "wellbeing",
];

export type Route =
  | { name: "home" }
  | { name: "callback" }
  | { name: "new" }
  | { name: "dashboard"; org: string }
  | { name: "teachers"; org: string }
  | { name: "classes"; org: string }
  | { name: "class"; org: string; classroom: string; tab: ClassTab }
  | { name: "handIns"; org: string; classroom: string; assignment: string }
  | { name: "answers"; org: string; classroom: string; test: string }
  | { name: "settings"; org: string }
  | { name: "student"; org: string; student: string }
  | { name: "teacher"; org: string; teacher: string }
  | { name: "notFound" };

const ID = /^[0-9a-f-]{36}$/i;

/**
 * The portal lives at the root of school.studafy.com; the dev server and a
 * preview serve it under /portal.
 */
export function basePath(
  pathname: string = typeof location === "undefined" ? "/" : location.pathname,
): string {
  return pathname === "/portal" || pathname.startsWith("/portal/")
    ? "/portal"
    : "";
}

export function parseRoute(pathname: string): Route {
  const base = basePath(pathname);
  const parts = pathname.slice(base.length).split("/").filter(Boolean);
  const [first, org, section, a, b, c] = parts;
  if (parts.length === 0) return { name: "home" };
  if (first === "auth" && org === "callback") return { name: "callback" };
  if (first === "new" && parts.length === 1) return { name: "new" };
  if (first !== "o" || !org || !ID.test(org)) return { name: "notFound" };
  if (!section) return { name: "dashboard", org };
  if (section === "teachers" && !a) return { name: "teachers", org };
  if (section === "teachers" && a && ID.test(a) && !b) {
    return { name: "teacher", org, teacher: a };
  }
  if (section === "students" && a && ID.test(a) && !b) {
    return { name: "student", org, student: a };
  }
  if (section === "settings" && !a) return { name: "settings", org };
  if (section === "classes" && !a) return { name: "classes", org };
  if (section === "classes" && a && ID.test(a)) {
    if (!b) return { name: "class", org, classroom: a, tab: "students" };
    if (b === "assignments" && c && ID.test(c)) {
      return { name: "handIns", org, classroom: a, assignment: c };
    }
    if (b === "tests" && c && ID.test(c)) {
      return { name: "answers", org, classroom: a, test: c };
    }
    if (CLASS_TABS.includes(b as ClassTab) && !c) {
      return { name: "class", org, classroom: a, tab: b as ClassTab };
    }
  }
  return { name: "notFound" };
}

export function hrefFor(route: Route, base: string = basePath()): string {
  const o = "org" in route ? `/o/${route.org}` : "";
  const path = (() => {
    switch (route.name) {
      case "home":
      case "notFound":
        return "/";
      case "callback":
        return "/auth/callback";
      case "new":
        return "/new";
      case "dashboard":
        return o;
      case "teachers":
        return `${o}/teachers`;
      case "classes":
        return `${o}/classes`;
      case "settings":
        return `${o}/settings`;
      case "student":
        return `${o}/students/${route.student}`;
      case "teacher":
        return `${o}/teachers/${route.teacher}`;
      case "class":
        return `${o}/classes/${route.classroom}/${route.tab}`;
      case "handIns":
        return `${o}/classes/${route.classroom}/assignments/${route.assignment}`;
      case "answers":
        return `${o}/classes/${route.classroom}/tests/${route.test}`;
    }
  })();
  return `${base}${path}`;
}

const CHANGE = "studafy:route";

export function navigate(route: Route, replace = false): void {
  const href = hrefFor(route);
  if (replace) history.replaceState(null, "", href);
  else history.pushState(null, "", href);
  dispatchEvent(new Event(CHANGE));
  scrollTo({ top: 0 });
}

export function useRoute(): Route {
  const [route, setRoute] = useState(() => parseRoute(location.pathname));
  useEffect(() => {
    const update = () => setRoute(parseRoute(location.pathname));
    addEventListener("popstate", update);
    addEventListener(CHANGE, update);
    return () => {
      removeEventListener("popstate", update);
      removeEventListener(CHANGE, update);
    };
  }, []);
  return route;
}

/** Moves to [to] after rendering, replacing the current address. */
export function Redirect({ to }: { to: Route }): null {
  useEffect(() => navigate(to, true), [hrefFor(to)]);
  return null;
}
