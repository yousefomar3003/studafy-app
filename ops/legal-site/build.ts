// Builds ops/legal-site/public from docs/legal. wrangler runs this before
// every deploy ([build] in wrangler.toml); `bun ops/legal-site/build.ts`
// runs it by hand.

import { join } from "node:path";
import { build } from "./src/site.ts";

const here = import.meta.dirname ?? ".";
const written = build({
  sourceDir: join(here, "..", "..", "docs", "legal"),
  outDir: join(here, "public"),
  stylesheet: join(here, "src", "styles.css"),
});
console.log(`legal-site: built ${written.join(", ")}`);
