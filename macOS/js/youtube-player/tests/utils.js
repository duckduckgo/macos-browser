import * as fs from 'node:fs/promises';


const getFileString = async (path) => {
    return await fs.readFile(path, { encoding: 'utf-8' });
}

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

export async function getDuckPlayerPage() {
    return await getFileString('../../DuckDuckGo/Youtube\ Player/Resources/youtube_player_template.html');
};

/**
 * Injects the icon overlay bundle and adds mocks so we intercept native MacOS browser comms
 * (as we don't have it in webkit)
 * @param {Object} page - the Playwright page object
 * @param {string} startURL - URL to start test from
 * @param {boolean} isLocal - whether test test is run locally
 */
export async function setupIconOverlays(page, startURL = 'https://www.youtube.com/', mock) {
    page.on('console', (msg) => {
        console.log(msg.type(), msg.text());
    })
    const mockWebkitMessaging = async () => {
        await page.addInitScript(() => {
            window.webkit = {
                messageHandlers: {
                    setUserValues: {
                        // for the sake of testing, just reflect the same values recieved
                        postMessage: async (input) => {
                            const { messageHandling, ...rest } = input;
                            return JSON.stringify(rest);
                        }
                    },
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
                    sendDuckPlayerPixel: {
                        postMessage: async () => {
                            return JSON.stringify({});
                        }
                    }
                }
            };
        });
    },

    injectIconOverlayBundle = async () => {
        const script = await scriptWithConfig({
            webkitMessagingConfig: {
                hasModernWebkitAPI: true,
            },
            allowedOrigins: ["localhost", "duckduckgo.com", "youtube.com"],
        })

        await page.evaluate(script.toString());
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
    },

    mockYouTubeURL = async () => {
        const duckIconOverlayMockPage = await getFileString('../../DuckDuckGo/Youtube\ Player/Resources/icon-overlay-integration-test.html');

        await page.route('**/*', route => {
            return route.fulfill({
                status: 200,
                body: duckIconOverlayMockPage,
                contentType: 'text/html'
            });
        });
    };

    if (mock) {
        await mockYouTubeURL();
    }
    await mockWebkitMessaging();
    await page.goto(startURL);
    await injectIconOverlayBundle();
    await triggerDuckPlayerSettings();

    if (!mock) {
        await rejectYouTubeCookies();
    }
  }

/**
 * Injects the icon overlay bundle and adds mocks so we intercept native MacOS browser comms
 * (as we don't have it in webkit)
 * @param {Object} page - the Playwright page object
 */
export async function mockVideoPage(page) {
    page.on('console', (msg) => {
        console.log(msg.type(), msg.text());
    })

    const duckIconOverlayMockPage = await getFileString('./tests/video.html');

    await page.route('**/*', route => {
        return route.fulfill({
            status: 200,
            body: duckIconOverlayMockPage,
            contentType: 'text/html'
        });
    });
}

/**
 * @param {YoutubeUserScriptConfig} config
 * @returns {Promise<string>}
 */
export async function scriptWithConfig(config) {
    const injectScript = await getFileString('../../DuckDuckGo/Youtube\ Player/Resources/youtube-inject-bundle.js');

    // This is replaced on the native side, replace it here instead.
    let script = `
    (() => {
        const $DDGYoutubeUserScriptConfig$ = ${JSON.stringify(config)};
        try {
            ${injectScript}
        } catch (e) {
            console.error('uncaught', e);
        }
     })()
    `
    return script;
}