export const Util = {
    /**
     * Add an event listener to an element that is only executed if it actually comes from a user action
     * @param {Element} element - to attach event to
     * @param {string} event
     * @param {function} callback
     */
    addTrustedEventListener: (element, event, callback) => {
        element.addEventListener(event, (e) => {
            if (e.isTrusted) {
                callback(e);
            }
        });
    },

    /**
     * Same as $(elem).parents(selector)
     * @param {HTMLElement} elem
     * @param {string} selector
     */
    getClosest: function (elem, selector) {
        // @ts-ignore
        for ( ; elem && elem !== document; elem = elem.parentNode ) {
            if ( elem.matches( selector ) ) return elem;
        }
        return null;
    },

    /**
     * Appends an element. This may change if we go with Shadow DOM approach
     * @param {Element} to - which element to append to
     * @param {Element} element - to be appended
     */
    appendElement: (to, element) => {
        to.appendChild(element);
    },

    /**
     * NATIVE NOTE: Returns the URL we use for telling the MacOS app to open the private player
     * @param {string} relativePath - for now, it's expected to always be something like /watch?v=VIDEO_ID, there is no validation yet.
     */
    getPrivatePlayerURL: (relativePath) => {
        let url = new URL(relativePath, window.location.origin);

        let validVideoId = /^[a-zA-Z0-9-_]+$/g;
        let validTimestamp = /^[0-9hms]+$/g

        let privatePlayerURL = '';

        if (validVideoId.test(url?.searchParams.get('v'))) {
            privatePlayerURL = url.searchParams.get('v');
        }

        if (validTimestamp.test(url?.searchParams.get('t'))) {
            privatePlayerURL += '&t=' + url.searchParams.get('t');
        }

        return 'privateplayer:' + privatePlayerURL;
    },
    /**
     * @param {string} href
     * @returns {string | null}
     */
    getYoutubeVideoId(href) {
        const url = new URL(href);
        const videoId = url.searchParams.get("v");

        if (!videoId) return null;

        const matchingElement = document.querySelector('#player video');

        if (!url.pathname.startsWith("/watch")) {
            // console.log("not on /watch page");
            return null;
        }

        if (!matchingElement) {
            // console.log("video not found")
            return null
        }

        // finally, ensure youtube video id is good
        if (/^[a-zA-Z0-9-_]*$/g.test(videoId)) {
            return videoId
        }

        return null;
    },
    /**
     * Try to load an image first. If the status code is 2xx, then continue
     * to load
     * @param {HTMLElement} parent
     * @param {string} targetSelector
     * @param {string} imageUrl
     */
    appendImageAsBackground(parent, targetSelector, imageUrl) {
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

        /**
         * Return a clean-up function to prevent any overlapping work
         */
        return () => {
            canceled = true;
        }
    },
    execCleanups(cleanups) {
        if (Array.isArray(cleanups) && cleanups.length > 0) {
            console.log("cleaning up %d items", cleanups.length);
        }
        for (let cleanup of cleanups) {
            if (typeof cleanup.fn === "function") {
                try {
                    cleanup.fn();
                    console.log("🧹 cleanup '%s' was successfully", cleanup.name)
                } catch (e) {
                    console.error(`cleanup ${cleanup.name} threw`, e)
                }
            } else {
                throw new Error("invalid cleanup")
            }
        }
    }
}
