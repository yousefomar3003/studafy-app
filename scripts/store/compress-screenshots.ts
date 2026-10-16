/**
 * Makes the store screenshots uploadable and smaller: simulator pictures
 * carry an alpha channel, which App Store Connect refuses, and Google Play
 * asks for 24-bit PNG. This removes the alpha channel and recompresses
 * losslessly (about a third of the size). It uses sharp, which is not a
 * dependency of the repo:
 *
 *   bun add --no-save sharp@0.34
 *   bun scripts/store/compress-screenshots.ts [docs/store/screenshots/ios]
 */
import { readdirSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

type Sharp = {
  removeAlpha(): Sharp;
  png(options: Record<string, unknown>): Sharp;
  toBuffer(): Promise<Uint8Array>;
};
const { default: sharp } = await import("sharp" as string) as {
  default: (input: string) => Sharp;
};

const root = process.argv[2] ?? "docs/store/screenshots/ios";
let before = 0;
let after = 0;
for (const dir of readdirSync(root)) {
  const full = join(root, dir);
  if (!statSync(full).isDirectory()) continue;
  for (const name of readdirSync(full).filter((n) => n.endsWith(".png"))) {
    const file = join(full, name);
    before += statSync(file).size;
    const out = await sharp(file)
      .removeAlpha()
      .png({ compressionLevel: 9, effort: 10, adaptiveFiltering: true })
      .toBuffer();
    writeFileSync(file, out);
    after += out.length;
  }
}
console.log(
  `${(before / 1e6).toFixed(1)} MB -> ${(after / 1e6).toFixed(1)} MB`,
);
