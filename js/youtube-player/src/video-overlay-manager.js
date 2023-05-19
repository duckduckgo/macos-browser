import {applyEffect, execCleanups, VideoParams} from "./util.js";
import {VideoPlayerIcon} from "./video-player-icon";
import {DDGVideoOverlay} from "./components/ddg-video-overlay.js";


/**
 * Handle the switch between small & large overlays
 * + conduct any communications
 */
export class VideoOverlayManager {

    /** @type {string | null} */
    lastVideoId = null

    /** @type {import("./video-player-icon").VideoPlayerIcon | null} */
    videoPlayerIcon = null;

    /**
     * @param {import("../youtube-inject").UserValues} userValues
     * @param {{getHref(): string, getLargeThumbnailSrc(videoId: string): string, setHref(href: string): void}} environment
     * @param {import("./comms").Communications} comms
     */
    constructor(userValues, environment, comms) {
        this.userValues = userValues;
        this.environment = environment;
        this.comms = comms;
    }

    /**
     * Special handling of a first-page, an attempt to load our overlay as quickly as possible
     */
    handleFirstPageLoad() {

        // don't continue unless we're in 'alwaysAsk' mode
        if (!("alwaysAsk" in this.userValues.privatePlayerMode)) return;

        // don't continue if we've recorded a previous interaction
        if (this.userValues.overlayInteracted) return;

        // don't continue if we can't derive valid video params
        const validParams = VideoParams.forWatchPage(this.environment.getHref());
        if (!validParams) return;

        /**
         * If we get here, we know the following:
         *
         * 1) we're going to show the overlay because of user settings/state
         * 2) we're on a valid `/watch` page
         * 3) we have at _least_ a valid video id
         *
         * So, in that case we append some css quickly to the head to ensure player items are not showing
         * Later, when our overlay loads that CSS will be removed in the cleanup.
         */
        this.sideEffect('add css to head', () => {
            const s = document.createElement('style');
            s.innerText = '.html5-video-player { opacity: 0!important }'
            document.head.appendChild(s)
            return () => {
                if (s.isConnected) {
                    document.head.removeChild(s);
                }
            }
        });

        /**
         * Keep trying to find the video element every 100 ms
         */
        this.sideEffect("wait for first video element", () => {
            const int = setInterval(() => {
                this.watchForVideoBeingAdded({via: 'first page load'});
            }, 100)
            return () => {
                clearInterval(int)
            }
        })
    }

    /**
     * Set up the overlay
     * @param {import("../youtube-inject.js").UserValues} userValues
     * @param {import("./util").VideoParams} params
     */
    addLargeOverlay(userValues, params) {
        let playerVideo = document.querySelector('#player video'),
            containerElement = document.querySelector('#player .html5-video-player')

        if (playerVideo && containerElement) {
            this.stopVideoFromPlaying(playerVideo);
            this.appendOverlayToPage(containerElement, params);
        }
    }

    /**
     * @param {import("./util").VideoParams} params
     */
    addSmallDaxOverlay(params) {
        let containerElement = document.querySelector('#player .html5-video-player')
        if (!containerElement) {
            console.error("no container element");
            return;
        }
        if (!this.videoPlayerIcon) {
            this.videoPlayerIcon = new VideoPlayerIcon();
        }
        this.videoPlayerIcon.init(containerElement, params);
    }

    /**
     * @param {{ignoreCache?: boolean, via?: string}} [opts]
     */
    watchForVideoBeingAdded(opts = {}) {
        const params = VideoParams.forWatchPage(this.environment.getHref());

        if (!params) {
            /**
             * If we've shown a video before, but now we don't have a valid ID,
             * it's likely a 'back' navigation by the user, so we should always try to remove all overlays
             */
            if (this.lastVideoId) {
                this.removeAllOverlays();
                this.lastVideoId = null;
            }
            return;
        }

        const conditions = [
            opts.ignoreCache,
            !this.lastVideoId,
            this.lastVideoId && this.lastVideoId !== params.id
        ]

        if (conditions.some(Boolean)) {
            const playerElement = document.querySelector('#player');

            if (!playerElement) {
                return null
            }

            /**
             * If we get here, it's a valid situation
             */
            const userValues = this.userValues;
            this.lastVideoId = params.id;

            /**
             * always remove everything first, to prevent any lingering state
             */
            this.removeAllOverlays();

            /**
             * When enabled, always show the small dax icon
             */
            if ('enabled' in userValues.privatePlayerMode) {
                this.addSmallDaxOverlay(params)
            }
            if ('alwaysAsk' in userValues.privatePlayerMode) {
                if (!userValues.overlayInteracted) {
                    this.addLargeOverlay(userValues, params)
                } else {
                    this.addSmallDaxOverlay(params)
                }
            }
        }
    }

