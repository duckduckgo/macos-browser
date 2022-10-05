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
        "title": "<b>Duck Player</b> protects your viewing activity from advertiser profiling and from influencing your YouTube recommendations."
    },
    "videoButtonOpen": {
        "title": "Watch in Duck Player"
    },
    "videoButtonOptOut": {
        "title": "No Thanks"
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
        if (!Reflect.has(text, name)) {
            console.error(`missing key ${name}`);
            return 'missing'
        }
        const match = Reflect.get(text, name);
        if (!Reflect.get(match, 'title')) {
            return 'missing'
        }
        return match.title;
    }
}
