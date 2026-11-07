import { resolve } from "node:path";
import react from "@vitejs/plugin-react";
import { defineConfig, type Plugin } from "vite";

/**
 * The dev server's stand-in for vercel.json's portal rewrite: any page
 * address under /portal/ serves the portal's one page.
 */
function portalPages(): Plugin {
  return {
    name: "studafy-portal-pages",
    configureServer(server) {
      server.middlewares.use((req, _res, next) => {
        const path = req.url?.split("?")[0] ?? "";
        if (path.startsWith("/portal/") && !path.slice(1).includes(".")) {
          req.url = "/portal/index.html";
        }
        next();
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), portalPages()],
  build: {
    // Fonts and images stay files: the Content-Security-Policy allows no
    // data: fonts, and a file can be cached for a year.
    assetsInlineLimit: 0,
    sourcemap: false,
    rollupOptions: {
      // The public pages (prerendered) and the School Portal (one page).
      input: {
        site: resolve(import.meta.dirname, "index.html"),
        portal: resolve(import.meta.dirname, "portal/index.html"),
      },
    },
  },
});
