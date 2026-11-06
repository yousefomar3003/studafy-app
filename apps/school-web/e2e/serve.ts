// Serves dist/ for the browser tests the way Vercel does for this site:
// /features is dist/features/index.html, a file is itself, and anything
// else is the 404 page (Arabic under /ar) with status 404. `vite preview`
// would answer every unknown path with the English home page instead.

import { statSync } from "node:fs";
import { join, normalize } from "node:path";

const root = join(import.meta.dirname, "..", "dist");
const port = Number(process.argv[2] ?? 5180);

function file(path: string): Response | null {
  try {
    return statSync(path).isFile() ? new Response(Bun.file(path)) : null;
  } catch {
    return null;
  }
}

Bun.serve({
  hostname: "127.0.0.1",
  port,
  fetch(request) {
    const path = normalize(decodeURIComponent(new URL(request.url).pathname));
    if (path.includes("..")) {
      return new Response("Bad request", { status: 400 });
    }
    const found = file(join(root, path)) ??
      file(join(root, path, "index.html"));
    if (found) return found;
    const notFound = path === "/ar" || path.startsWith("/ar/")
      ? "ar/404.html"
      : "404.html";
    return new Response(Bun.file(join(root, notFound)), {
      status: 404,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  },
});
console.log(`site on http://127.0.0.1:${port}`);
