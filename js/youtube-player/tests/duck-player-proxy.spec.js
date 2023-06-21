import {expect, test} from "@playwright/test";
import {scriptWithConfig, setupIconOverlays, mockVideoPage} from "./utils";
import * as constants from "../constants";

test.describe('ddg serp proxy', () => {
    test('readUserValues', async ({page}) => {
        await setupIconOverlays(page, 'https://duckduckgo.com', true);
        await page.evaluate((constants) => {
            window.__serp_received = [];
            window.addEventListener(constants.MSG_NAME_PROXY_RESPONSE, (e) => {
                window.__serp_received.push(e.detail);
            })

            // simulate the serp reading values
            window.dispatchEvent(new CustomEvent(constants.MSG_NAME_PROXY_INCOMING, {
                detail: {
                    kind: constants.MSG_NAME_READ_VALUES
                }
            }))
        }, constants)

        // assert the values were proxied through a custom event on window
        const messages = await page.evaluate(() => window.__serp_received);
        expect(messages).toMatchObject([
            {
                kind: constants.MSG_NAME_PUSH_DATA,
                data: { privatePlayerMode: {alwaysAsk:{}}, overlayInteracted: false }
            }
        ]);
    })

    test('setUserValues', async ({page}) => {
        await setupIconOverlays(page, 'https://duckduckgo.com', true);
        await page.evaluate((constants) => {
            window.__serp_received = [];
            window.addEventListener(constants.MSG_NAME_PROXY_RESPONSE, (e) => {
                window.__serp_received.push(e.detail);
            })

            // simulate the serp setting values
            window.dispatchEvent(new CustomEvent(constants.MSG_NAME_PROXY_INCOMING, {
                detail: {
                    kind: constants.MSG_NAME_SET_VALUES,
                    data: {
                        privatePlayerMode: {
                            enabled: {}
                        },
                        overlayInteracted: false
                    }
                }
            }))
        }, constants)

        // assert the values were proxied through a custom event on window
        const messages = await page.evaluate(() => window.__serp_received);
        expect(messages).toMatchObject([
            {
                kind: constants.MSG_NAME_PUSH_DATA,
                data: { privatePlayerMode: {enabled:{}}, overlayInteracted: false }
            }
        ]);
    })
    test('receiving values from `onUserValuesChanged`', async ({page}) => {
        await setupIconOverlays(page, 'https://duckduckgo.com', true);
        await page.evaluate((constants) => {
            window.__serp_received = [];
            window.addEventListener(constants.MSG_NAME_PROXY_RESPONSE, (e) => {
                window.__serp_received.push(e.detail);
            })

            // assert settings being 'pushed' (eg: a user changing them)
            window.onUserValuesChanged({
                userValuesNotification: {
                    privatePlayerMode: {
                        enabled: {}
                    },
                    overlayInteracted: false
                }
            })
            window.onUserValuesChanged({
                userValuesNotification: {
                    privatePlayerMode: {
                        disabled: {}
                    },
                    overlayInteracted: false
                }
            })
            window.onUserValuesChanged({
                userValuesNotification: {
                    privatePlayerMode: {
                        enabled: {}
                    },
                    overlayInteracted: false
                }
            })
        }, constants)

        // ensure that all 3 updates were received
        const messages = await page.evaluate(() => window.__serp_received);
        expect(messages).toMatchObject([
            {
                kind: constants.MSG_NAME_PUSH_DATA,
                data: { privatePlayerMode: {enabled:{}}, overlayInteracted: false }
            },
            {
                kind: constants.MSG_NAME_PUSH_DATA,
                data: { privatePlayerMode: {disabled:{}}, overlayInteracted: false }
            },
            {
                kind: constants.MSG_NAME_PUSH_DATA,
                data: { privatePlayerMode: {enabled:{}}, overlayInteracted: false }
            }
        ]);
    })
})

test.describe('auto-playing with #ddg-play + referrer', () => {
    async function setup(page) {
        await mockVideoPage(page);
        await page.addInitScript(() => {
            window.webkit = {
                messageHandlers: {
                    setUserValues: {
                        postMessage: async (input) => {
                            const { messageHandling, ...rest } = input;
                            return JSON.stringify(rest);
                        }
                    },
                    readUserValues: {
                        postMessage: async () => {
                            return JSON.stringify({privatePlayerMode: {alwaysAsk: {}}, overlayInteracted: false});
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
        const script = await scriptWithConfig({
            webkitMessagingConfig: {
                hasModernWebkitAPI: true,
            },
            allowedOrigins: ["localhost", "duckduckgo.com", "youtube.com"],
            testMode: "overlay-enabled"
        });
        return script;
    }
    test('regular overlay shows when #ddg-play is absent', async ({page}) => {
        const script = await setup(page);
        await page.goto('https://www.youtube.com/watch?v=987');
        await page.evaluate(script);
        await page.getByRole('link', { name: 'Watch in Duck Player' }).waitFor({timeout: 500})
    })
    test('regular overlay shows when #ddg-play is *present*, but referrer is not duckduckgo.com', async ({page}) => {
        const script = await setup(page);
        await page.goto('https://www.youtube.com/watch?v=987#ddg-play', { referer: "https://example.com" });
        //                                                                                 ^^^^^^^^^^^^^^^^^^^^
        await page.evaluate(script);
        await page.getByRole('link', { name: 'Watch in Duck Player' }).waitFor({timeout: 500})
    })
    test('overlay DOES NOT SHOW #ddg-play is *present* AND referrer is duckduckgo.com', async ({page}) => {
        const script = await setup(page);
        await page.goto('https://www.youtube.com/watch?v=987#ddg-play', { referer: "https://duckduckgo.com" });
        //                                                                                 ^^^^^^^^^^^^^^^^^^^^^^^
        await page.evaluate(script);

        /**
         *
         * NOTE: It's very hard to test something 'did not happen' in a UI.
         * So, here we're assuming that if all other tests pass (above) then
         * by waiting for 1000ms and asserting the absence of the overlay, then
         * things should have worked ok.
         *
         */
        await page.waitForTimeout(1000); // <- sanity check
        await expect(page.getByRole('link', { name: 'Watch in Duck Player' })).not.toBeVisible();
    })
})