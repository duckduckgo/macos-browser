export const DuckPlayerPage = {
    videoIframe: page => page.locator('iframe'),

    playerError: page => page.locator('.player-error'),

    toolbar: page => page.locator('.toolbar'),

    infoIcon: page => page.locator('.info-icon-container svg'),

    infoTooltip: page => page.locator('.info-icon-tooltip'),

    settingsCog: page => page.locator('.open-settings'),

    playOnYouTubeButton: page => page.locator('.play-on-youtube'),

    settingsContainer: page => page.locator('.setting-container'),

    settingsCheckbox: page => page.locator('.setting-container input'),

    moveMouseOutOfContent: async (page) => {
        await page.mouse.move(1, 1);
    },

    moveMouseToNewPositionOutsideOfContent: async (page) => {
        await page.mouse.move(10, 10);
    }
};
