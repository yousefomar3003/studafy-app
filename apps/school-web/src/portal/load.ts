import { useCallback, useEffect, useState } from "react";
import { ApiError } from "./api";

export type Loaded<T> =
  | { state: "loading" }
  | { state: "error"; code: string }
  | { state: "ok"; data: T };

/** Runs [load] when [key] changes; `reload` runs it again. */
export function useLoad<T>(
  load: () => Promise<T>,
  key: string,
): Loaded<T> & { reload: () => void } {
  const [value, setValue] = useState<Loaded<T>>({ state: "loading" });
  const [tick, setTick] = useState(0);
  useEffect(() => {
    let live = true;
    setValue({ state: "loading" });
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
