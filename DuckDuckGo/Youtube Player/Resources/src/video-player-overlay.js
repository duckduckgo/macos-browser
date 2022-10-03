import dax from "../assets/dax.svg";
import {Util} from "./util.js";
import {VideoPlayerIcon} from "./video-player-icon";

export class VideoPlayerOverlay {

    /** @type {string | null} */
    lastVideoId = null

    /** @type {{fn: () => void, name: string}[]} */
    cleanups = [];

    CLASS_OVERLAY =  'ddg-video-player-overlay';

    /** @type {import("./video-player-icon").VideoPlayerIcon | null} */
    videoPlayerIcon = null;

    /**
     * @param {import("../youtube-inject").UserValues} userValues
     * @param {{getHref(): string, getLargeThumbnailSrc(videoId: string): string, setHref(href: string): void}} environment
     * @param {import("./comms.js").macOSCommunications} comms
     */
    constructor(userValues, environment, comms) {
        this.userValues = userValues;
        this.environment = environment;
        this.comms = comms;
    }

    /**
     * Creates the video player overlay and returns the element
     * @returns {HTMLElement}
     */
    overlay(videoId) {
        let videoURL = Util.getPrivatePlayerURL(videoId);
        let overlayElement = document.createElement('div');
        overlayElement.classList.add(this.CLASS_OVERLAY);
        overlayElement.innerHTML = `
            <div class="ddg-vpo-bg"></div>
            <div class="ddg-vpo-content">
                <div class="ddg-eyeball">
                    ${dax}
                </div>
                <div class="ddg-vpo-title">
                    Tired of watching creepy ads on YouTube? 
                </div>
                <div class="ddg-vpo-text">
                    <b>DuckPlayer</b> protects your viewing activity from advertiser profiling and from inluencing YouTube’s recommendation algorithm.
                </div>
                <div class="ddg-vpo-buttons">
                    <button class="ddg-vpo-button ddg-vpo-cancel" type="button">No Thanks</button>
                    <a class="ddg-vpo-button ddg-vpo-open" href="${videoURL}">Watch in Duck Player</a>
                </div>
                <div class="ddg-vpo-remember">
                    <label for="remember">
                        <input id="remember" type="checkbox" name="ddg-remember"> Remember my choice (can be changed in settings)
                    </label>
                </div>
            </div>
            `;
        this.appendThumbnail(overlayElement, videoId);
        return overlayElement;
    }
    appendThumbnail(overlayElement, videoId) {
        // @ts-ignore
        const imageUrl = this.environment.getLargeThumbnailSrc(videoId);
        const cleanup = Util.appendImageAsBackground(overlayElement, '.ddg-vpo-bg', imageUrl);
        this.cleanups.push({
            name: 'teardown from images added',
            fn: cleanup,
        })
    }
    /**
     * Sets up buttons being clickable, right now just the cancel button
     */
    setupButtonsInsideOverlay(ddgElement, videoId) {
        const cancelElement = ddgElement.querySelector('.ddg-vpo-cancel');
        const watchInPlayer = ddgElement.querySelector('.ddg-vpo-open');
        if (!cancelElement) return console.warn("Could not access .ddg-vpo-cancel");
        if (!watchInPlayer) return console.warn("Could not access .ddg-vpo-open");
        const optOutHandler = (e) => {
            if (e.isTrusted) {
                const remember = ddgElement.querySelector('input[name="ddg-remember"]');
                if (!remember) throw new Error('cannot find our input');
                /**
                 * If the checkbox was checked, this cancellation should also **disable** the player
                 * (by sending 'false' for `privatePlayerEnabled`)
                 *
                 * But, if the checkbox was not checked, then we don't set the player to
                 * enabled or disabled, but rather it remains 'undecided'. A non-boolean
                 * value such as 'null' or 'undefined' is used to represent this in JS. In
                 * the swift side, it's an `Optional<Bool>`
                 *
                 * @type {import("../youtube-inject.js").UserValues['privatePlayerMode']}
                 */
                if (remember.checked) {
                    this.userChoice({ alwaysAsk: {} })
                        .then(values => this.userValues = values)
                        .then(() => this.watchForVideoBeingAdded({ ignoreCache: true }))
                        .catch(e => console.error("could not set userChoice for opt-out", e ))
                } else {
                    this.removeOverlays();
                    this.addSmallDaxOverlay(videoId)
                }
            }
        };
        const watchInPlayerHandler = (e) => {
            if (e.isTrusted) {
                e.preventDefault();
                const href = e.target.href;
                const remember = ddgElement.querySelector('input[name="ddg-remember"]');
                if (!remember) throw new Error('cannot find our input');
                /**
                 * If the checkbox was checked, this action means that we want to 'always'
                 * use the private player
                 *
                 * But, if the checkbox was not checked, then we don't set the player to
                 * enabled or disabled, but rather it remains 'undecided'. A non-boolean
                 * value such as 'null' or 'undefined' is used to represent this in JS. In
                 * the swift side, it's an `Optional<Bool>`
                 *
                 * @type {import("../youtube-inject.js").UserValues['privatePlayerMode']}
                 */
                let privatePlayerEnabled = {alwaysAsk: {}};
                if (remember.checked) {
                    privatePlayerEnabled = {enabled: {}}
                } else {
                    // do nothing. The checkbox was off meaning we don't want to save any choice
                }
                this.userChoice(privatePlayerEnabled)
                    .then(() => this.environment.setHref(href))
                    .catch(e => console.error("error setting user choice", e))
            }
        }
        cancelElement.addEventListener("click", optOutHandler);
        watchInPlayer.addEventListener("click", watchInPlayerHandler);
        this.cleanups.push({
            name: "remove event handlers for button clicks",
            fn: () => {
                cancelElement?.removeEventListener("click", optOutHandler);
                watchInPlayer?.removeEventListener("click", watchInPlayerHandler);
            }
        })
    }
    /**
     * Set up the overlay
     * @param {import("../youtube-inject.js").UserValues} userValues
     * @param {string} videoId
     */
    addLargeOverlay(userValues, videoId) {
        console.log("🤞adding large overlay.....")
        let player = document.querySelector('#player'),
            playerVideo = document.querySelector('#player video'),
            containerElement = document.querySelector('#player .html5-video-player')

        if (player && playerVideo && containerElement) {
            console.log("🚧 showing full overlay")
            this.callPauseUntilPaused(playerVideo);
            const ddgElement = this.appendOverlayToPage(containerElement, videoId);
            this.setupButtonsInsideOverlay(ddgElement, videoId);
        }
    }

