import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const web = resolve(import.meta.dirname, '../../../../services/api/src/wayday_api/gateway/share_web');
const id = 'fd720d83-5d17-41f9-8a4d-d7c99d9a2f45';
const token = 'a'.repeat(43);
const origin = 'https://share.wayday.test';
const fixture = () => ({
  expiresAt: Math.floor(Date.now() / 1000) + 7200, revision: 0,
  ownerSharing: false, ownerLocation: null,
  snapshot: {
    version: 1, sourceId: 'browser-fixture', completed: ['one'],
    start: { latitude: 14.56, longitude: 121.08, label: 'Start' },
    destination: { latitude: 14.58, longitude: 121.09, label: 'Destination' },
    route: [[14.56, 121.08], [14.565, 121.081], [14.58, 121.09]],
    stops: [
      { id: 'one', title: 'Bumili ng pagkain para sa buong pamilya', place: 'Confirmed market', latitude: 14.565, longitude: 121.081 },
      { id: 'two', title: 'Pick up parcel', place: 'Confirmed pickup point', latitude: 14.57, longitude: 121.085 },
    ],
  },
});

async function serve(page: import('@playwright/test').Page, data = fixture(), status = 200) {
  await page.route(origin + '/**', async route => {
    const url = new URL(route.request().url());
    if (url.pathname === '/v1/shares/' + id) {
      expect(route.request().headers().authorization).toBe('Bearer ' + token);
      expect(url.search).toBe('');
      await route.fulfill({ status, json: status === 200 ? data : { error: { code: 'share_unavailable' } } });
    } else if (url.pathname === '/share/config') {
      await route.fulfill({ json: { mapsKey: '', package: 'dev.wayday.wayday' } });
    } else {
      const asset = url.pathname === '/share/' || url.pathname === '/pair/' ? 'index.html' : url.pathname.replace('/share/', '');
      const types: Record<string, string> = { 'index.html': 'text/html', 'viewer.js': 'text/javascript', 'viewer.css': 'text/css', 'assets/Figtree.ttf': 'font/ttf', 'assets/wayday-logo.png': 'image/png' };
      await route.fulfill({ body: readFileSync(resolve(web, asset)), contentType: types[asset] ?? 'text/plain' });
    }
  });
}

for (const width of [320, 390, 1200]) {
  test(`shared trip follows Wayday layout at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 844 });
    await serve(page);
    await page.goto(`${origin}/share/#${id}.${token}`);
    await expect(page.getByRole('heading', { name: 'Shared trip' })).toBeVisible();
    await expect(page.getByText('1 of 2 done')).toBeVisible();
    await expect(page.getByText('Confirmed pickup point')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Retry map' })).toBeVisible();
    await expect(page.getByText('Live location is off.')).toBeVisible();
    await expect(page.getByRole('link', { name: 'Download app' })).toHaveAttribute('href', 'https://pu-roi.github.io/Wayday/#download');
    await expect(page.getByRole('link', { name: 'Open app' })).toHaveAttribute('href', /intent:\/\/share\.wayday\.test\/share\//);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    if (width === 390 && process.env.WAYDAY_SHARE_SCREENSHOTS) {
      await page.screenshot({ path: resolve(import.meta.dirname, '../../../../.tools/sharing-viewer.png'), fullPage: true });
    }
  });
}

test('expired shares clear private itinerary and location', async ({ page }) => {
  await serve(page, fixture(), 404);
  await page.goto(`${origin}/share/#${id}.${token}`);
  await expect(page.getByRole('heading', { name: 'This trip is unavailable' })).toBeVisible();
  await expect(page.getByText('Confirmed pickup point')).toHaveCount(0);
});

test('pairing invitation requires app consent and contains no itinerary', async ({ page }) => {
  await serve(page);
  await page.goto(`${origin}/pair/#${id}.${token}`);
  await expect(page.getByRole('heading', { name: 'Share your location back' })).toBeVisible();
  await expect(page.getByText('Confirmed pickup point')).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Open app' })).toBeVisible();
});

test('trip expiring while open removes its itinerary', async ({ page }) => {
  const data = fixture(); data.expiresAt = Math.floor(Date.now() / 1000) + 2;
  await serve(page, data);
  await page.goto(`${origin}/share/#${id}.${token}`);
  await expect(page.getByText('Confirmed pickup point')).toBeVisible();
  await expect(page.getByRole('heading', { name: 'This trip is unavailable' })).toBeVisible({ timeout: 5000 });
});
