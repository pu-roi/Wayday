import { test } from "node:test";
import assert from "node:assert/strict";
import { qualifiedRelease } from "../src/release.ts";

const valid = {
  qualified: true,
  version: "0.1.0+101",
  publishedAt: "2026-11-01T08:00:00Z",
  apkUrl:
    "https://github.com/pu-roi/Wayday/releases/download/dev-101/wayday.apk",
  notesUrl: "https://github.com/pu-roi/Wayday/releases/tag/dev-101",
  sizeBytes: 1024,
  sha256: "a".repeat(64),
  compatibility: "Release-qualified Android devices",
};
test("release is unavailable by default and without explicit qualification", () => {
  for (const input of [undefined, {}, { ...valid, qualified: false }, null]) {
    assert.equal(qualifiedRelease(input), null);
  }
});
test("a complete qualified release is available", () =>
  assert.deepEqual(qualifiedRelease(valid), valid));
test("incomplete, malformed and foreign download metadata fails closed", () => {
  for (const patch of [
    { sha256: "invalid" },
    { sizeBytes: -1 },
    { version: "" },
    { publishedAt: "yesterday" },
    { compatibility: "" },
    { apkUrl: "javascript:alert(1)" },
    { apkUrl: "https://github.com/other/repo/releases/download/a/wayday.apk" },
    { notesUrl: "https://example.org/notes" },
    { apkUrl: valid.apkUrl + "?token=secret" },
  ])
    assert.equal(qualifiedRelease({ ...valid, ...patch }), null);
});
