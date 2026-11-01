import { test, expect } from "@playwright/test";

for (const width of [638, 1440]) {
  test(`opening has substantial reversible scale, rotation and note travel at ${width}px`, async ({
    page,
  }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("");
    const pose = () =>
      page.locator(".phone-motion").evaluate((e) => {
        const m = new DOMMatrixReadOnly(getComputedStyle(e).transform);
        return {
          scale: Math.hypot(m.a, m.b),
          rotation: (Math.atan2(m.b, m.a) * 180) / Math.PI,
        };
      });
    await expect.poll(async () => (await pose()).scale).toBeCloseTo(0.8, 1);
    const first = await pose();
    const noteStart = await page
      .locator(".slip-one")
      .evaluate(
        (e) => new DOMMatrixReadOnly(getComputedStyle(e).transform).m41,
      );
    await page.evaluate(() =>
      window.scrollTo({ top: 850, behavior: "instant" }),
    );
    await expect
      .poll(async () => (await pose()).scale - first.scale)
      .toBeGreaterThan(0.3);
    await expect
      .poll(async () => (await pose()).rotation - first.rotation)
      .toBeGreaterThan(15);
    await expect
      .poll(() =>
        page
          .locator(".slip-one")
          .evaluate(
            (e) => new DOMMatrixReadOnly(getComputedStyle(e).transform).m41,
          ),
      )
      .toBeGreaterThan(noteStart + 90);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
    await page.evaluate(() => window.scrollTo({ top: 0, behavior: "instant" }));
    await expect
      .poll(async () => Math.abs((await pose()).scale - first.scale))
      .toBeLessThan(0.02);
    await expect
      .poll(async () => Math.abs((await pose()).rotation - first.rotation))
      .toBeLessThan(1);
  });
}

test("lower chapters have broad reveals and a scroll-linked reuse rotation", async ({
  page,
}) => {
  await page.setViewportSize({ width: 638, height: 900 });
  await page.goto("");
  const top = await page
    .locator(".feature-lead")
    .evaluate((e) => e.getBoundingClientRect().top + scrollY);
  await page.evaluate(
    (y) => window.scrollTo({ top: y - 900, behavior: "instant" }),
    top,
  );
  const noteScale = () =>
    page.locator(".detail-preview").evaluate((e) => {
      const m = new DOMMatrixReadOnly(getComputedStyle(e).transform);
      return Math.hypot(m.a, m.b);
    });
  const before = await noteScale();
  await page.evaluate(
    (y) => window.scrollTo({ top: y - 150, behavior: "instant" }),
    top,
  );
  await expect
    .poll(async () => (await noteScale()) - before)
    .toBeGreaterThan(0.15);
  const reuse = await page
    .locator(".reuse-row")
    .evaluate((e) => e.getBoundingClientRect().top + scrollY);
  const rotation = () =>
    page.locator(".reuse-wheel").evaluate((e) => {
      const m = new DOMMatrixReadOnly(getComputedStyle(e).transform);
      return (Math.atan2(m.b, m.a) * 180) / Math.PI;
    });
  await page.evaluate(
    (y) => window.scrollTo({ top: y - 650, behavior: "instant" }),
    reuse,
  );
  let angle = 0;
  await expect
    .poll(async () => {
      angle = await rotation();
      return Number.isFinite(angle);
    })
    .toBe(true);
  await page.evaluate(
    (y) => window.scrollTo({ top: y - 100, behavior: "instant" }),
    reuse,
  );
  await expect
    .poll(async () => Math.abs((await rotation()) - angle))
    .toBeGreaterThan(35);
});

test("reduced motion removes choreography and short viewports do not pin the opening", async ({
  page,
}) => {
  await page.setViewportSize({ width: 638, height: 900 });
  await page.goto("");
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect(page.locator("html")).not.toHaveClass(/has-motion/);
  expect(
    await page
      .locator(".steps li")
      .first()
      .evaluate((e) => getComputedStyle(e).position),
  ).toBe("relative");
  expect(
    await page
      .locator(".hero-stage")
      .evaluate((e) => getComputedStyle(e).position),
  ).toBe("relative");
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await page.setViewportSize({ width: 844, height: 390 });
  expect(
    await page
      .locator(".hero-stage")
      .evaluate((e) => getComputedStyle(e).position),
  ).toBe("relative");
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
});

test("without JavaScript, navigation and product content remain available", async ({
  browser,
}) => {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 390, height: 844 },
  });
  const page = await context.newPage();
  await page.goto("http://127.0.0.1:4173/Wayday/");
  await expect(page.locator("#main-nav")).toBeVisible();
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  await page.locator('#main-nav a[href="#download"]').click();
  await expect(page).toHaveURL(/#download$/);
  await expect(page.locator("#release-panel")).toHaveText(
    "Download coming soon",
  );
  await context.close();
});
