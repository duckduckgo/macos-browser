import { test, expect } from '@playwright/test';
import { setupIconOverlays, getClickedDuckPlayerLink } from './utils.js';

test('youtube homepage', async ({ page }) => {
  await setupIconOverlays(page);

  let firstHomepageVideoThumbnail = page.locator('ytd-rich-grid-renderer ytd-rich-grid-row:first-child ytd-rich-item-renderer:first-child #thumbnail'),
      hoverOverlay = page.locator('.ddg-overlay-hover'),
      previewOverlay = page.locator('#preview ddg-icon-overlay');

  // 1. Expect hover overlay shown on hovering thumbnail
  await firstHomepageVideoThumbnail.hover();
  await expect(hoverOverlay).toBeVisible();

  // 2. Once the preview animates in, expect the previewOverlay to be shown
  await expect(previewOverlay).toBeVisible();

  // 3. Clicking the preview overlay should open duck player
  await previewOverlay.hover();
  await previewOverlay.click();
  await expect(await getClickedDuckPlayerLink(page)).toEqual(await previewOverlay.getAttribute('href'));

});

test('youtube search', async ({ page }) => {
  await setupIconOverlays(page);

  await page.locator('input#search').click();
  await page.keyboard.type('duckduckgo', { delay: 100 });
  await page.keyboard.press('Enter');

  let hoverOverlay = page.locator('.ddg-overlay-hover');

  const getVideoResultThumbnail = num => {
    return 'ytd-section-list-renderer ytd-item-section-renderer #contents.ytd-item-section-renderer .ytd-item-section-renderer:nth-child('+num+') #thumbnail';
  }

  // 1. Hover first result, make sure hover overlay is visible
  await page.locator(getVideoResultThumbnail(1)).hover();
  await expect(hoverOverlay).toBeVisible();

  // 2. Move cursor away, make sure hover overlay is hidden
  await page.mouse.move(1,1);
  await expect(hoverOverlay).toBeHidden();


  // 3. Move cursor to 2nd result, make sure hover overlay is visible
  await page.locator(getVideoResultThumbnail(2)).hover();
  await expect(hoverOverlay).toBeVisible();

  // 4. Clicking the hover overlay should open the video in duck player
  await hoverOverlay.hover();
  await hoverOverlay.click();
  await expect(await getClickedDuckPlayerLink(page)).toEqual(await hoverOverlay.getAttribute('href'));
});

test('recommended videos', async ({ page }) => {
  await setupIconOverlays(page);

  let firstHomepageVideoThumbnail = page.locator('ytd-rich-grid-renderer ytd-rich-grid-row:first-child ytd-rich-item-renderer:first-child #thumbnail'),
      hoverOverlay = page.locator('.ddg-overlay-hover');

  const getRecommendedVideoThumbnail = num => {
    return '#playlist ~ #related #items ytd-compact-video-renderer:nth-child(' + num + ') #thumbnail';
  }

  // 1. Click the first video on the homepage
  await firstHomepageVideoThumbnail.click();

  // 2. Hover the first recommended video, make sure the overlay is shown
  await page.locator(getRecommendedVideoThumbnail(1)).hover();
  await expect(hoverOverlay).toBeVisible();

  // 3. Move mouse away, expect hoverOverlay to be hidden
  await page.mouse.move(1,1);
  await expect(hoverOverlay).toBeHidden();

  // 4. Hover the 2nd recommended video, make sure the overlay is shown
  await page.locator(getRecommendedVideoThumbnail(2)).hover();
  await expect(hoverOverlay).toBeVisible();

  // 5. Clicking the hover overlay should open the video in duck player
  await hoverOverlay.hover();
  await hoverOverlay.click();
  await expect(await getClickedDuckPlayerLink(page)).toEqual(await hoverOverlay.getAttribute('href'));

});

test('playlist', async ({ page }) => {
  await setupIconOverlays(page, 'https://www.youtube.com/watch?v=U0CGsw6h60k&list=PLMC9KNkIncKtPzgY-5rmhvj7fax8fdxoj');

  let hoverOverlay = page.locator('.ddg-overlay-hover'),
      hoverOverlayLink = page.locator('.ddg-overlay-hover a');

  const getPlaylistVideoThumbnail = num => {
    return '#secondary-inner > #playlist #items ytd-playlist-panel-video-renderer:nth-child(' + num + ') #thumbnail';
  }

  // 2. Hover the first playlist video, make sure the overlay is shown
  await page.locator(getPlaylistVideoThumbnail(1)).hover();
  await expect(hoverOverlay).toBeVisible();

  // 3. Move mouse away, expect hoverOverlay to be hidden
  await page.mouse.move(1,1);
  await expect(hoverOverlay).toBeHidden();

  // 4. Hover the 2nd recommended video, make sure the overlay is shown
  await page.locator(getPlaylistVideoThumbnail(2)).hover();
  await expect(hoverOverlay).toBeVisible();

  // 5. Clicking the hover overlay should open the video in duck player
  await hoverOverlay.hover();
  await hoverOverlay.click();

  await expect(hoverOverlayLink).toBeHidden();
  await expect(await getClickedDuckPlayerLink(page)).toEqual(await hoverOverlay.getAttribute('href'));
});
