import {addTrustedEventListener, appendElement, VideoParams} from "./util";
import dax from "../assets/dax.svg";
import {i18n} from "./text.js";

export const IconOverlay = {
    /**
     * Special class used for the overlay hover. For hovering, we use a
     * single element and move it around to the hovered video element.
     */
    HOVER_CLASS: 'ddg-overlay-hover',
    OVERLAY_CLASS: 'ddg-overlay',

    /** @type {HTMLElement | null} */
    currentVideoElement: null,
    hoverOverlayVisible: false,

    /**
     * @type {import("./comms.js").MacOSCommunications | null}
     */
    comms: null,
    /**
     * // todo: when this is a class, pass this as a constructor arg
     * @param {import("./comms.js").MacOSCommunications} comms
     */
    setComms(comms) {
        IconOverlay.comms = comms;
    },
    /**
     * Creates an Icon Overlay.
     * @param {string} size - currently kind-of unused
     * @param {string} href - what, if any, href to set the link to by default.
     * @param {string} [extraClass] - whether to add any extra classes, such as hover
     * @returns {HTMLElement}
     */
    create: (size, href, extraClass) => {
        let overlayElement = document.createElement('div');

        overlayElement.setAttribute('class', 'ddg-overlay' + (extraClass ? ' ' + extraClass : ''));
        overlayElement.setAttribute('data-size', size);
        overlayElement.innerHTML = `
                <a class="ddg-play-privately" href="#">
                    <div class="ddg-dax">
                        ${dax}
                    </div>
                    <div class="ddg-play-text-container">
                        <div class="ddg-play-text">
                            ${i18n.t("playText")}
                        </div>
                    </div>
                </a>`;

        overlayElement.querySelector('a.ddg-play-privately')?.setAttribute('href', href);

        overlayElement.querySelector('a.ddg-play-privately')?.addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();

            // @ts-ignore
            let link = event.target.closest('a');
            let href = link.getAttribute('href');

            IconOverlay.comms?.openInDuckPlayerViaMessage(href);

            return;
        })

        return overlayElement;
    },

    /**
     * Util to return the hover overlay
     * @returns {HTMLElement | null}
     */
    getHoverOverlay: () => {
        return document.querySelector('.' + IconOverlay.HOVER_CLASS);
    },

    /**
     * Moves the hover overlay to a specified videoElement
     * @param {HTMLElement} videoElement - which element to move it to
     */
    moveHoverOverlayToVideoElement: (videoElement) => {
        let overlay = IconOverlay.getHoverOverlay();

        if (overlay === null) {
            return;
        }

        let videoElementOffset = IconOverlay.getElementOffset(videoElement);

        overlay.setAttribute('style', '' +
            'top: ' + videoElementOffset.top + 'px;' +
            'left: ' + videoElementOffset.left + 'px;' +
            'display:block;'
        );

        overlay.setAttribute('data-size', 'fixed ' + IconOverlay.getThumbnailSize(videoElement));

        const href = videoElement.getAttribute('href');

        if (href) {
            const privateUrl = VideoParams.fromPathname(href)?.toPrivatePlayerUrl();
            if (overlay && privateUrl) {
                overlay.querySelector('a')?.setAttribute('href', privateUrl);
            }
        }

        IconOverlay.hoverOverlayVisible = true;
        IconOverlay.currentVideoElement = videoElement;
    },

    /**
     * Return the offset of an HTML Element
     * @param {HTMLElement} el
     * @returns {Object}
     */
    getElementOffset: (el) => {
        const box = el.getBoundingClientRect();
        const docElem = document.documentElement;
        return {
            top: box.top + window.pageYOffset - docElem.clientTop,
            left: box.left + window.pageXOffset - docElem.clientLeft,
        };
    },

    /**
     * Reposition the hover overlay on top of the current video element (in case
     * of window resize if the hover overlay is visible)
     */
    repositionHoverOverlay: () => {
        if (IconOverlay.currentVideoElement && IconOverlay.hoverOverlayVisible) {
            IconOverlay.moveHoverOverlayToVideoElement(IconOverlay.currentVideoElement)
        }
    },

    /**
     * Hides the hover overlay element, but only if mouse pointer is outside of the hover overlay element
     */
    hideHoverOverlay: (event, force) => {
        let overlay = IconOverlay.getHoverOverlay();

        let toElement = event.toElement;

        if (overlay) {
            // Prevent hiding overlay if mouseleave is triggered by user is actually hovering it and that
            // triggered the mouseleave event
            if (toElement === overlay || overlay.contains(toElement) || force) {
                return;
            }

            IconOverlay.hideOverlay(overlay);
            IconOverlay.hoverOverlayVisible = false;
        }

    },

    /**
     * Util for hiding an overlay
     * @param {HTMLElement} overlay
     */
    hideOverlay: (overlay) => {
        overlay.setAttribute('style', 'display:none;');
    },

    /**
     * Appends the Hover Overlay to the page. This is the one that is shown on hover of any video thumbnail.
     * More performant / clean than adding an overlay to each and every video thumbnail. Also it prevents triggering
     * the video hover preview on the homepage if the user hovers the overlay, because user is no longer hovering
     * inside a video thumbnail when hovering the overlay. Nice.
     */
    appendHoverOverlay: () => {
        let el = IconOverlay.create('fixed', '', IconOverlay.HOVER_CLASS);
        appendElement(document.body, el);

        // Hide it if user clicks anywhere on the page but in the icon overlay itself
        addTrustedEventListener(document.body, 'mouseup', (event) => {
            IconOverlay.hideHoverOverlay(event);
        });
    },

    /**
     * Appends an overlay (currently just used for the video hover preview)
     * @param {HTMLElement} videoElement - to append to
     * @returns {boolean} - whether the overlay was appended or not
     */
    appendToVideo: (videoElement) => {
        let appendOverlayToThumbnail = (videoElement) => {
            if (videoElement) {
                const privateUrl = VideoParams.fromHref(videoElement.href)?.toPrivatePlayerUrl();
                const thumbSize = IconOverlay.getThumbnailSize(videoElement);
                if (privateUrl) {
                    appendElement(videoElement, IconOverlay.create(thumbSize, privateUrl));
                    videoElement.classList.add('has-dgg-overlay');
                }
            }
        };

        let videoElementAlreadyHasOverlay = videoElement && videoElement.querySelector('div[class="ddg-overlay"]');

        if (!videoElementAlreadyHasOverlay) {
            appendOverlayToThumbnail(videoElement);
            return true;
        }

        return false;
    },

    getThumbnailSize: (videoElement) => {
        let imagesByArea = {};

        Array.from(videoElement.querySelectorAll('img')).forEach(image => {
            imagesByArea[(image.offsetWidth * image.offsetHeight)] = image;
        });

        let largestImage = Math.max.apply(this, Object.keys(imagesByArea).map(Number));

        let getSizeType = (width, height) => {
            if (width < (123 + 10)) { // match CSS: width of expanded overlay + twice the left margin.
                return 'small';
            } else if (width < 300 && height < 175) {
                return 'medium';
            } else {
                return 'large';
            }
        }

        return getSizeType(imagesByArea[largestImage].offsetWidth, imagesByArea[largestImage].offsetHeight);
    },

    removeAll: () => {
        document.querySelectorAll('.' + IconOverlay.OVERLAY_CLASS).forEach(element => {
            element.remove();
        });
    }
};
