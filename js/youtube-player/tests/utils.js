import * as fs from 'node:fs/promises';

/**
 * Wait for a set amount of seconds (mainly used when waiting for CSS transitions)
 * @param {number} delay - delay in ms
 */
export async function sleep(delay) {
    await new Promise(resolve => setTimeout(resolve, delay));
};

/**
 * Using the setupIconOverlays below, we mock icon link clicks by setting a
 * global variable ._test_clickedDuckPlayerLink. This function returns the value of
 * it so that we can detect if a link was clicked. (Clicks into duck://player doesn't work)
 * @param {Object} page - the Playwright page object
 */
export async function getClickedDuckPlayerLink(page) {
    return await page.evaluate(() => {
        return window._test_clickedDuckPlayerLink;
    });
}

/**
 * Injects the icon overlay bundle and adds mocks so we intercept native MacOS browser comms
 * (as we don't have it in webkit)
 * @param {Object} page - the Playwright page object
 * @param {string} startURL - URL to start test from
 * @param {boolean} isLocal - whether test test is run locally
 */
export async function setupIconOverlays(page, startURL = 'https://www.youtube.com/') {
    const isYouTube = startURL.includes('youtube.com');

    const mockWebkitMessaging = async () => {
        await page.addInitScript(() => {
            window.webkit = {
                messageHandlers: {
                setUserValues: { postMessage: () => { } },
                readUserValues:  {
                    postMessage: async () => {
                        return JSON.stringify({ privatePlayerMode: { alwaysAsk: {} }, overlayInteracted: false });
                    }
                },
                openDuckPlayer:  {
                    postMessage: (message) => {
                        window._test_clickedDuckPlayerLink = message.href;
                    }
                },
                }
            };
        });
    },
    injectIconOverlayBundle = async () => {
        const getFileString = async (path) => {
            return await fs.readFile(path, { encoding: 'utf-8' });
        }

        const injectScript = await getFileString('../../DuckDuckGo/Youtube\ Player/Resources/youtube-inject-bundle.js');

        // This is replaced on the native side, replace it here instead.
        let script = injectScript.replace('$WebkitMessagingConfig$', JSON.stringify({
            hasModernWebkitAPI: true,
        }));

        // Ugly way of making sure enable (which relies on the un-mockable window.location.hostname === 'youtube.com') returns true
        // when we're not running the test on YouTube.com
        if (!isYouTube) {
            script = script.replace('enabled() {', 'enabled() { return true;');
        }

        await page.evaluate(script);
    },
    triggerDuckPlayerSettings = async () => {
        await page.evaluate(() => {
            window.onUserValuesChanged({
                userValuesNotification: {
                    privatePlayerMode: {
                        alwaysAsk: {}
                    },
                    overlayInteracted: false
                }
            });
        });
    },
    rejectYouTubeCookies = async () => {
        await page.getByText('Reject all', { exact: true}).click();
    };

    await mockWebkitMessaging();
    await page.goto(startURL);
    await injectIconOverlayBundle();
    await triggerDuckPlayerSettings();

    if (isYouTube) {
        await rejectYouTubeCookies();
    }
  }
