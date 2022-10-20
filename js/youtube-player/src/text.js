/**
 * If this get's localised in the future, this would likely be in a json file
 */
const text = {
    "playText": {
        "title": "Duck Player"
    },
    "videoOverlayTitle": {
        "title": "Tired of targeted YouTube ads and recommendations?"
    },
    "videoOverlaySubtitle": {
        "title": "<b>Duck Player</b> provides a clean viewing experience without personalized ads and prevents viewing activity from influencing your YouTube recommendations."
    },
    "videoButtonOpen": {
        "title": "Watch in Duck Player"
    },
    "videoButtonOptOut": {
        "title": "Watch Here"
    },
    "rememberLabel": {
        "title": "Remember my choice"
    }
}

export const i18n = {
    /**
     * @param {keyof text} name
     */
    t(name) {
        if (!text.hasOwnProperty(name)) {
            console.error(`missing key ${name}`);
            return 'missing'
        }
        const match = text[name];
        if (!match.title) {
            return 'missing'
        }
        return match.title;
    }
}
