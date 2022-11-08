import { test, expect } from '@playwright/test';

const loadMockVideo = async (page) => {
  await page.addInitScript(() => { window._mockVideoID = 'VIDEO_ID'; });
  await page.goto('/youtube_player_template.html');
}

const waitFor = delay => { new Promise(resolve => setTimeout(resolve, delay)) };

test('iframe loaded with valid video id', async ({ page }) => {
  await loadMockVideo(page);
  await expect(page.locator('iframe')).toHaveAttribute('src','https://www.youtube-nocookie.com/embed/VIDEO_ID?iv_load_policy=1&autoplay=1&rel=0&modestbranding=1');
});

test('error shown with invalid video id', async ({ page }) => {
  await page.addInitScript(() => { window._mockVideoID = '€%dd#"'; });
  await page.goto('/youtube_player_template.html');

  await expect(page.locator('.player-error')).toBeVisible();
  await expect(page.locator('.player-error')).toHaveText('ERROR: Invalid video id');
  await expect(page.locator('iframe')).toHaveCount(0);
});

test('inactivity timer shows and hides toolbar based on user activity', async ({ page }) => {
  await loadMockVideo(page);

  // 1. Expect toolbar to be visible at page load
  await expect(page.locator('.content-body')).not.toHaveCSS('opacity', '0');
  await page.mouse.move(1,1);

  // 2. Expect it to be hidden after 2 seconds of inactivity
  await waitFor(2000);
  await expect(page.locator('.content-body')).toHaveCSS('opacity', '0');

  // 3. Expect it to be shown if there is mouse activity
  await page.mouse.move(10, 10);
  await waitFor(500);
  await expect(page.locator('.content-body')).not.toHaveCSS('opacity', '0');
});

test('tooltip shown on hover', async ({ page }) => {
  await loadMockVideo(page);

  // 1. Show tooltip on hover of info icon
  await page.locator('.info-icon-container svg').hover();
  await expect(page.locator('.info-tooltip')).toBeVisible();

  // 2. Hide tooltip when mouse leaves
  await page.mouse.move(1,1);
  await expect(page.locator('.info-tooltip')).toBeHidden();

});

test('click on settings cog', async ({ page, context }) => {
  await loadMockVideo(page);

  const [newPage] = await Promise.all([
    context.waitForEvent('page'),
    page.locator('.open-settings').click()
  ])
  await newPage.waitForLoadState();
  await expect(newPage).toHaveURL('about:preferences/duckplayer');

});

test('click on open in YouTube', async ({ page }) => {
  await loadMockVideo(page);
  await page.locator('.play-on-youtube').click()
  await expect(page).toHaveURL('https://www.youtube.com/watch?v=VIDEO_ID');
});

test('always open setting', async ({ page }) => {
  const loadMockVideoAndSetting = async (page) => {
    await page.addInitScript(() => {
      window.webkit = {
        messageHandlers: {
          setAlwaysOpenSettingTo: {
            postMessage: (value) => {
              window._setAlwaysOpenSettingToMock = value;
            }
          }
        }
      };
    });
    await loadMockVideo(page);
  };

  const mockSendSettingFromNative = async (page, value) => {
    await page.evaluate((value) => {
      window.postMessage({ alwaysOpenSetting: value });
    }, value)
  }

  const getMockSettingSentToNative = async (page) => {
    return await page.evaluate(() => {
      return window._setAlwaysOpenSettingToMock;
    });
  }

  await loadMockVideoAndSetting(page);
  await mockSendSettingFromNative(page, false);

  // 1. Expect always open setting to be visible if it is turned OFF at page load
  await expect(page.locator('.setting')).toBeVisible();

  // 2. Expect the setting to slide out and be hidden and a message sent to native after clicking it.
  await page.locator('.setting input').click();
  await waitFor(1000);
  await expect(page.locator('.setting-container')).toHaveCSS('width', '0px');
  await expect(await getMockSettingSentToNative(page)).toEqual(true);

});
