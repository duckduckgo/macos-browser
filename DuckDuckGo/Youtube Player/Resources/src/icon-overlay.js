import {Util} from "./util";
import dax from "../assets/dax.svg";

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
     * Creates an Icon Overlay.
     * @param {string} size - currently kind-of unused
     * @param {string} href - what, if any, href to set the link to by default.
     * @param {string} [extraClass] - whether to add any extra classes, such as hover
     * @returns {HTMLElement}
     */
    create: (size, href, extraClass) => {
        let overlayElement = document.createElement('div');
        let videoURL = Util.getPrivatePlayerURL(href);

        overlayElement.setAttribute('class', 'ddg-overlay' + (extraClass ? ' ' + extraClass : ''));
        overlayElement.setAttribute('data-size', size);
        overlayElement.innerHTML = `
                <a class="ddg-play-privately" href="#">
                    <div class="ddg-dax">
                        ${dax}
                    </div>
                    <div class="ddg-play-text-container">
                        <div class="ddg-play-text">
                            Watch Privately
                        </div>
                    </div>
                </a>`;

        overlayElement.querySelector('a.ddg-play-privately')?.setAttribute('href', videoURL);

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

        if (overlay !== null) {
            let offset = (el) => {
                const box = el.getBoundingClientRect();
                const docElem = document.documentElement;
                return {
                    top: box.top + window.pageYOffset - docElem.clientTop,
                    left: box.left + window.pageXOffset - docElem.clientLeft,
                };
            }

            let videoElementOffset = offset(videoElement);

            overlay.setAttribute('style', '' +
                'top: ' + videoElementOffset.top + 'px;' +
                'left: ' + videoElementOffset.left + 'px;' +
                'display:block;'
            );

            overlay.setAttribute('data-size', 'fixed ' + IconOverlay.getThumbnailSize(videoElement));

            const href = videoElement.getAttribute('href');

            if (href) {
                overlay.querySelector('a')?.setAttribute('href', Util.getPrivatePlayerURL(href));
            }

            IconOverlay.hoverOverlayVisible = true;
            IconOverlay.currentVideoElement = videoElement;
        }
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
        Util.appendElement(document.body, el);

        // Hide it if user clicks anywhere on the page but in the icon overlay itself
        Util.addTrustedEventListener(document.body, 'mouseup', (event) => {
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

                Util.appendElement(
                    videoElement,
                    IconOverlay.create(
                        IconOverlay.getThumbnailSize(videoElement), videoElement.getAttribute('href')
                    )
                );

                videoElement.classList.add('has-dgg-overlay');
            }
        };

        let videoElementAlreadyHasOverlay = videoElement && videoElement.querySelector('div[class="ddg-overlay"]');

        if (!videoElementAlreadyHasOverlay) {
            appendOverlayToThumbnail(videoElement);
            return true;
        } else {
            return false;
        }
    },

    getThumbnailSize: (videoElement) => {
        let imagesByArea = {};
        let images = Array.from(videoElement.querySelectorAll('img')).forEach(image => {
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
        document.querySelectorAll(IconOverlay.OVERLAY_CLASS).forEach(element => {
            element.remove();
        });

        document.querySelectorAll('.ddg-has-overlay').forEach(element => {
            element.classList.remove('ddg-has-overlay');
        });
    }
};
