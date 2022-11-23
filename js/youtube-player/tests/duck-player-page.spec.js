import { test, expect } from '@playwright/test';
import { DuckPlayerPage } from './DuckPlayerPageObject.js';

const MOCK_VIDEO_ID = 'VIDEO_ID';
const MOCK_IFRAME_SRC = 'https://www.youtube-nocookie.com/embed/'+MOCK_VIDEO_ID+'?iv_load_policy=1&autoplay=1&rel=0&modestbranding=1';

const loadMockVideo = async (page, videoID = MOCK_VIDEO_ID, timestamp) => {
  await page.addInitScript((videoID) => { window._mockVideoID = videoID; }, videoID);
  await page.goto('/youtube_player_template.html' + (timestamp ? '?t='+timestamp : ''));
}

Object.entries({
  '2h3m1s': 7381,
  '5m20s': 320,
  '50s': 50,
  '1h2m': 3720
}).forEach(
  ([ timestamp, seconds ]) => {
    test(`timestamp: ${timestamp} should output ${seconds}`, async ({ page }) => {
      await loadMockVideo(page, 'VIDEO_ID', timestamp);
      await expect(DuckPlayerPage.videoIframe(page)).toHaveAttribute('src', MOCK_IFRAME_SRC + '&start='+seconds);
    });
  }
);

test('iframe loaded with invalid timestamp', async ({ page }) => {
  await loadMockVideo(page, 'VIDEO_ID', 'aaaqkw');
  await expect(DuckPlayerPage.videoIframe(page)).toHaveAttribute('src', MOCK_IFRAME_SRC);
});

test('iframe loaded with valid video id', async ({ page }) => {
  await loadMockVideo(page);
  await expect(DuckPlayerPage.videoIframe(page)).toHaveAttribute('src', MOCK_IFRAME_SRC);
});

test('error shown with invalid video id', async ({ page }) => {
  await page.addInitScript(() => { window._mockVideoID = '€%dd#"'; });
  await page.goto('/youtube_player_template.html');

  await expect(DuckPlayerPage.playerError(page)).toBeVisible();
  await expect(DuckPlayerPage.playerError(page)).toHaveText('ERROR: Invalid video id');
  await expect(DuckPlayerPage.videoIframe(page)).toHaveCount(0);
});

test('inactivity timer shows and hides toolbar based on user activity', async ({ page }) => {
  await loadMockVideo(page);

  // 1. Expect toolbar to be visible at page load
  await expect(DuckPlayerPage.toolbar(page)).not.toHaveCSS('opacity', '0');
  await DuckPlayerPage.moveMouseOutOfContent(page);

  // 2. Expect it to be hidden after 2 seconds of inactivity
  await expect(DuckPlayerPage.toolbar(page)).toHaveCSS('opacity', '0');

  // 3. Expect it to be shown if there is mouse activity
  await DuckPlayerPage.moveMouseToNewPositionOutsideOfContent(page);
  await expect(DuckPlayerPage.toolbar(page)).not.toHaveCSS('opacity', '0');
});

test('tooltip shown on hover', async ({ page }) => {
  await loadMockVideo(page);

  // 1. Show tooltip on hover of info icon
  await DuckPlayerPage.infoIcon(page).hover();
  await expect(DuckPlayerPage.infoTooltip(page)).toBeVisible();

  // 2. Hide tooltip when mouse leaves
  await DuckPlayerPage.moveMouseOutOfContent(page);
  await expect(DuckPlayerPage.infoTooltip(page)).toBeHidden();

});

test('click on settings cog', async ({ page, context }) => {
  await loadMockVideo(page);

  const [newPage] = await Promise.all([
    context.waitForEvent('page'),
    DuckPlayerPage.settingsCog(page).click()
  ])
  await newPage.waitForLoadState();
  await expect(newPage).toHaveURL('about:preferences/duckplayer');

});

test('click on open in YouTube', async ({ page }) => {
  await loadMockVideo(page);
  await DuckPlayerPage.playOnYouTubeButton(page).click()
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
  await expect(DuckPlayerPage.settingsContainer(page)).toBeVisible();

  // 2. Expect the setting to slide out and be hidden and a message sent to native after clicking it.
  await DuckPlayerPage.settingsCheckbox(page).click();
  await expect(DuckPlayerPage.settingsContainer(page)).toHaveCSS('width', '0px');
  await expect(await getMockSettingSentToNative(page)).toEqual(true);

});
