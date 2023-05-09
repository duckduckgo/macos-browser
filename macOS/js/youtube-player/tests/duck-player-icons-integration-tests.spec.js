import { test, expect } from '@playwright/test';
import { setupIconOverlays } from './utils.js';
import { IconOverlayPage } from './IconOverlayPageObject.js';

const setupMockIconOverlays = async (page) => {
  return setupIconOverlays(page, 'https://www.youtube.com/', true);
}

test('thumbnail hover', async ({ page }) => {
  await setupMockIconOverlays(page);

  // 1. Hover overlay hidden at page load
  await expect(IconOverlayPage.hoverOverlay(page)).toBeHidden();

  // 2. Hover overlay shown when hovering 1st thumbnail
  await IconOverlayPage.thumbnail(page, 'THUMBNAILS', 1).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();

  // 3. Expect hover overlay to be hidden when moving mouse away
  await IconOverlayPage.moveMouseAway(page);
  await expect(IconOverlayPage.hoverOverlay(page)).toBeHidden();

  // 4. Hover overlay to be shown when hovering 2nd thumbnail
  await IconOverlayPage.thumbnail(page, 'THUMBNAILS', 2).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();

  // 5. Hover overlay to be shown when hovering 3rd thumbnail
  await IconOverlayPage.thumbnail(page, 'THUMBNAILS', 3).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();

  // 6. Wait for new content to be added and make sure hover overlay is shown when hovering it
  await IconOverlayPage.thumbnail(page, 'LOADED_THUMBNAILS', 1).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();

  // 7. Make sure hover also works for 2nd loaded thumbnails
  await IconOverlayPage.moveMouseAway(page);
  await IconOverlayPage.thumbnail(page, 'LOADED_THUMBNAILS', 2).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();

});

test('playlist thumbnail hover', async ({ page }) => {
  await setupMockIconOverlays(page);

  // 1. Hover overlay hidden at page load
  await expect(IconOverlayPage.hoverOverlay(page)).toBeHidden();

  // 2. Hover overlay shown when hovering 1st thumbnail in playlist
  await IconOverlayPage.thumbnail(page, 'PLAYLIST', 1).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();

  // 3. Expect hover overlay to be hidden when moving mouse away
  await IconOverlayPage.moveMouseAway(page);
  await expect(IconOverlayPage.hoverOverlay(page)).toBeHidden();

  // 4. Hover overlay to be shown when hovering 2nd thumbnail
  await IconOverlayPage.thumbnail(page, 'PLAYLIST', 2).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();

  // 5. Hover overlay to be shown when hovering 3rd thumbnail
  await IconOverlayPage.thumbnail(page, 'PLAYLIST', 3).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();
});

test('hovering overlay itself', async ({ page }) => {
  await setupMockIconOverlays(page);

  // 1. Hover overlay hidden at page load
  await expect(IconOverlayPage.hoverOverlay(page)).toBeHidden();

  // 2. Hover overlay shown when hovering 1st thumbnail
  await IconOverlayPage.thumbnail(page, 'THUMBNAILS', 1).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();

  // 3. Hover the overlay itself
  await IconOverlayPage.hoverOverlay(page).hover();
  await expect(IconOverlayPage.hoverOverlayLink(page)).toHaveCSS('width', '80px');

  // 4. Hover the thumbnail again, overlaylink to be hidden
  await IconOverlayPage.thumbnail(page, 'THUMBNAILS', 1).hover();
  await expect(IconOverlayPage.hoverOverlayLink(page)).toHaveCSS('width', '0px');

  // 5. Hovering the overlay in the playlist should NOT show the overlay link
  await IconOverlayPage.thumbnail(page, 'PLAYLIST', 1).hover();
  await expect(IconOverlayPage.hoverOverlay(page)).toBeVisible();
  await IconOverlayPage.hoverOverlay(page).hover();
  await expect(IconOverlayPage.hoverOverlayLink(page)).toHaveCSS('width', '0px');

});
