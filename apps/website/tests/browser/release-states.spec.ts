import { test, expect } from "@playwright/test";
import { execFileSync, spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

test("qualified and incomplete release metadata produce honest download states", async ({
  page,
}) => {
  const fixture = {
    qualified: true,
    version: "0.1.0+101",
    publishedAt: "2026-11-01T08:00:00Z",
    apkUrl:
      "https://github.com/pu-roi/Wayday/releases/download/dev-101/wayday.apk",
    notesUrl: "https://github.com/pu-roi/Wayday/releases/tag/dev-101",
    sizeBytes: 1024,
    sha256: "a".repeat(64),
    compatibility: "Fixture compatibility, not public qualification",
  };
  for (const complete of [true, false]) {
    const folder = resolve(`.qa/${complete ? "available" : "incomplete"}`);
    mkdirSync(folder, { recursive: true });
    const metadata = resolve(folder, "release.json");
    writeFileSync(
      metadata,
      JSON.stringify({ ...fixture, sha256: complete ? fixture.sha256 : "" }),
    );
    execFileSync(
      process.execPath,
      ["node_modules/vite/bin/vite.js", "build", "--outDir", `${folder}/dist`],
      {
        env: { ...process.env, WAYDAY_RELEASE_FILE: metadata },
        stdio: "pipe",
      },
    );
    const server = spawn(
      process.execPath,
      [
        "node_modules/vite/bin/vite.js",
        "preview",
        "--outDir",
        `${folder}/dist`,
        "--port",
        "4174",
        "--strictPort",
        "--host",
        "127.0.0.1",
      ],
      { stdio: "pipe", windowsHide: true },
    );
    try {
      await expect
        .poll(async () => {
          try {
            return (await fetch("http://127.0.0.1:4174/Wayday/")).status;
          } catch {
            return 0;
          }
        })
        .toBe(200);
      await page.goto("http://127.0.0.1:4174/Wayday/");
      if (complete) {
        await expect(page.locator("#release-panel a.button")).toHaveAttribute(
          "href",
          fixture.apkUrl,
        );
        await expect(page.locator("#release-panel")).toContainText(
          fixture.compatibility,
        );
        await expect(page.locator("#availability-summary")).toContainText(
          "is available",
        );
        await expect(page.locator(".download-status")).toHaveText(
          "Public development release",
        );
      } else {
        await expect(page.locator("#release-panel")).toHaveText(
          "Download coming soon",
        );
        await expect(page.locator("#release-panel a")).toHaveCount(0);
      }
    } finally {
      server.kill();
      await new Promise<void>((resolveExit) =>
        server.once("exit", () => resolveExit()),
      );
    }
  }
});