    /**
     * @param {Element} targetElement
     * @param {import("./util").VideoParams} params
     */
    appendOverlayToPage(targetElement, params) {
        this.sideEffect(`appending ${DDGVideoOverlay.CUSTOM_TAG_NAME} to the page`, () => {
            const overlayElement = new DDGVideoOverlay(this.environment, params, this)
            targetElement.appendChild(overlayElement)

            /**
             * To cleanup just find and remove the element
             */
            return () => {
                const prevOverlayElement = document.querySelector(DDGVideoOverlay.CUSTOM_TAG_NAME);
                if (prevOverlayElement) {
                    prevOverlayElement.parentNode?.removeChild?.(prevOverlayElement);
                }
            }
        })
    }

    /**
     * Just brute-force calling video.pause() for as long as the user is seeing the overlay.
     */
    stopVideoFromPlaying(videoElement) {
        this.sideEffect('pausing the <video> element', () => {
            /**
             * Set up the interval - keep calling .pause() to prevent
             * the video from playing
             */
            const int = setInterval(() => {
                if (videoElement instanceof HTMLVideoElement && videoElement.isConnected) {
                    videoElement.pause();
                }
            }, 10);

            /**
             * To clean up, we need to stop the interval
             * and then call .play() on the original element, if it's still connected
             */
            return () => {

                clearInterval(int)

                if (videoElement?.isConnected) {
                    videoElement.play();
                } else {
                    const video = document.querySelector('#player video');
                    if (video instanceof HTMLVideoElement) {
                        video.play();
                    }
                }
            }
        })
    }

    /**
     * If the checkbox was checked, this action means that we want to 'always'
     * use the private player
     *
     * But, if the checkbox was not checked, then we want to keep the state
     * as 'alwaysAsk'
     *
     */
    userOptIn(remember, params) {
        /** @type {import("../youtube-inject.js").UserValues['privatePlayerMode']} */
        let privatePlayerMode = {alwaysAsk: {}};
        if (remember) {
            privatePlayerMode = {enabled: {name: "shane"}}
        } else {
            // do nothing. The checkbox was off meaning we don't want to save any choice
        }
        const outgoing = {
            overlayInteracted: false,
            privatePlayerMode,
        };
        this.comms.setUserValues(outgoing)
            .then(() => this.environment.setHref(params.toPrivatePlayerUrl()))
            .catch(e => console.error("error setting user choice", e))
    }

    /**
     * @param {boolean} remember
     * @param {import("./util").VideoParams} params
     */
    userOptOut(remember, params) {
        /**
         * If the checkbox was checked we send the 'interacted' flag to the backend
         * so that the next video can just see the Dax icon instead of the full overlay
         *
         * But, if the checkbox was **not** checked, then we don't update any backend state
         * and instead we just swap the main overlay for Dax
         */
        if (remember) {
            /** @type {import("../youtube-inject.js").UserValues['privatePlayerMode']} */
            let privatePlayerMode = {alwaysAsk: {}};
            this.comms.setUserValues({
                privatePlayerMode: privatePlayerMode,
                overlayInteracted: true
            })
                .then(values => this.userValues = values)
                .then(() => this.watchForVideoBeingAdded({ignoreCache: true, via: 'userOptOut'}))
                .catch(e => console.error("could not set userChoice for opt-out", e))
        } else {
            this.removeAllOverlays();
            this.addSmallDaxOverlay(params)
        }
    }

    /** @type {{fn: () => void, name: string}[]} */
    _cleanups = [];

    /**
     * Wrap a side-effecting operation for easier debugging
     * and teardown/release of resources
     * @param {string} name
     * @param {() => () => void} fn
     */
    sideEffect(name, fn) {
        applyEffect(name, fn, this._cleanups)
    }

    /**
     * Remove elements, event listeners etc
     */
    removeAllOverlays() {
        execCleanups(this._cleanups);
        this._cleanups = [];

        if (this.videoPlayerIcon) {
            this.videoPlayerIcon.cleanup();
        }

        this.videoPlayerIcon = null;
    }
}
