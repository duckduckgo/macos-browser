import {Util} from "./util";
import {IconOverlay} from "./icon-overlay";

export const VideoPlayerIcon = {
    hasAddedVideoPlayerIcon: false,

    /**
     * @param {import("../youtube-inject.js").UserValues} userValues
     */
    init: (userValues) => {
        if (typeof userValues.privatePlayerEnabled === "boolean") {
            // console.log("bailing because `userValues.privatePlayerEnabled` was set")
            return;
        }
        if (!userValues.overlayInteracted) {
            // console.log("bailing because `userValues.overlayInteracted` was not true")
            return;
        }

        let videoId = Util.getYoutubeVideoId();

        if (videoId) {
            console.log("🦆 show small dax overlay on video")
            let videoPlayer = document.querySelector('#player');

            if (videoPlayer) {
                console.log('add vpi');

                Util.appendElement(
                    videoPlayer,
                    IconOverlay.create('video-player', window.location.pathname + window.location.search, 'hidden')
                );

                console.log('addClass', videoPlayer);
                videoPlayer.classList.add('has-ddg-overlay');
                VideoPlayerIcon.hasAddedVideoPlayerIcon = true;
            }

            if (VideoPlayerIcon.hasAddedVideoPlayerIcon) {

                let hasTitle = !document.querySelector('#player .ytp-hide-info-bar');
                // @ts-ignore
                let hasPaidContent = document.querySelector('.ytp-paid-content-overlay-link').offsetWidth > 0;
                let isAds = document.querySelector('#player .ad-showing');

                // @ts-ignore
                let vpiClasses = document.querySelector('.ddg-overlay[data-size^="video-player"]').classList;

                if (isAds) {
                    if (!vpiClasses.contains('hidden')) {
                        console.log('isAds, hide');
                        vpiClasses.add('hidden');
                    }
                } else {
                    if (vpiClasses.contains('hidden')) {
                        console.log('is not ads, show after 50ms');

                        setTimeout(() => {
                            if (!document.querySelector('#player .ad-showing') && vpiClasses.contains('hidden')) {
                                vpiClasses.remove('hidden');
                            }
                        }, 50);
                    }
                }

                if (hasPaidContent) {
                    console.log('they just showed paid content, update position');
                    if (document.querySelector('.ddg-overlay[data-size="video-player"]')) {
                        document.querySelector('.ddg-overlay[data-size="video-player"]')?.setAttribute('data-size', 'video-player-with-paid-content');
                    }
                } else {
                    console.log('they just hid paid content, update position');
                    if (document.querySelector('.ddg-overlay[data-size="video-player-with-paid-content"]')) {
                        document.querySelector('.ddg-overlay[data-size="video-player-with-paid-content"]')?.setAttribute('data-size', 'video-player');
                    }
                }

                /*if (hasTitle) {
                    console.log('they just hid the infobar, move the icon');
                    document.querySelector('.ddg-overlay[data-size="video-player"]').setAttribute('data-size', 'video-player-with-title');
                } else {
                    console.log('infobar not hidden anymore, show icon');
                    document.querySelector('.ddg-overlay[data-size="video-player-with-title"]').setAttribute('data-size', 'video-player');
                }*/
            }
        }
    }
}