    /**
     * @param {string} videoId
     */
    addSmallDaxOverlay(videoId) {
        console.log("🦆 showing small dax overlay on video", videoId)
        if (!this.videoPlayerIcon) {
            this.videoPlayerIcon = new VideoPlayerIcon();
        }
        this.videoPlayerIcon.init(videoId);
    }

    /**
     * @param {{ignoreCache?: boolean}} [opts]
     */
    watchForVideoBeingAdded(opts = {}) {
        const href = this.environment.getHref();
        const videoId = Util.getYoutubeVideoId(href);
        if (!videoId) {
            console.log("no video id");
            return;
        }

        const conditions = [
            opts.ignoreCache,
            !this.lastVideoId,
            this.lastVideoId && this.lastVideoId !== videoId
        ]

        if (conditions.some(Boolean)) {
            const userValues = this.userValues;
            this.lastVideoId = videoId;
            console.log("📹 video shown", videoId, userValues);

            /**
             * always remove first, don't allow any lingering state
             */
            this.removeOverlays();

            /**
             * When enabled, always show the small dax icon
             */
            if ('enabled' in userValues.privatePlayerMode) {
                this.addSmallDaxOverlay(videoId)
            }
            if ('alwaysAsk' in userValues.privatePlayerMode) {
                if (!userValues.overlayInteracted) {
                    this.addLargeOverlay(userValues, videoId)
                } else {
                    this.addSmallDaxOverlay(videoId)
                }
            }
            if ('disabled' in userValues.privatePlayerMode) {
                console.log("do nothing");
            }
        }
    }

    /**
     * @param {Element} targetElement
     * @param {string} videoId
     * @return {HTMLElement}
     */
    appendOverlayToPage(targetElement, videoId) {
        const overlayElement = this.overlay(videoId);
        targetElement.appendChild(overlayElement)

        /**
         * Remove the element
         */
        this.cleanups.push({
            name: 'remove .ddg-video-player-overlay',
            fn: () => {
                const prevOverlayElement = document.querySelector(".ddg-video-player-overlay");
                if (prevOverlayElement) {
                    prevOverlayElement.parentNode?.removeChild?.(prevOverlayElement);
                } else {
                    console.log("exists, but disconnected");
                }
            },
        })

        return overlayElement;
    }

    /**
     * Just brute-force calling video.pause() for as long as the user is seeing the overlay.
     */
    callPauseUntilPaused(videoElement) {
        console.count("⏸ callPauseUntilPaused...")
        const int = setInterval(() => {
            if (videoElement instanceof HTMLVideoElement) {
                videoElement.pause();
            }
        }, 10);

        /**
         * Ensure the interval is cleared whenever the overlay is removed
         */
        this.cleanups.push({
            name: 'removing setInterval .pause()',
            fn: () => clearInterval(int)
        })
        /**
         * Try to continue the video by calling play on the video element
         * if we can
         */
        this.cleanups.push({
            name: 'calling `.play()` on video element',
            fn: () => {
                if (videoElement && videoElement.isConnected) {
                    console.log("▶️ called on original video element");
                    videoElement.play();
                } else {
                    console.log("▶️ trying to call 'play()' on newly queried element");
                    const video = document.querySelector('#player video');
                    if (video instanceof HTMLVideoElement) {
                        video.play();
                    }
                }
            }
        })
    }

    /**
     * Record the users choice
     * @param {import("../youtube-inject.js").UserValues['privatePlayerMode']} privatePlayerMode
     * @returns {Promise<import("../youtube-inject").UserValues>}
     */
    userChoice(privatePlayerMode) {
        return this.comms.setUserValues(privatePlayerMode)
            .then((userValues) => {
                console.log("interacted flag set, now cleanup");
                return userValues;
            })
            .catch(e => console.error("could not set interacted after user opt out", e))
    }
    /**
     * Remove elements, event listeners etc
     */
    removeOverlays() {
        Util.execCleanups(this.cleanups);
        this.cleanups = [];
        if (this.videoPlayerIcon) {
            this.videoPlayerIcon.cleanup();
        }
    }
}
