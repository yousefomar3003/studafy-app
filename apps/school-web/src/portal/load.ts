import { useCallback, useEffect, useRef, useState } from "react";
import { ApiError } from "./api";

export type Loaded<T> =
  | { state: "loading" }
  | { state: "error"; code: string }
  | { state: "ok"; data: T };

/**
 * Runs [load] when [key] changes; `reload` runs it again. A reload keeps
 * what is shown until the new data arrives, so the page (and any message
 * on it, such as "Invitation sent") stays; a new key starts from loading.
 */
export function useLoad<T>(
  load: () => Promise<T>,
  key: string,
): Loaded<T> & { reload: () => void } {
  const [value, setValue] = useState<Loaded<T>>({ state: "loading" });
  const [tick, setTick] = useState(0);
  const shownKey = useRef<string | null>(null);
  useEffect(() => {
    let live = true;
    const sameKey = shownKey.current === key;
    shownKey.current = key;
    setValue((current) =>
      sameKey && current.state === "ok" ? current : { state: "loading" }
    );
    load().then(
      (data) => live && setValue({ state: "ok", data }),
      (error) =>
        live &&
        setValue({
          state: "error",
          code: error instanceof ApiError ? error.code : "INTERNAL_ERROR",
        }),
    );
    return () => {
      live = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, tick]);
  const reload = useCallback(() => setTick((n) => n + 1), []);
  return { ...value, reload };
}
