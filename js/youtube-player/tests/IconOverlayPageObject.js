export const IconOverlayPage = {
    thumbnail: (page, section, nthChild) => {
        return page.locator(`[data-testid="${section}"] #thumbnail:nth-child(${nthChild})`);
    },

    hoverOverlay: page => page.locator('.ddg-overlay-hover'),

    moveMouseAway: async (page) => {
        await page.mouse.move(1, 1);
    }

}
