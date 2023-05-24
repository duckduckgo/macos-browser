import {expect, test} from "@playwright/test";
import {scriptWithConfig, mockVideoPage} from "./utils";

test.describe('Pixels', () => {
    async function setup(page) {
        await mockVideoPage(page);
        await page.addInitScript(() => {
            window.__playwright_duck_player = {
                pixels: [],
            };
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
                        postMessage: async (incoming) => {
                            window.__playwright_duck_player.pixels.push(incoming)
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

    test('fires overlay pixel when shown', async ({page}) => {
        const script = await setup(page);
        await page.goto('https://www.youtube.com/watch?v=987');
        await page.evaluate(script);
        await page.getByRole('link', {name: 'Watch in Duck Player'}).waitFor({timeout: 500});
        const pixels = await page.evaluate(() => window.__playwright_duck_player.pixels);
        expect(pixels).toMatchObject([
            {
                pixelName: 'overlay',
                params: {},
                messageHandling: {secret: undefined}
            }
        ])
    });
    test('fires use pixel when opting in', async ({page}) => {
        const script = await setup(page);
        await page.goto('https://www.youtube.com/watch?v=987');
        await page.evaluate(script);
        await page.getByRole('link', {name: 'Watch in Duck Player'}).click({timeout: 500});
        const pixels = await page.evaluate(() => window.__playwright_duck_player.pixels);
        expect(pixels[1]).toMatchObject({
            pixelName: 'play.use',
            params: {
                remember: "0"
            },
            messageHandling: {secret: undefined}
        })
    });
    test('fires use pixel + remember option', async ({page}) => {
        const script = await setup(page);
        await page.goto('https://www.youtube.com/watch?v=987');
        await page.evaluate(script);
        await page.getByLabel('Remember my choice').check();
        await page.getByRole('link', {name: 'Watch in Duck Player'}).click({timeout: 500});
        const pixels = await page.evaluate(() => window.__playwright_duck_player.pixels);
        expect(pixels[1]).toMatchObject({
            pixelName: 'play.use',
            params: {
                remember: "1"
            },
            messageHandling: {secret: undefined}
        })
    });
    test('fires do_not_use pixel', async ({page}) => {
        const script = await setup(page);
        await page.goto('https://www.youtube.com/watch?v=987');
        await page.evaluate(script);
        await page.getByRole('button', { name: 'Watch Here' }).click({timeout: 500});
        const pixels = await page.evaluate(() => window.__playwright_duck_player.pixels);
        expect(pixels[1]).toMatchObject({
            pixelName: 'play.do_not_use',
            params: {
                remember: "0"
            },
            messageHandling: {secret: undefined}
        })
    });
    test('fires do_not_use pixel + remember option', async ({page}) => {
        const script = await setup(page);
        await page.goto('https://www.youtube.com/watch?v=987');
        await page.evaluate(script);
        await page.getByLabel('Remember my choice').check();
        await page.getByRole('button', { name: 'Watch Here' }).click({timeout: 500});
        const pixels = await page.evaluate(() => window.__playwright_duck_player.pixels);
        expect(pixels[1]).toMatchObject({
            pixelName: 'play.do_not_use',
            params: {
                remember: "1"
            },
            messageHandling: {secret: undefined}
        })
    });
})