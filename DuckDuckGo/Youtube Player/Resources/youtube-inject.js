// @ts-nocheck
import css from "./assets/styles.css";
import {VideoPlayerOverlay} from "./src/video-player-overlay";
import {VideoPlayerIcon} from "./src/video-player-icon.js";
import {IconOverlay} from "./src/icon-overlay.js";
import {Util} from "./src/util.js";

console.log("script load", window.location.href);

/**
 * @typedef UserValues - A way to communicate some user state
 * @property {boolean|null|undefined} [privatePlayerEnabled] - optional, and one of 3 values: true/false/(null/undefined)
 * @property {boolean} overlayInteracted - always a boolean
 */
window.enable = function enable(args) {
    console.log("👴 reading user prefs", args);
    const CSS = {
        styles: css,
        /**
         * Initialize the CSS by adding it to the page in a <style> tag
         */
        init: () => {
            let style = document.createElement("style");
            style.innerText = CSS.styles;
            Util.appendElement(document.head, style);
        }
    }

    const OverlaySettings = {
        enabled: {
            thumbnails: true,
            video: true,
        },

        enableThumbnails: () => {
            IconOverlay.appendHoverOverlay();
            VideoThumbnail.bindEventsToAll();

            OverlaySettings.enabled.thumbnails = true;
        },

        disableThumbnails: () => {
            let overlays = document.querySelectorAll('.' + IconOverlay.OVERLAY_CLASS);
            console.log('overlays', overlays);

            overlays.forEach(overlay => {
                overlay.remove();
            });

            OverlaySettings.enabled.thumbnails = false;
        },

        disableVideo: () => {
            OverlaySettings.enabled.video = false;
        }
    };

    const VideoThumbnail = {
        /**
         * Find all video thumbnails on the page
         * @returns {array} array of videoElement(s)
         */
        findAll: () => {
            const linksToVideos = item => {
                let href = item.getAttribute('href');
                return href && (
                    (href.includes('/watch?v=') && !href.includes('&list=')) ||
                    (href.includes('/watch?v=') && href.includes('&list=') && href.includes('&index='))
                ) && !href.includes('&pp=') //exclude movies for rent
            }

            const linksWithImages = item => {
                return item.querySelector('img');
            }

            const linksWithoutSubLinks = item => {
                return !item.querySelector('a[href^="/watch?v="]');
            }

            const linksNotInVideoPreview = item => {
                let linksInVideoPreview = Array.from(document.querySelectorAll('#preview a'));

                return linksInVideoPreview.indexOf(item) === -1;
            }

            return Array.from(document.querySelectorAll('a:not(.has-ddg-overlay,.ddg-play-privately)'))
                .filter(linksToVideos)
                .filter(linksWithoutSubLinks)
                .filter(linksNotInVideoPreview)
                .filter(linksWithImages);
        },

        /**
         * Bind hover events and make sure hovering the video will correctly show the hover
         * overlay and mousouting will hide it.
         */
        bindEvents: (video) => {
            if (video) {
                Util.addTrustedEventListener(video, 'mouseover', () => {
                    IconOverlay.moveHoverOverlayToVideoElement(video);
                });

                Util.addTrustedEventListener(video, 'mouseout', IconOverlay.hideHoverOverlay);

                video.classList.add('has-ddg-overlay');
            }
        },

        /**
         * Bind events to all video thumbnails on the page (that hasn't already been bound)
         */
        bindEventsToAll: () => {
            VideoThumbnail.findAll().forEach(VideoThumbnail.bindEvents);
        }
    };

    const Preview = {
        previewContainer: false,

        /**
         * Get the video hover preview link
         * @returns {HTMLElement}
         */
        getPreviewVideoLink: () => {
            let linkSelector = 'a[href^="/watch?v="]';
            let previewVideo = document.querySelector('#preview '+linkSelector+' video');

            return Util.getClosest(previewVideo, linkSelector);
        },

        /**
         * Append icon overlay to the video hover preview unless it's already been appended
         * @returns {(HTMLElement|false)}
         */
        appendIfNotAppended: () => {
            if (!OverlaySettings.enabled.thumbnails) {
                return;
            }

            let previewVideo = Preview.getPreviewVideoLink();

            if (previewVideo) {
                return IconOverlay.appendToVideo(previewVideo);
            }

            return false;
        },

        /**
         * Updates the icon overlay to use the correct video url in the preview hover link whenever it is hovered
         */
        update: () => {
            let updateOverlayVideoId = (element) => {
                let overlay = element && element.querySelector('.ddg-overlay');

                if (overlay) {
                    overlay.querySelector('a.ddg-play-privately').setAttribute('href', Util.getPrivatePlayerURL(element.getAttribute('href')));
                }
            }

            let videoElement = Preview.getPreviewVideoLink();

            updateOverlayVideoId(videoElement);
        },

        /**
         * YouTube does something weird to links added within ytd-app. Needs to set this up to
         * be able to make the preview link clickable.
         */
        fixLinkClick: () => {
            let previewLink = Preview.getPreviewVideoLink().querySelector('a.ddg-play-privately');

            Util.addTrustedEventListener(previewLink, 'click', () => {
                window.location = previewLink.getAttribute('href');
            });
        },

        /**
         * Initiate the preview hover overlay
         */
        init: () => {
            let appended = Preview.appendIfNotAppended();

            if (appended) {
                Preview.fixLinkClick();
            } else {
                Preview.update();
            }
        }
    };

    const Site = {
        onDOMLoaded: (callback) => {
            callback();
        },

        onDOMChanged: (callback) => {
            let observer = new MutationObserver(callback);
            observer.observe(document.querySelector('body'), {
                subtree: true,
                childList: true,
                attributeFilter: ['src']
            });
        },

        init: () => {
            Site.onDOMLoaded(() => {
                CSS.init();
                IconOverlay.appendHoverOverlay();
                VideoThumbnail.bindEventsToAll();
                // VideoPlayerIcon.init(args);
            });

            console.log('🔍 waiting for video');

            Site.onDOMChanged(() => {
                if (OverlaySettings.enabled.thumbnails) {
                    VideoThumbnail.bindEventsToAll();
                    Preview.init();
                }

                // VideoPlayerIcon.init(args);
                VideoPlayerOverlay.watchForVideoBeingAdded(args);
            });
        }
    }

    Site.init();

    // TODO: Remove if we're not going to do this. Doesn't look like it anymore.
    /*let appendOverlayToVideoPageTitle = () => {
        let onVideoPage = document.location.pathname === '/watch';

        let findVideoTitleElement = () => {
            let titles = Array.from(document.querySelectorAll('h1:not(.has-ddg-overlay)'));

            for (let i in titles) {
                let text = titles[i].innerText.trim();
                if (text !== '' && document.title.includes(text)) {
                    return titles[i];
                }
            }

            return false;
        }

        if (onVideoPage) {
            let videoTitleElement = findVideoTitleElement();

            if (videoTitleElement) {
                videoTitleElement.appendChild(overlay('title', '#'));
                videoTitleElement.classList.add('has-ddg-overlay');
            }
        }
    }*/

}

window.disable = function disable(args) {
    console.log("I'm injected, but disabled", args);
}
