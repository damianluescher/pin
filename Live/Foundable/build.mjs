// Builds Foundable's real window (its own src, imported by path) into dist/ as plain files Pin opens by file: address.
// Uses the build tools already in foundable-app's node_modules; writes nothing there.
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
const here = import.meta.dirname, app = path.resolve(here, "../../../foundable-app");
const load = f => import(pathToFileURL(path.join(app, "node_modules", f)).href);
const { build } = await load("vite/dist/node/index.js");
const { default: react } = await load("@vitejs/plugin-react/dist/index.js");
await build({
  configFile: false, root: here, base: "./", logLevel: "warn", cacheDir: path.join(here, ".cache"), plugins: [react()],
  build: {
    outDir: "dist", emptyOutDir: true, assetsInlineLimit: 0, cssCodeSplit: false, modulePreload: false,
    rollupOptions: {
      input: path.join(here, "src/entry.ts"),
      output: { format: "iife", entryFileNames: "app.js", assetFileNames: a => a.names?.[0]?.endsWith(".css") ? "assets/app.css" : "assets/[name][extname]" },
    },
  },
});
fs.copyFileSync(path.join(here, "index.html"), path.join(here, "dist/index.html"));
for (const f of ["app.js", "assets/app.css", "index.html"]) if (!fs.existsSync(path.join(here, "dist", f))) throw new Error("missing " + f);
