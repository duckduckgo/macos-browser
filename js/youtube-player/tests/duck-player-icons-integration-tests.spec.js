import { test, expect } from '@playwright/test';
import { setupIconOverlays, sleep } from './utils.js';

const setupMockIconOverlays = async (page) => {
  return setupIconOverlays(page, '/icon-overlay-integration-test.html');
}

const thumbnail = (page, section, nthChild) => {
  return page.locator(`[data-testid="${section}"] #thumbnail:nth-child(${nthChild})`);
}

const hoverOverlay = (page) => {
  return page.locator('.ddg-overlay-hover');
}

const hoverOverlayLink = (page) => {
  return page.locator('.ddg-overlay-hover .ddg-play-text-container');
}

test('thumbnail hover', async ({ page }) => {
  await setupMockIconOverlays(page);

  // 1. Hover overlay hidden at page load
  await expect(hoverOverlay(page)).toBeHidden();

  // 2. Hover overlay shown when hovering 1st thumbnail
  await thumbnail(page, 'THUMBNAILS', 1).hover();
  await expect(hoverOverlay(page)).toBeVisible();

  // 3. Expect hover overlay to be hidden when moving mouse away
  await page.mouse.move(1,1);
  await expect(hoverOverlay(page)).toBeHidden();

  // 4. Hover overlay to be shown when hovering 2nd thumbnail
  await thumbnail(page, 'THUMBNAILS', 2).hover();
  await expect(hoverOverlay(page)).toBeVisible();

  // 5. Hover overlay to be shown when hovering 3rd thumbnail
  await thumbnail(page, 'THUMBNAILS', 3).hover();
  await expect(hoverOverlay(page)).toBeVisible();

  // 6. Wait for new content to be added and make sure hover overlay is shown when hovering it
  await sleep(1000);
  await thumbnail(page, 'LOADED_THUMBNAILS', 1).hover();
  await expect(hoverOverlay(page)).toBeVisible();

  // 7. Make sure hover also works for 2nd loaded thumbnails
  await page.mouse.move(1,1);
  await thumbnail(page, 'LOADED_THUMBNAILS', 2).hover();
  await expect(hoverOverlay(page)).toBeVisible();

});

test('playlist thumbnail hover', async ({ page }) => {
  await setupMockIconOverlays(page);

  // 1. Hover overlay hidden at page load
  await expect(hoverOverlay(page)).toBeHidden();

  // 2. Hover overlay shown when hovering 1st thumbnail in playlist
  await thumbnail(page, 'PLAYLIST', 1).hover();
  await expect(hoverOverlay(page)).toBeVisible();

  // 3. Expect hover overlay to be hidden when moving mouse away
  await page.mouse.move(1,1);
  await expect(hoverOverlay(page)).toBeHidden();

  // 4. Hover overlay to be shown when hovering 2nd thumbnail
  await thumbnail(page, 'PLAYLIST', 2).hover();
  await expect(hoverOverlay(page)).toBeVisible();

  // 5. Hover overlay to be shown when hovering 3rd thumbnail
  await thumbnail(page, 'PLAYLIST', 3).hover();
  await expect(hoverOverlay(page)).toBeVisible();
});
