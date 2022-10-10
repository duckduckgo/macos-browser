import css from "./assets/styles.css";
import {VideoPlayerOverlay} from "./src/video-player-overlay";
import {IconOverlay} from "./src/icon-overlay.js";
import {onDOMLoaded, onDOMChanged, addTrustedEventListener, appendElement, VideoParams} from "./src/util.js";
import {macOSCommunications} from "./src/comms";

console.log("script load", window.location.href);

const defaultEnvironment = {
    getHref() {
        return window.location.href
    },
    getLargeThumbnailSrc(videoId) {
        const url = new URL(`/vi/${videoId}/maxresdefault.jpg`, 'https://i.ytimg.com');
        return url.href
    },
    setHref(href) {
        window.location.href = href;
    }
}

const defaultComms = macOSCommunications;

/**
 * Entry point. Until this returns with initial user values, we cannot continue.
 */
defaultComms.readUserValues().then((userValues) => {
    enable(userValues, defaultEnvironment, defaultComms);
}).catch(e => console.error("could not read userValues", e))

/**
 * @typedef UserValues - A way to communicate some user state
 * @property {{enabled: {}} | {alwaysAsk:{}} | {disabled:{}}} privatePlayerMode - one of 3 values: 'enabled:{}', 'alwaysAsk:{}', 'disabled:{}'
 * @property {boolean} overlayInteracted - always a boolean
 *
 * @param {UserValues} userValues - user values are state-based things that can update
 * @param {defaultEnvironment} [environment] - methods to read environment-sensitive things like the current URL etc
 * @param {macOSCommunications } [comms] - methods to communicate with a native backend
 */
