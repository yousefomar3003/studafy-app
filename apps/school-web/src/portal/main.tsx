import "@fontsource-variable/inter";
import "@fontsource/ibm-plex-sans-arabic/400.css";
import "@fontsource/ibm-plex-sans-arabic/600.css";
import "@fontsource/ibm-plex-sans-arabic/700.css";
import "../styles/base.css";
import "./portal.css";

import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { Portal } from "./Portal";

const root = document.getElementById("root");
if (root) {
  createRoot(root).render(
    <StrictMode>
      <Portal />
    </StrictMode>,
  );
}
