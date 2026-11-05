import {
  createClient,
  type Session,
  type SupabaseClient,
} from "@supabase/supabase-js";
import { useEffect, useState } from "react";
import { portalConfig, type Provider } from "./config";
import { DEMO, demoSession } from "./demo";

const LAST_ACTIVE = "studafy.portal.lastActive";

let client: SupabaseClient | null = null;

/** One client per page; null when the build has no Supabase project. */
export function supabase(): SupabaseClient | null {
  if (client) return client;
  if (!portalConfig.supabaseUrl || !portalConfig.supabaseKey) return null;
  client = createClient(portalConfig.supabaseUrl, portalConfig.supabaseKey, {
    auth: {
      flowType: "pkce",
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
  return client;
}

export async function accessToken(): Promise<string | null> {
  const { data } = await supabase()?.auth.getSession() ??
    { data: { session: null } };
  return data.session?.access_token ?? null;
}

/** Starts sign-in with a provider; the browser comes back to /auth/callback. */
export async function signIn(provider: Provider, base: string): Promise<void> {
  const auth = supabase()?.auth;
  if (!auth) throw new Error("NOT_CONFIGURED");
  const { error } = await auth.signInWithOAuth({
    provider,
    options: {
      redirectTo: `${location.origin}${base}/auth/callback`,
      // Microsoft gives the email only when asked for it.
      ...(provider === "azure" ? { scopes: "email" } : {}),
    },
  });
  if (error) throw error;
}

/** Ends the session and forgets everything this site kept in the browser. */
export async function signOut(): Promise<void> {
  if (DEMO) return;
  try {
    await supabase()?.auth.signOut();
  } finally {
    try {
      for (const key of Object.keys(localStorage)) {
        if (key.startsWith("sb-") || key.startsWith("studafy.portal.")) {
          localStorage.removeItem(key);
        }
      }
      sessionStorage.clear();
    } catch { /* storage may be blocked; the session is already ended */ }
  }
}

/** Records activity; a session idle for 12 hours ends (plan 7.6). */
export function touch(): void {
  try {
    localStorage.setItem(LAST_ACTIVE, String(Date.now()));
  } catch { /* blocked storage: the server's own expiry still applies */ }
}

function idleTooLong(): boolean {
  try {
    const last = Number(localStorage.getItem(LAST_ACTIVE) ?? "0");
    return last > 0 && Date.now() - last > portalConfig.idleLimitMs;
  } catch {
    return false;
  }
}

/** Apple's "Hide My Email" relay: teachers would see no real address. */
export function isHiddenEmail(email: string | undefined | null): boolean {
  return (email ?? "").toLowerCase().endsWith("@privaterelay.appleid.com");
}

/** The session, or null when signed out; undefined while still unknown. */
export function useSession(): Session | null | undefined {
  const [session, setSession] = useState<Session | null | undefined>(
    DEMO ? (demoSession as unknown as Session) : undefined,
  );
  useEffect(() => {
    if (DEMO) return;
    const auth = supabase()?.auth;
    if (!auth) {
      setSession(null);
      return;
    }
    let live = true;
    void (async () => {
      if (idleTooLong()) await signOut();
      const { data } = await auth.getSession();
      if (live) setSession(data.session);
      if (data.session) touch();
    })();
    const { data } = auth.onAuthStateChange((_event, next) => {
      if (live) setSession(next);
      if (next) touch();
    });
    return () => {
      live = false;
      data.subscription.unsubscribe();
    };
  }, []);
  return session;
}
