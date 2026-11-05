import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  build: {
    // Fonts and images stay files: the Content-Security-Policy allows no
    // data: fonts, and a file can be cached for a year.
    assetsInlineLimit: 0,
    sourcemap: false,
  },
});
