import assert from "node:assert/strict";
import test from "node:test";

import { runMkdocsPdf } from "./mkdocs-pdf.mjs";

test("runMkdocsPdf sets MKDOCS_PDF and calls uv", () => {
  let called = null;
  const spawn = (command, args, options) => {
    called = { command, args, options };
    return { status: 0 };
  };
  const env = { PATH: "x" };

  runMkdocsPdf({ spawn, env });

  assert.equal(called.command, "uv");
  assert.deepEqual(called.args, ["run", "mkdocs", "build"]);
  assert.equal(called.options.shell, true);
  assert.equal(called.options.env.MKDOCS_PDF, "1");
  assert.equal(called.options.env.PATH, "x");
});
