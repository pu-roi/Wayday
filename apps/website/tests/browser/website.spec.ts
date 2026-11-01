import { test, expect } from "@playwright/test";

for (const width of [320, 360, 390, 638, 768, 1024, 1440]) {
  test(`readable production page and working assets at ${width}px`, async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.setViewportSize({ width, height: 900 });
    await page.goto("");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect(page.locator("#release-panel")).toHaveText(
      "Download coming soon",
    );
    expect(await page.locator("#release-panel a").count()).toBe(0);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
    expect(
      await page
        .locator("img")
        .evaluateAll((images) =>
          images.every(
            (i) =>
              (i as HTMLImageElement).complete &&
              (i as HTMLImageElement).naturalWidth > 0,
          ),
        ),
    ).toBe(true);
    await page.locator('.hero-actions a[href="#how-it-works"]').click();
    await expect(page).toHaveURL(/#how-it-works$/);
    await expect(page.locator("#how-it-works")).toBeFocused();
    await expect
      .poll(() =>
        page
          .locator("#how-it-works")
          .evaluate((e) => e.getBoundingClientRect().top),
      )
      .toBeLessThan(120);
    expect(
      await page
        .locator("#how-it-works")
        .evaluate((e) => e.getBoundingClientRect().top),
    ).toBeGreaterThan(75);
    await expect(
      page.getByRole("link", { name: "Back to top", exact: true }),
    ).toBeVisible();
    await page.getByRole("link", { name: "Back to top", exact: true }).click();
    await expect(page).toHaveURL(/#top$/);
    await expect
      .poll(() => page.evaluate(() => window.scrollY))
      .toBeLessThan(2);
    if (width <= 960) {
      await page.getByRole("button", { name: /Menu/ }).click();
      await expect(page.locator("#main-nav")).toBeVisible();
      await page.keyboard.press("Escape");
      await expect(page.getByRole("button", { name: /Menu/ })).toBeFocused();
      await expect(page.locator("#main-nav")).not.toBeVisible();
    }
    expect(errors).toEqual([]);
  });
}
test("reduced motion, direct hashes and browser history remain usable", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("#requirements");
  await expect
    .poll(() =>
      page
        .locator("#requirements")
        .evaluate((e) => Math.abs(e.getBoundingClientRect().top - 108)),
    )
    .toBeLessThan(25);
  await page.locator('.site-header a[href="#features"]').click();
  await expect(page).toHaveURL(/#features$/);
  await page.goBack();
  await expect(page).toHaveURL(/#requirements$/);
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect(page.getByRole("heading", { name: /Your phone/ })).toBeVisible();
});
