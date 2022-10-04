import {appendElement, execCleanups} from "./util";
import {IconOverlay} from "./icon-overlay";

export class VideoPlayerIcon {
    /** @type {{fn: () => void, name: string}[]} */
    cleanups = [];

    /**
     * This will only get called once everytime a new video is loaded.
     *
     * @param {Element} containerElement
     * @param {import("./util").VideoParams} params
     */
    init(containerElement, params) {

        if (!containerElement) {
            console.error("missing container element");
            return;
        }

        this.appendOverlay(containerElement, params);

        // let hasTitle = !document.querySelector('#player .ytp-hide-info-bar');
        // let hasPaidContentElement = document.querySelector('.ytp-paid-content-overlay-link');
        // // @ts-ignore
        // let hasPaidContent = hasPaidContentElement && hasPaidContentElement.offsetWidth > 0;
        // let isAds = document.querySelector('#player .ad-showing');
        //
        // // @ts-ignore
        // let vpiClasses = document.querySelector('.ddg-overlay[data-size^="video-player"]').classList;
        //
        // if (isAds) {
        //     console.log('isAds, maybe hide?');
        //     if (!vpiClasses.contains('hidden')) {
        //         console.log('isAds, hide');
        //         // vpiClasses.add('hidden');
        //     }
        // } else {
        //     if (vpiClasses.contains('hidden')) {
        //         console.log('is not ads, show after 50ms');
        //
        //         // setTimeout(() => {
        //         //     if (!document.querySelector('#player .ad-showing') && vpiClasses.contains('hidden')) {
        //         //         vpiClasses.remove('hidden');
        //         //     }
        //         // }, 50);
        //     }
        // }
        //
        // if (hasPaidContent) {
        //     console.log('they just showed paid content, update position');
        //     // if (document.querySelector('.ddg-overlay[data-size="video-player"]')) {
        //     //     document.querySelector('.ddg-overlay[data-size="video-player"]')?.setAttribute('data-size', 'video-player-with-paid-content');
        //     // }
        // } else {
        //     console.log('they just hid paid content, update position');
        //     // if (document.querySelector('.ddg-overlay[data-size="video-player-with-paid-content"]')) {
        //     //     document.querySelector('.ddg-overlay[data-size="video-player-with-paid-content"]')?.setAttribute('data-size', 'video-player');
        //     // }
        // }
        //
        // /*if (hasTitle) {
        //     console.log('they just hid the infobar, move the icon');
        //     document.querySelector('.ddg-overlay[data-size="video-player"]').setAttribute('data-size', 'video-player-with-title');
        // } else {
        //     console.log('infobar not hidden anymore, show icon');
        //     document.querySelector('.ddg-overlay[data-size="video-player-with-title"]').setAttribute('data-size', 'video-player');
        // }*/
    }

    /**
     * @param {Element} containerElement
     * @param {import("./util").VideoParams} params
     */
    appendOverlay(containerElement, params) {
        this.cleanup();
        const href = params.toPrivatePlayerUrl();
        const iconElement = IconOverlay.create('video-player', href, 'hidden');
        appendElement(containerElement, iconElement);
        iconElement.classList.remove('hidden')
        this.cleanups.push({
            name: "removing dax 🐥 icon overlay",
            fn() {
                containerElement?.removeChild(iconElement)
            }
        })
    }

    /**
     * Remove elements, event listeners etc
     */
    cleanup() {
        execCleanups(this.cleanups);
        this.cleanups = [];
    }
}
