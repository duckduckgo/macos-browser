import eyeball from "../assets/eyeball.svg";
import {Util} from "./util.js";

export const VideoPlayerOverlay = {

    CLASS_OVERLAY: 'ddg-video-player-overlay',

    /**
     * Creates the video player overlay and returns the element
     * @returns {HTMLElement}
     */
    overlay: (videoId) => {
        let videoURL = Util.getPrivatePlayerURL(videoId);
        let overlayElement = document.createElement('div');
        overlayElement.setAttribute('class', VideoPlayerOverlay.CLASS_OVERLAY);
        overlayElement.innerHTML = `
            <div class="ddg-vpo-bg"></div>
            <div class="ddg-vpo-content">
                <div class="ddg-eyeball">
                    ${eyeball}
                </div>
                <div class="ddg-vpo-title">
                    Watch without creepy ads and trackers
                </div>
                <div class="ddg-vpo-text">
                    YouTube does not let you watch videos anonymously... but the DuckDuckGo video player does! Watch this video with fewer trackers and no creepy ads.
                </div>
                <div class="ddg-vpo-buttons">
                    <button class="ddg-vpo-cancel" type="button">No Thanks</button>
                    <a class="ddg-vpo-open" href="${videoURL}">Try it now</a>
                </div>
            </div>
            `;
        VideoPlayerOverlay.appendThumbnail(overlayElement, videoId);
        return overlayElement;
    },
    appendThumbnail(overlayElement, videoId) {
        const imageUrl = new URL(`/vi/${videoId}/maxresdefault.jpg`, 'https://i.ytimg.com');
        const cleanup = Util.appendImageAsBackground(overlayElement, '.ddg-vpo-bg', imageUrl.href);
        VideoPlayerOverlay.cleanups.push({
            name: 'teardown from images added',
            fn: cleanup,
        })
    },
    /**
     * Sets up buttons being clickable, right now just the cancel button
     */
    setupButtonsInsideOverlay: () => {
        const cancel = document.querySelector('.ddg-vpo-cancel');
        if (!cancel) return console.warn("Could not access .ddg-vpo-cancel");
        const handler = (e) => {
            if (e.isTrusted) {
                VideoPlayerOverlay.userOptOut();
            }
        };
        cancel.addEventListener("click", handler);
        VideoPlayerOverlay.cleanups.push({
            name: "remove event handlers for button clicks",
            fn: () => {
                cancel?.removeEventListener("click", handler);
            }
        })
    },

    /**
     * Set up the overlay
     * @param {string} videoId
     */
    create: (videoId) => {
        console.log("🤞🤞🤞🤞calling create.....")

        VideoPlayerOverlay.cleanup();

        let player = document.querySelector('#player'),
            playerVideo = document.querySelector('#player video'),
            containerElement = document.querySelector('#player .html5-video-player')

        if (player && playerVideo && containerElement) {
            VideoPlayerOverlay.callPauseUntilPaused(playerVideo);
            VideoPlayerOverlay.appendOverlay(containerElement, videoId);
            VideoPlayerOverlay.setupButtonsInsideOverlay();
        }
    },

    /**
     * @param {import("../youtube-inject.js").UserValues} userValues
     */
    watchForVideoBeingAdded: (userValues) => {
        const videoId = Util.getYoutubeVideoId();
        if (!videoId) {
            return;
        }
        if (!VideoPlayerOverlay.lastVideoId || VideoPlayerOverlay.lastVideoId && VideoPlayerOverlay.lastVideoId !== videoId) {
            VideoPlayerOverlay.lastVideoId = videoId;
            // console.log("📹 video shown", videoId, userValues);
            if (userValues.privatePlayerEnabled === true) {
                // console.log("userValues.privatePlayerEnabled === true", "should not get here...")
            } else if (userValues.privatePlayerEnabled === false) {
                // console.log("userValues.privatePlayerEnabled === false")
            } else {
                if (!userValues.overlayInteracted) {
                    console.log("🚧 showing full overlay")
                    VideoPlayerOverlay.create(videoId);
                }
            }
        }
    },

    /** @type {string | null} */
    lastVideoId: null,

    /**
     * @param {Element} targetElement
     * @param {string} videoId
     */
    appendOverlay(targetElement, videoId) {
        const overlayElement = VideoPlayerOverlay.overlay(videoId);
        targetElement.appendChild(overlayElement)

        VideoPlayerOverlay.cleanups.push({
            name: 'remove .ddg-video-player-overlay',
            fn: () => {
                const prevOverlayElement = document.querySelector(".ddg-video-player-overlay");
                if (prevOverlayElement && prevOverlayElement.isConnected) {
                    prevOverlayElement.parentNode?.removeChild?.(prevOverlayElement);
                } else {
                    console.log("exists, but disconnected");
                }
            },
        })
    },

    /**
     * Just brute-force calling video.pause() for as long as the user is seeing the overlay.
     */
    callPauseUntilPaused: (videoElement) => {
        console.count("⏸ callPauseUntilPaused...")
        const int = setInterval(() => {
            if (videoElement instanceof HTMLVideoElement) {
                videoElement.pause();
            }
        }, 10);

        /**
         * Ensure the interval is cleared whenever the overlay is removed
         */
        VideoPlayerOverlay.cleanups.push({
            name: 'removing setInterval .pause()',
            fn: () => clearInterval(int)
        })
        /**
         * Try to continue the video by calling play on the video element
         * if we can
         */
        VideoPlayerOverlay.cleanups.push({
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
    },

    /**
     * Hide the video player overview
     */
    userOptOut: () => {
        VideoPlayerOverlay.cleanup();
        Util.setInteracted()
            .then(() => console.log("interacted flag set"))
            .catch(e => console.error("could not set interacted after user opt out", e))
    },
    /** @type {{fn: () => void, name: string}[]} */
    cleanups: [],
    /**
     * Remove elements, event listeners etc
     */
    cleanup() {
        if (Array.isArray(VideoPlayerOverlay.cleanups) && VideoPlayerOverlay.cleanups.length > 0) {
            console.log("cleaning up %d items", VideoPlayerOverlay.cleanups.length);
        }
        for (let cleanup of VideoPlayerOverlay.cleanups) {
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
        VideoPlayerOverlay.cleanups = [];
    }
}
