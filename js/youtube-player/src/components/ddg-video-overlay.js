import css from "../../assets/video-overlay.css";
import dax from "../../assets/dax.svg";
import {i18n} from "../text.js";
import {appendImageAsBackground} from "../util.js";
import {VideoOverlayManager} from "../video-overlay-manager.js";

/**
 * The custom element that we use to present our UI elements
 * over the YouTube player
 */
export class DDGVideoOverlay extends HTMLElement {
    static CUSTOM_TAG_NAME = 'ddg-video-overlay'
    /**
     * @param {{
     *  getHref(): string,
     *  getLargeThumbnailSrc(videoId: string): string,
     *  setHref(href: string): void,
     *  isTestMode(): boolean
     * }} environment
     * @param {import("../util").VideoParams} params
     * @param {VideoOverlayManager} manager
     */
    constructor(environment, params, manager) {
        super();
        if (!(manager instanceof VideoOverlayManager)) throw new Error('invalid arguments');
        this.environment = environment;
        this.params = params;
        this.manager = manager;

        /**
         * Create the shadow root, closed to prevent any outside observers
         * @type {ShadowRoot}
         */
        const shadow = this.attachShadow({ mode: this.environment.isTestMode() ? "open" : "closed" });

        /**
         * Add our styles
         * @type {HTMLStyleElement}
         */
        let style = document.createElement("style");
        style.innerText = css;

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
    }

    /**
     * @returns {HTMLDivElement}
     */
    createOverlay() {
        let overlayElement = document.createElement('div');
        overlayElement.classList.add('ddg-video-player-overlay');
        overlayElement.innerHTML = `
            <div class="ddg-vpo-bg"></div>
            <div class="ddg-vpo-content">
                <div class="ddg-eyeball">${dax}</div>
                <div class="ddg-vpo-title">${i18n.t("videoOverlayTitle")}</div>
                <div class="ddg-vpo-text">${i18n.t("videoOverlaySubtitle")}</div>
                <div class="ddg-vpo-buttons">
                    <button class="ddg-vpo-button ddg-vpo-cancel" type="button">${i18n.t("videoButtonOptOut")}</button>
                    <a class="ddg-vpo-button ddg-vpo-open" href="#">${i18n.t("videoButtonOpen")}</a>
                </div>
                <div class="ddg-vpo-remember">
                    <label for="remember">
                        <input id="remember" type="checkbox" name="ddg-remember"> ${i18n.t("rememberLabel")}
                    </label>
                </div>
            </div>
            `;
        /**
         * Set the link
         * @type {string}
         */
        const href = this.params.toPrivatePlayerUrl();
        overlayElement.querySelector('.ddg-vpo-open')?.setAttribute("href", href)

        /**
         * Add thumbnail
         */
        this.appendThumbnail(overlayElement, this.params.id)

        /**
         * Setup the click handlers
         */
        this.setupButtonsInsideOverlay(overlayElement, this.params)

        return overlayElement;
    }

    /**
     * @param {HTMLElement} overlayElement
     * @param {string} videoId
     */
    appendThumbnail(overlayElement, videoId) {
        const imageUrl = this.environment.getLargeThumbnailSrc(videoId);
        appendImageAsBackground(overlayElement, '.ddg-vpo-bg', imageUrl);
    }

    /**
     * @param {HTMLElement} containerElement
     * @param {import("../util").VideoParams} params
     */
    setupButtonsInsideOverlay(containerElement, params) {
        const cancelElement = containerElement.querySelector('.ddg-vpo-cancel');
        const watchInPlayer = containerElement.querySelector('.ddg-vpo-open');
        if (!cancelElement) return console.warn("Could not access .ddg-vpo-cancel");
        if (!watchInPlayer) return console.warn("Could not access .ddg-vpo-open");
        const optOutHandler = (e) => {
            if (e.isTrusted) {
                const remember = containerElement.querySelector('input[name="ddg-remember"]');
                if (!(remember instanceof HTMLInputElement)) throw new Error('cannot find our input');
                this.manager.userOptOut(remember.checked, params);
            }
        };
        const watchInPlayerHandler = (e) => {
            if (e.isTrusted) {
                e.preventDefault();
                const remember = containerElement.querySelector('input[name="ddg-remember"]');
                if (!(remember instanceof HTMLInputElement)) throw new Error('cannot find our input');
                this.manager.userOptIn(remember.checked, params);
            }
        }
        cancelElement.addEventListener("click", optOutHandler);
        watchInPlayer.addEventListener("click", watchInPlayerHandler);
    }
}

customElements.define(DDGVideoOverlay.CUSTOM_TAG_NAME, DDGVideoOverlay)
