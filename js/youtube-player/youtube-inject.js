import css from "./assets/styles.css";
import {VideoOverlayManager} from "./src/video-overlay-manager.js";
import {IconOverlay} from "./src/icon-overlay.js";
import {onDOMLoaded, onDOMChanged, addTrustedEventListener, appendElement, VideoParams} from "./src/util.js";
import {Communications} from "./src/comms";

/**
 * @typedef UserValues - A way to communicate some user state
 * @property {{enabled: {}} | {alwaysAsk:{}} | {disabled:{}}} privatePlayerMode - one of 3 values: 'enabled:{}', 'alwaysAsk:{}', 'disabled:{}'
 * @property {boolean} overlayInteracted - always a boolean
 */
const userScriptConfig = $DDGYoutubeUserScriptConfig$;

/** @type {string[]} */
const allowedProxyOrigins = userScriptConfig.allowedOrigins.filter(origin => !origin.endsWith('youtube.com'));

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
    },
    overlaysEnabled() {
        if (userScriptConfig.testMode === "overlay-enabled") {
            return true;
        }
        return window.location.hostname === "www.youtube.com"
    },
    enabledProxy() {
        return allowedProxyOrigins.includes(window.location.hostname)
    },
    isTestMode() {
        return typeof userScriptConfig.testMode === "string"
    },
    /**
     * @returns {boolean}
     */
    hasOneTimeOverride() {
        try {
            // #ddg-play is a hard requirement, regardless of referrer
            if (window.location.hash !== "#ddg-play") return false

            // double-check that we have something that might be a parseable URL
            if (typeof document.referrer !== "string") return false
            if (document.referrer.length === 0) return false; // can be empty!

            const { hostname } = new URL(document.referrer);
            const isAllowed = allowedProxyOrigins.includes(hostname)
            return isAllowed;
        } catch (e) {
            if (userScriptConfig.testMode) {
                console.log("could not evaluate hasOneTimeOverride")
                console.error(e)
            }
        }
        return false
    }
}

if (defaultEnvironment.overlaysEnabled()) {
    try {
        const comms = Communications.fromInjectedConfig(
            userScriptConfig.webkitMessagingConfig
        )
        initWithEnvironment(defaultEnvironment, comms)
    } catch (e) {
        if (userScriptConfig.testMode) {
            console.log("failed to init overlays")
            console.error(e);
        }
    }
}

if (defaultEnvironment.enabledProxy()) {
    try {
        const comms = Communications.fromInjectedConfig(
            userScriptConfig.webkitMessagingConfig
        )
        comms.serpProxy();
    } catch (e) {
        if (userScriptConfig.testMode) {
            console.log("failed to init proxy")
            console.error(e);
        }
    }
}

/**
 * @param {typeof defaultEnvironment} environment - methods to read environment-sensitive things like the current URL etc
 * @param {Communications} comms - methods to communicate with a native backend
 */
