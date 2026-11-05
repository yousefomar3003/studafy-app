import { useEffect, useState } from "react";
import { api } from "./api";
import { touch, useSession } from "./auth";
import {
  CopyContext,
  copyFor,
  initialLang,
  type PortalLang,
  saveLang,
} from "./i18n";
import { useLoad } from "./load";
import { Redirect, type Route, useRoute } from "./router";
import { Loader } from "./ui";
import { ClassPage } from "./pages/ClassPage";
import { Classes } from "./pages/Classes";
import { CreateSchool } from "./pages/CreateSchool";
import { Dashboard } from "./pages/Dashboard";
import { Settings } from "./pages/Settings";
import { Shell } from "./pages/Shell";
import { SignIn } from "./pages/SignIn";
import { Teachers } from "./pages/Teachers";
import { Welcome } from "./pages/Welcome";
import { AnswersPage, HandInsPage } from "./pages/Work";

/** The School Portal: sign-in, then the school pages the person runs. */
export function Portal() {
  const [lang, setLang] = useState<PortalLang>(initialLang);
  useEffect(() => saveLang(lang), [lang]);
  // Any interaction counts as activity for the 12-hour idle limit.
  useEffect(() => {
    const on = () => touch();
    addEventListener("pointerdown", on);
    addEventListener("keydown", on);
    return () => {
      removeEventListener("pointerdown", on);
      removeEventListener("keydown", on);
    };
  }, []);
  return (
    <CopyContext.Provider value={copyFor(lang)}>
      <Gate onLanguage={() => setLang(lang === "en" ? "ar" : "en")} />
    </CopyContext.Provider>
  );
}

function Gate({ onLanguage }: { onLanguage: () => void }) {
  const session = useSession();
  const route = useRoute();
  if (session === undefined) return <p className="state">…</p>;
  if (route.name === "callback") {
    // The library has exchanged the code by now; a failure leaves no session.
    if (session) return <Redirect to={{ name: "home" }} />;
    const params = new URLSearchParams(location.search);
    return (
      <SignIn
        error={params.get("error") === "access_denied" ? "cancelled" : "failed"}
      />
    );
  }
  if (!session) return <SignIn />;
  return (
    <SignedIn
      route={route}
      me={session.user.id}
      email={session.user.email ?? null}
      onLanguage={onLanguage}
    />
  );
}

function SignedIn({ route, me, email, onLanguage }: {
  route: Route;
  me: string;
  email: string | null;
  onLanguage: () => void;
}) {
  const orgs = useLoad(
    async () => ({ ...(await api.orgs()), ...(await api.myInvites()) }),
    "orgs",
  );
  return (
    <Loader value={orgs} onRetry={orgs.reload}>
      {(data) => {
        if (route.name === "new") {
          return <CreateSchool email={email} onCreated={orgs.reload} />;
        }
        const live = data.orgs.filter((o) => o.status !== "closed");
        if (!("org" in route)) {
          const first = live[0];
          if (first) {return (
              <Redirect to={{ name: "dashboard", org: first.id }} />
            );}
          return <Welcome invites={data.invites} onJoined={orgs.reload} />;
        }
        const org = live.find((o) => o.id === route.org);
        if (!org) return <Redirect to={{ name: "home" }} />;
        const section = route.name === "teachers" || route.name === "settings"
          ? route.name
          : route.name === "dashboard"
          ? "dashboard"
          : "classes";
        return (
          <Shell
            org={org}
            orgs={live}
            section={section}
            onLanguage={onLanguage}
          >
            {route.name === "dashboard" && <Dashboard org={org.id} />}
            {route.name === "teachers" && <Teachers org={org.id} />}
            {route.name === "classes" && <Classes org={org.id} />}
            {route.name === "class" && (
              <ClassPage
                org={org.id}
                classroom={route.classroom}
                tab={route.tab}
              />
            )}
            {route.name === "handIns" && (
              <HandInsPage
                org={org.id}
                classroom={route.classroom}
                assignment={route.assignment}
              />
            )}
            {route.name === "answers" && (
              <AnswersPage
                org={org.id}
                classroom={route.classroom}
                test={route.test}
              />
            )}
            {route.name === "settings" && (
              <Settings org={org} me={me} onChange={orgs.reload} />
            )}
          </Shell>
        );
      }}
    </Loader>
  );
}
