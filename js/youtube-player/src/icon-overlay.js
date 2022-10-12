import {addTrustedEventListener, appendElement, VideoParams} from "./util";
import dax from "../assets/dax.svg";
import {i18n} from "./text.js";
import css from "../assets/styles.css"

class DDGIconOverlay extends HTMLElement {
    constructor(size, href) {
        super();

        this.size = size;
        this.href = href;

        /**
         * Create the shadow root, closed to prevent any outside observers
         * @type {ShadowRoot}
         */
         const shadow = this.attachShadow({ mode: "closed" });

         /**
          * Add our styles
          * @type {HTMLStyleElement}
          */
         let style = document.createElement("style");
         style.textContent = css;

         /**
          * Create the overlay
          * @type {HTMLDivElement}
          */
         const overlay = this.createOverlay();

         /**
          * Append both to the shadow root
          */
         shadow.appendChild(overlay)
         shadow.appendChild(style);

         this.root = shadow;
    }

    /**
     * @returns {HTMLDivElement}
     */
    createOverlay() {
        let overlayElement = document.createElement('div');

        overlayElement.setAttribute('class', 'ddg-overlay');
        overlayElement.setAttribute('data-size', this.size);
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

        overlayElement.querySelector('a.ddg-play-privately')?.setAttribute('href', this.href);

        return overlayElement;
    }

    static get observedAttributes() { return ['href', 'data-size']; }

    attributeChangedCallback(name, oldValue, newValue) {
        if (name === 'href') {
            this.root.querySelector('a.ddg-play-privately').setAttribute('href', newValue);
        }

        if (name === 'data-size') {
            console.log('change size', oldValue, newValue);
            console.trace();
            this.root.querySelector('.ddg-overlay').setAttribute('data-size', newValue);
        }
    }
}

customElements.define('ddg-icon-overlay', DDGIconOverlay);

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
        let el = new DDGIconOverlay(size, href);

        if (extraClass) {
            el.setAttribute('class', extraClass);
        }

        return el;
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
                'display:block;'+
                'position:absolute;'
            );

            overlay.setAttribute('data-size', 'fixed ' + IconOverlay.getThumbnailSize(videoElement));

            const href = videoElement.getAttribute('href');

            if (href) {
                const privateUrl = VideoParams.fromPathname(href)?.toPrivatePlayerUrl();
                if (overlay && privateUrl) {
                    overlay.setAttribute('href', privateUrl);
                }
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
        console.log('append to video', videoElement);

        let appendOverlayToThumbnail = (videoElement) => {
            if (videoElement) {
                const privateUrl = VideoParams.fromHref(videoElement.href)?.toPrivatePlayerUrl();
                const thumbSize = IconOverlay.getThumbnailSize(videoElement);
                if (privateUrl) {
                    console.log('append IconOverlay with privateURL', privateUrl);
                    let overlay = IconOverlay.create(thumbSize, privateUrl);
                    //overlay.setAttribute('style', 'z-index:1000;');
                    appendElement(videoElement, overlay);
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
