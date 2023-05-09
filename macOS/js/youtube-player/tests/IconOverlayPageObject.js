export const IconOverlayPage = {
    thumbnail: (page, section, nthChild) => {
        return page.locator(`[data-testid="${section}"] #thumbnail:nth-child(${nthChild})`);
    },

    hoverOverlay: page => page.locator('.ddg-overlay-hover'),

    hoverOverlayLink: page => page.locator('.ddg-overlay-hover .ddg-play-text-container'),

    moveMouseAway: async (page) => {
        await page.mouse.move(1, 1);
    }

}