function initWithEnvironment(environment, comms) {
    /**
     * Entry point. Until this returns with initial user values, we cannot continue.
     */
    comms.readUserValues()
        .then((userValues) => enable(userValues))
        .catch(e => console.error(e))

    /**
     * @param {UserValues} userValues - user values are state-based things that can update
     */
    function enable(userValues) {
        const videoPlayerOverlay = new VideoOverlayManager(userValues, environment, comms);
        videoPlayerOverlay.handleFirstPageLoad();

        // give access to macos communications
        // todo: make this a class + constructor arg
        IconOverlay.setComms(comms);

        comms.onUserValuesNotification((userValues) => {
            videoPlayerOverlay.userValues = userValues;
            videoPlayerOverlay.watchForVideoBeingAdded({ via: "user notification", ignoreCache: true });

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
        }, userValues);

        const CSS = {
            styles: css,
            /**
             * Initialize the CSS by adding it to the page in a <style> tag
             */
            init: () => {
                let style = document.createElement("style");
                style.textContent = CSS.styles;
                appendElement(document.head, style);
            }
        }

        const VideoThumbnail = {
            hoverBoundElements: new WeakMap(),

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

                const linksNotAlreadyBound = item => {
                    return !VideoThumbnail.hoverBoundElements.has(item);
                }

                return Array.from(document.querySelectorAll('a[href^="/watch?v="]'))
                    .filter(linksNotAlreadyBound)
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

                    VideoThumbnail.hoverBoundElements.set(video, true);
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

                        videoPlayerOverlay.watchForVideoBeingAdded({ via: "mutation observer" });
                    });

                    window.addEventListener('resize', IconOverlay.repositionHoverOverlay);

                    window.addEventListener('scroll', IconOverlay.hidePlaylistOverlayOnScroll, true);
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
            /** @type {string|null} */
            lastMouseOver: null,
            bindEventsToAll: () => {
                if (!OpenInDuckPlayer.enabled) {
                    return
                }

                const videoLinksAndPreview = Array.from(document.querySelectorAll('a[href^="/watch?v="], #media-container-link'))
                const isValidVideoLinkOrPreview = (element) => {
                    return VideoThumbnail.isSingleVideoURL(element?.getAttribute('href')) ||
                        element.getAttribute('id') === 'media-container-link'
                }
                videoLinksAndPreview
                    .forEach((element) => {
                        // bail when this element was already seen
                        if (OpenInDuckPlayer.clickBoundElements.has(element)) return

                        // bail if it's not a valid element
                        if (!isValidVideoLinkOrPreview(element)) return

                        // handle mouseover + click events
                        const handler = {
                            handleEvent (event) {
                                switch (event.type) {
                                    case 'mouseover': {
                                        /**
                                         * Store the element's link value on hover - this occurs just in time
                                         * before the youtube overlay take sover the event space
                                         */
                                        const href = element instanceof HTMLAnchorElement
                                            ? VideoParams.fromHref(element.href)?.toPrivatePlayerUrl()
                                            : null
                                        if (href) {
                                            OpenInDuckPlayer.lastMouseOver = href
                                        }
                                        break
                                    }
                                    case 'click': {
                                        /**
                                         * On click, the receiver might be the preview element - if
                                         * it is, we want to use the last hovered `a` tag instead
                                         */
                                        event.preventDefault()
                                        event.stopPropagation()

                                        const link = event.target.closest('a')
                                        const fromClosest = VideoParams.fromHref(link?.href)?.toPrivatePlayerUrl()

                                        if (fromClosest) {
                                            comms.openInDuckPlayerViaMessage(fromClosest)
                                        } else if (OpenInDuckPlayer.lastMouseOver) {
                                            comms.openInDuckPlayerViaMessage(OpenInDuckPlayer.lastMouseOver)
                                        } else {
                                            // could not navigate, doing nothing
                                        }

                                        break
                                    }
                                }
                            }
                        }

                        // register both handlers
                        element.addEventListener('mouseover', handler, true)
                        element.addEventListener('click', handler, true)

                        // store the handler for removal later (eg: if settings change)
                        OpenInDuckPlayer.clickBoundElements.set(element, handler)
                    })
            },

            disable: () => {
                OpenInDuckPlayer.clickBoundElements.forEach((handler, element) => {
                    element.removeEventListener('mouseover', handler, true)
                    element.removeEventListener('click', handler, true)
                    OpenInDuckPlayer.clickBoundElements.delete(element)
                })

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

                    onDOMChanged(() => {
                        OpenInDuckPlayer.bindEventsToAll();
                    });
                });
            }
        };

        // Enable icon overlays on page load if not explicitly disabled
        if ('alwaysAsk' in userValues.privatePlayerMode) {
            AllIconOverlays.enableOnDOMLoaded();
        } else if ('enabled' in userValues.privatePlayerMode) {
            OpenInDuckPlayer.enableOnDOMLoaded();
        }
    }
}