function enable(userValues, environment = defaultEnvironment, comms = defaultComms) {
    const videoPlayerOverlay = new VideoPlayerOverlay(userValues, environment, comms);

    defaultComms.onUserValuesNotification((userValues) => {
        console.log("got new values after zero", userValues)
        videoPlayerOverlay.userValues = userValues;
        videoPlayerOverlay.watchForVideoBeingAdded({ignoreCache: true});

        if (userValues.privatePlayerMode.disabled) {
            AllIconOverlays.disable();
            OpenInDuckPlayer.disable();
        } else if (userValues.privatePlayerMode.enabled) {
            AllIconOverlays.disable();
            OpenInDuckPlayer.enable();
        } else if (userValues.privatePlayerMode.alwaysAsk) {
            AllIconOverlays.enable();
            OpenInDuckPlayer.disable();
        }
    });
    const CSS = {
        styles: css,
        /**
         * Initialize the CSS by adding it to the page in a <style> tag
         */
        init: () => {
            let style = document.createElement("style");
            style.innerText = CSS.styles;
            appendElement(document.head, style);
        }
    }

    const VideoThumbnail = {

        isSingleVideoURL: (href) => {
            return href && (
                (href.includes('/watch?v=') && !href.includes('&list=')) ||
                (href.includes('/watch?v=') && href.includes('&list=') && href.includes('&index='))
            ) && !href.includes('&pp=') //exclude movies for rent
        },

        /**
         * Find all video thumbnails on the page
         * @returns {array} array of videoElement(s)
         */
        findAll: () => {
            const linksToVideos = item => {
                let href = item.getAttribute('href');
                return VideoThumbnail.isSingleVideoURL(href);
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

            return Array.from(document.querySelectorAll('a[href^="/watch?v="]'))
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
                addTrustedEventListener(video, 'mouseover', () => {
                    IconOverlay.moveHoverOverlayToVideoElement(video);
                });

                addTrustedEventListener(video, 'mouseout', IconOverlay.hideHoverOverlay);
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
         * @returns {HTMLElement | null | undefined}
         */
        getPreviewVideoLink: () => {
            let linkSelector = 'a[href^="/watch?v="]';
            let previewVideo = document.querySelector('#preview '+linkSelector+' video');

            return previewVideo?.closest(linkSelector);
        },

        /**
         * Append icon overlay to the video hover preview unless it's already been appended
         * @returns {HTMLElement|boolean}
         */
        appendIfNotAppended: () => {
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
                let overlay = element?.querySelector('.ddg-overlay');
                const href = element?.getAttribute("href");
                if (href) {
                    const privateUrl = VideoParams.fromPathname(href)?.toPrivatePlayerUrl();
                    if (overlay && privateUrl) {
                        overlay.querySelector('a.ddg-play-privately')?.setAttribute('href', privateUrl);
                    }
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
            let previewLink = Preview.getPreviewVideoLink()?.querySelector('a.ddg-play-privately');
            if (!previewLink) return;
            addTrustedEventListener(previewLink, 'click', () => {
                const href = previewLink?.getAttribute('href');
                if (href) {
                    environment.setHref(href);
                }
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

    const AllIconOverlays = {
        enabled: false,
        hasBeenEnabled: false,

        enableOnDOMLoaded: () => {
            onDOMLoaded(() => {
                AllIconOverlays.enable();
            });
        },

        enable: () => {
            if (!AllIconOverlays.hasBeenEnabled) {
                CSS.init();

                onDOMChanged(() => {
                    if (AllIconOverlays.enabled) {
                        VideoThumbnail.bindEventsToAll();
                        Preview.init();
                    }

                    videoPlayerOverlay.watchForVideoBeingAdded();
                });

                window.addEventListener('resize', () => {
                    IconOverlay.repositionHoverOverlay();
                });
            }

            IconOverlay.appendHoverOverlay();
            VideoThumbnail.bindEventsToAll();

            AllIconOverlays.enabled = true;
            AllIconOverlays.hasBeenEnabled = true;

        },

        disable: () => {
            AllIconOverlays.enabled = false;
            IconOverlay.removeAll();
        }

    };

    const OpenInDuckPlayer = {
        clickBoundElements: new Map(),
        enabled: false,

        bindEventsToAll: () => {
            if (!OpenInDuckPlayer.enabled) {
                return;
            }

            let videoLinksAndPreview = Array.from(document.querySelectorAll('a[href^="/watch?v="], #media-container-link')),
                isValidVideoLinkOrPreview = (element) => {
                    return VideoThumbnail.isSingleVideoURL(element?.getAttribute('href')) ||
                        element.getAttribute('id') === 'media-container-link';
                },
                excludeAlreadyBound = (element) => !OpenInDuckPlayer.clickBoundElements.has(element);

            videoLinksAndPreview
                .filter(excludeAlreadyBound)
                .forEach(element => {
                    if (isValidVideoLinkOrPreview(element)) {

                        let onClickOpenDuckPlayer = (event) => {
                            event.preventDefault();
                            event.stopPropagation();

                            let link = event.target.closest('a');

                            if (link) {
                                const href = VideoParams.fromHref(link.href)?.toPrivatePlayerUrl();
                                comms.openInDuckPlayerViaMessage(href);
                            }

                            return false;
                        };

                        element.addEventListener('click', onClickOpenDuckPlayer, true);

                        OpenInDuckPlayer.clickBoundElements.set(element, onClickOpenDuckPlayer);
                    }
                });
        },

        disable: () => {
            OpenInDuckPlayer.clickBoundElements.forEach((functionToRemove, element) => {
                element.removeEventListener('click', functionToRemove, true);
                OpenInDuckPlayer.clickBoundElements.delete(element);
            });

            OpenInDuckPlayer.enabled = false;
        },

        enable: () => {
            OpenInDuckPlayer.enabled = true;
            OpenInDuckPlayer.bindEventsToAll();

            onDOMChanged(() => {
                OpenInDuckPlayer.bindEventsToAll();
            });
        },

        enableOnDOMLoaded: () => {
            OpenInDuckPlayer.enabled = true;
            onDOMLoaded(() => {
                OpenInDuckPlayer.bindEventsToAll();
            });

            onDOMChanged(() => {
                OpenInDuckPlayer.bindEventsToAll();
            });
        }
    }

    // Enable icon overlays on page load if not explicitly disabled
    if ('alwaysAsk' in userValues.privatePlayerMode) {
        AllIconOverlays.enableOnDOMLoaded();
    } else if ('enabled' in userValues.privatePlayerMode) {
        OpenInDuckPlayer.enableOnDOMLoaded();
    }
}
