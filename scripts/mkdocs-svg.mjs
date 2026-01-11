import { spawnSync } from "node:child_process";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

export function runMkdocsSvg({ spawn = spawnSync, env = process.env } = {}) {
  const mergedEnv = { ...env, RENDER_SVG: "1" };

  return spawn("uv", ["run", "mkdocs", "build"], {
    env: mergedEnv,
    shell: true,
    stdio: "inherit",
  });
}

const isMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isMain) {
  const result = runMkdocsSvg();
  process.exit(result.status ?? 1);
}
