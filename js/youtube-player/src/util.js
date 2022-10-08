/**
 * Add an event listener to an element that is only executed if it actually comes from a user action
 * @param {Element} element - to attach event to
 * @param {string} event
 * @param {function} callback
 */
export function addTrustedEventListener(element, event, callback) {
    element.addEventListener(event, (e) => {
        if (e.isTrusted) {
            callback(e);
        }
    });
}

export function onDOMLoaded(callback) {
    window.addEventListener('DOMContentLoaded', () => {
        callback();
    });
};

export function onDOMChanged(callback) {
    let observer = new MutationObserver(callback);
    observer.observe(document.body, {
        subtree: true,
        childList: true,
        attributeFilter: ['src']
    });
};

/**
 * Appends an element. This may change if we go with Shadow DOM approach
 * @param {Element} to - which element to append to
 * @param {Element} element - to be appended
 */
export function appendElement(to, element) {
    to.appendChild(element);
}

/**
 * Try to load an image first. If the status code is 2xx, then continue
 * to load
 * @param {HTMLElement} parent
 * @param {string} targetSelector
 * @param {string} imageUrl
 */
export function appendImageAsBackground(parent, targetSelector, imageUrl) {
    let canceled = false;

    /**
     * Make a HEAD request to see what the status of this image is, without
     * having to fully download it.
     *
     * This is needed because YouTube returns a 404 + valid image file when there's no
     * thumbnail and you can't tell the difference through the 'onload' event alone
     */
    fetch(imageUrl, { method: "HEAD" }).then(x => {
        const status = String(x.status);
        if (canceled) return console.warn("not adding image, cancelled");
        if (status.startsWith('2')) {
            if (!canceled) {
                append();
            } else {
                console.warn("ignoring cancelled load")
            }
        } else {
            console.error('❌ status code did not start with a 2')
            markError();
        }
    }).catch(x => {
        console.error("e from fetch")
    })

    /**
     * If loading fails, mark the parent with data-attributes
     */
    function markError() {
        parent.dataset.thumbLoaded = String(false);
        parent.dataset.error = String(true);
    }

    /**
     * If loading succeeds, try to append the image
     */
    function append() {
        const targetElement = parent.querySelector(targetSelector);
        if (!(targetElement instanceof HTMLElement)) return console.warn("could not find child with selector", targetSelector, "from", parent)
        parent.dataset.thumbLoaded = String(true);
        parent.dataset.thumbSrc = imageUrl;
        let img = new Image();
        img.src = imageUrl;
        img.onload = function(arg) {
            if (canceled) return console.warn("not adding image, cancelled");
            targetElement.style.backgroundImage = `url(${imageUrl})`;
            targetElement.style.backgroundSize = `cover`;
        }
        img.onerror = function(arg) {
            if (canceled) return console.warn("not calling markError, cancelled");
            markError();
            const targetElement = parent.querySelector(targetSelector);
            if (!(targetElement instanceof HTMLElement)) return;
            targetElement.style.backgroundImage = ``;
        }
    }
}

/**
 * Execute any stored tear-down functions.
 *
 * This handled anything you might want to 'undo', like stopping timers,
 * removing things from the page etc.
 *
 * @param {({fn: ()=>void, name: string})[]} cleanups
 */
export function execCleanups(cleanups) {
    for (let cleanup of cleanups) {
        if (typeof cleanup.fn === "function") {
            try {
                cleanup.fn();
                console.log("🧹 cleanup '%s' was successfully executed", cleanup.name)
            } catch (e) {
                console.error(`cleanup ${cleanup.name} threw`, e)
            }
        } else {
            throw new Error("invalid cleanup")
        }
    }
}

/**
 * @param {string} name
 * @param {()=>void} fn
 * @param {{name: string, fn: ()=>void}[]} storage
 */
export function applyEffect(name, fn, storage) {
    let cleanup;
    try {
        cleanup = fn();
        console.log(`☢️ side effect '%s' executed`, name)
    } catch (e) {
        console.error('%s threw an error', name, e);
    }
    if (typeof cleanup === "function") {
        storage.push({name, fn: cleanup})
    }
}

/**
 * A container for valid/parsed video params.
 *
 * If you have an instance of `VideoParams`, then you can trust that it's valid and you can always
 * produce a PrivatePlayer link from it
 *
 * The purpose is to co-locate all processing of search params/pathnames for easier security auditing/testing
 *
 * @example
 *
 * ```
 * const privateUrl = VideoParams.fromHref("https://example.com/foo/bar?v=123&t=21")?.toPrivatePlayerUrl()
 *       ^^^^ <- this is now null, or a string if it was valid
 * ```
 */
export class VideoParams {
    /**
     * @param {string} id - the YouTube video ID
     * @param {string|null|undefined} time - an optional time
     */
    constructor(id, time) {
        this.id = id;
        this.time = time;
    }

    static validVideoId = /^[a-zA-Z0-9-_]+$/;
    static validTimestamp = /^[0-9hms]+$/;

    /**
     * @returns {string}
     */
    toPrivatePlayerUrl() {
        const duckUrl = new URL(this.id, 'https://player');
        duckUrl.protocol = "duck:";

        if (this.time) {
            duckUrl.searchParams.set("t", this.time);
        }
        return duckUrl.href;
    }

    /**
     * Convert a relative pathname into a
     * @param {string} href
     * @returns {VideoParams|null}
     */
    static forWatchPage(href) {
        let url = new URL(href);
        if (!url.pathname.startsWith("/watch")) {
            return null;
        }
        return VideoParams.fromHref(url.href);
    }

    /**
     * Convert a relative pathname into a
     * @param pathname
     * @returns {VideoParams|null}
     */
    static fromPathname(pathname) {
        let url = new URL(pathname, window.location.origin);
        return VideoParams.fromHref(url.href)
    }

    /**
     * Convert a href into valid video params. Those can then be converted into a private player
     * link when needed
     *
     * @param href
     * @returns {VideoParams|null}
     */
    static fromHref(href) {
        const url = new URL(href);
        const vParam = url.searchParams.get("v");
        const tParam = url.searchParams.get("t");

        let id = null;
        let time = null;

        // ensure youtube video id is good
        if (vParam && VideoParams.validVideoId.test(vParam)) {
            id = vParam
        } else {
            // if the video ID is invalid, we cannot produce an instance of VideoParams
            return null;
        }

        // ensure timestamp is good, if set
        if (tParam && VideoParams.validTimestamp.test(tParam)) {
            time = tParam
        }

        return new VideoParams(id, time)
    }
}
