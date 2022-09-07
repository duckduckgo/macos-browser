
function enable() {
    console.log('Injected and ran YouTube Icon Overlay script.');
    
    const Icons = {
        dax: `
        <svg width="24" height="25" viewBox="0 0 24 25" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M14.1402 21.1305C13.7869 20.4466 13.4176 19.4487 13.2017 19.0185C12.5115 17.6243 11.8165 15.6598 12.1321 14.3924C12.1894 14.1617 11.4812 5.86527 10.9807 5.59664C10.4246 5.29834 9.216 4.90445 8.5896 4.79897C8.15292 4.7281 8.05479 4.85171 7.87162 4.87973C8.04498 4.89785 8.866 5.30493 9.02465 5.328C8.866 5.43677 8.39661 5.32471 8.09732 5.4582C7.94521 5.52907 7.83236 5.78946 7.83563 5.91142C8.691 5.82407 10.0272 5.90977 10.8188 6.26246C10.1891 6.33497 9.23236 6.41573 8.82184 6.63327C7.62792 7.26613 7.10129 8.74775 7.41531 10.5244C7.70643 12.1774 8.99537 18.6139 9.51709 21.1305C10.4362 21.447 11.1212 21.6064 12.145 21.6064C13.1395 21.6064 13.5841 21.2376 14.1402 21.1305Z" fill="#D5D7D8"/>
                <path fill-rule="evenodd" clip-rule="evenodd" d="M9.98431 21.2998C9.80923 20.0461 9.49398 18.7306 9.23216 17.4923C8.65596 14.7671 7.93939 11.3779 7.72236 10.1651C7.40449 8.382 7.72236 7.10886 8.9359 6.46981C9.35145 6.25127 9.94414 6.09233 10.5799 6.02114C9.77859 5.66519 8.82828 5.52778 7.9591 5.61553C7.95693 5.37438 8.23556 5.30072 8.49618 5.23181C8.63279 5.1957 8.76446 5.16089 8.84815 5.10395C8.77135 5.09287 8.64002 5.00492 8.50451 4.91416C8.35667 4.81515 8.20384 4.71281 8.11142 4.7033C9.21403 4.51457 10.3481 4.69171 11.3381 5.21157C11.8431 5.48308 12.2007 5.77281 12.4209 6.07578C12.9954 6.1867 13.5036 6.39365 13.8364 6.72642C14.8579 7.74626 15.7685 10.074 15.3877 11.4134C15.2801 11.7842 15.035 12.0557 14.7271 12.2792C14.49 12.452 14.3637 12.4084 14.2048 12.3537C13.9631 12.2705 13.6463 12.1614 12.7503 12.7478C12.6178 12.8338 12.576 13.3034 12.5437 13.6657C12.5288 13.833 12.5159 13.9775 12.497 14.0507C12.1792 15.3238 12.8795 17.2956 13.5798 18.6979C13.7139 18.9652 13.8898 19.3023 14.0885 19.683C14.1984 19.8935 14.5199 20.7096 14.6405 20.9424C12.4209 21.7688 12.1751 21.8631 9.98431 21.2998Z" fill="white"/>
                <path d="M9.85686 10.7012C10.2514 10.7012 10.5711 10.4213 10.5711 10.0762C10.5711 9.73099 10.2514 9.45117 9.85686 9.45117C9.46237 9.45117 9.14258 9.73099 9.14258 10.0762C9.14258 10.4213 9.46237 10.7012 9.85686 10.7012Z" fill="#2D4F8E"/>
                <path d="M10.1725 10.0697C10.2684 10.0697 10.346 9.99199 10.346 9.89617C10.346 9.80034 10.2684 9.72266 10.1725 9.72266C10.0767 9.72266 9.99902 9.80034 9.99902 9.89617C9.99902 9.99199 10.0767 10.0697 10.1725 10.0697Z" fill="white"/>
                <path d="M14.2666 10.5036C14.5541 10.5036 14.7872 10.2317 14.7872 9.89635C14.7872 9.56095 14.5541 9.28906 14.2666 9.28906C13.9791 9.28906 13.7461 9.56095 13.7461 9.89635C13.7461 10.2317 13.9791 10.5036 14.2666 10.5036Z" fill="#2D4F8E"/>
                <path d="M14.469 9.80991C14.5489 9.80991 14.6137 9.73223 14.6137 9.6364C14.6137 9.54057 14.5489 9.46289 14.469 9.46289C14.389 9.46289 14.3242 9.54057 14.3242 9.6364C14.3242 9.73223 14.389 9.80991 14.469 9.80991Z" fill="white"/>
                <path d="M9.9291 8.30723C9.9291 8.30723 9.46635 8.09871 9.01725 8.37923C8.56968 8.65825 8.58485 8.94177 8.58485 8.94177C8.58485 8.94177 8.34664 8.41673 8.98084 8.15872C9.61959 7.9037 9.9291 8.30723 9.9291 8.30723Z" fill="#2D4F8E"/>
                <path d="M14.6137 8.20731C14.6137 8.20731 14.2487 8.06408 13.9655 8.06637C13.3839 8.07095 13.2256 8.24741 13.2256 8.24741C13.2256 8.24741 13.3239 7.82689 14.0671 7.91168C14.3087 7.94147 14.5137 8.05147 14.6137 8.20731Z" fill="#2D4F8E"/>
                <path d="M12.0108 12.8643C12.0749 12.4677 13.061 11.7199 13.7612 11.673C14.4613 11.6276 14.6786 11.639 15.2615 11.4933C15.846 11.3492 17.3526 10.9607 17.7668 10.7616C18.1841 10.5625 19.9501 10.8604 18.7061 11.5807C18.1669 11.8931 16.715 12.4661 15.6772 12.7883C14.6411 13.1088 14.0112 12.4807 13.6674 13.01C13.3939 13.4293 13.6127 14.0039 14.8505 14.1237C16.5243 14.284 18.1278 13.3435 18.3044 13.8437C18.481 14.3439 16.8681 14.9654 15.8835 14.9865C14.9005 15.0059 12.9188 14.3131 12.6234 14.0994C12.3249 13.8858 11.9295 13.3839 12.0108 12.8643Z" fill="#FDD20A"/>
                <path d="M15.4382 16.7912C15.1405 16.7224 13.9976 17.5417 13.5494 17.8742C13.5312 17.8003 13.5164 17.7398 13.5015 17.7063C13.4287 17.5232 12.3288 17.6273 12.0377 17.9044C11.3431 17.5535 9.91412 16.8835 9.88434 17.2949C9.84134 17.8423 9.88434 20.072 10.1738 20.2415C10.3855 20.3658 11.5482 19.7261 12.1601 19.3718C12.1783 19.3785 12.1949 19.3836 12.2164 19.3903C12.5885 19.4759 13.2931 19.3903 13.5428 19.2224C13.5676 19.2056 13.5875 19.1771 13.6024 19.1435C14.1663 19.3651 15.3158 19.7916 15.5623 19.6992C15.893 19.5683 15.8103 16.8768 15.4382 16.7912Z" fill="#65BC46"/>
                <path d="M12.3032 19.2499C11.9194 19.1671 12.0491 18.7948 12.0491 17.9243L12.0474 17.9226C12.0474 17.921 12.0491 17.9177 12.0491 17.916C11.9484 17.9739 11.8836 18.0418 11.8836 18.1179H11.8853C11.8853 18.9884 11.7557 19.3624 12.1394 19.4451C12.5249 19.5279 13.2514 19.4451 13.509 19.2797C13.5516 19.2515 13.5806 19.1969 13.5994 19.1241C13.2992 19.2631 12.6562 19.3277 12.3032 19.2499Z" fill="#43A244"/>
                <path fill-rule="evenodd" clip-rule="evenodd" d="M12 22.1299C17.5228 22.1299 22 17.6527 22 12.1299C22 6.60704 17.5228 2.12988 12 2.12988C6.47715 2.12988 2 6.60704 2 12.1299C2 17.6527 6.47715 22.1299 12 22.1299ZM12 21.1299C16.9706 21.1299 21 17.1004 21 12.1299C21 7.15932 16.9706 3.12988 12 3.12988C7.02944 3.12988 3 7.15932 3 12.1299C3 17.1004 7.02944 21.1299 12 21.1299Z" fill="white"/>
            </svg>
        `,

        play: `
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="0.625" y="3.125" width="18.75" height="13.75" rx="2.375" stroke="white" stroke-width="1.25"/>
                <path fill-rule="evenodd" clip-rule="evenodd" d="M13.0588 10.642C13.5624 10.3576 13.5624 9.64292 13.0588 9.35853L8.93913 7.03194C8.4377 6.74875 7.8125 7.10486 7.8125 7.67366L7.8125 12.3268C7.8125 12.8956 8.4377 13.2517 8.93913 12.9685L13.0588 10.642Z" fill="white"/>
            </svg>
        `,

        eyeball: `
            <svg width="52" height="52" viewBox="0 0 52 52" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M9.94816 17.9071C5.48524 26.7822 9.05984 37.5983 17.9323 42.0655C26.8047 46.5327 37.6151 42.9594 42.078 34.0843C46.5409 25.2092 42.9663 14.3932 34.0939 9.92595C25.2215 5.45874 14.4111 9.03204 9.94816 17.9071Z" fill="#C7B9EE"/>
                <path opacity="0.5" d="M33.6359 42.2915C29.327 43.1601 24.8489 42.4196 21.0477 40.21C17.2466 38.0003 14.3857 34.4745 13.0057 30.2989C11.6257 26.1232 11.8221 21.5868 13.5579 17.547C15.2936 13.5072 18.4484 10.2437 22.4262 8.3732C19.9329 8.87583 17.5745 9.90196 15.5071 11.3838C13.4396 12.8657 11.71 14.7696 10.4325 16.9698C9.15501 19.1699 8.35867 21.6163 8.09608 24.1474C7.83349 26.6785 8.11062 29.2366 8.90918 31.6529C9.70774 34.0692 11.0096 36.2887 12.7287 38.1647C14.4478 40.0408 16.545 41.5307 18.882 42.5362C21.2189 43.5416 23.7423 44.0397 26.2856 43.9975C28.8289 43.9554 31.3341 43.3739 33.6359 42.2915Z" fill="#A591DC"/>
                <path d="M28.8678 19.6448C23.7034 20.8278 20.4737 25.9737 21.6541 31.1384C22.8345 36.3032 27.9779 39.531 33.1423 38.3479C38.3066 37.1649 41.5363 32.019 40.3559 26.8543C39.1756 21.6895 34.0321 18.4617 28.8678 19.6448Z" fill="#876ECB"/>
                <path d="M31.1017 23.8775C28.1967 24.543 26.38 27.4375 27.044 30.3427C27.7079 33.2478 30.6011 35.0635 33.5061 34.398C36.411 33.7326 38.2277 30.838 37.5638 27.9328C36.8998 25.0277 34.0066 23.212 31.1017 23.8775Z" fill="#3E228C"/>
                <path d="M33.369 19.5309C31.668 19.9205 30.6042 21.6155 30.993 23.3166C31.3818 25.0177 33.0759 26.0809 34.7769 25.6912C36.4779 25.3016 37.5417 23.6066 37.1529 21.9055C36.7641 20.2044 35.07 19.1412 33.369 19.5309Z" fill="#ECE6FF"/>
                <path d="M42.5574 9.46473C38.322 5.22367 32.4674 2.59998 26.0001 2.59998C13.0766 2.59998 2.6001 13.0765 2.6001 26C2.6001 32.4673 5.22379 38.3219 9.46485 42.5573M42.5574 9.46473C46.7855 13.6984 49.4001 19.5439 49.4001 26C49.4001 38.9234 38.9236 49.4 26.0001 49.4C19.544 49.4 13.6985 46.7854 9.46485 42.5573M42.5574 9.46473L9.46485 42.5573" stroke="#EE1025" stroke-width="3.6"/>
            </svg>
        `
    };

    const CSS = {
        styles: `
            /* -- THUMBNAIL OVERLAY -- */
            .ddg-overlay {
                position: absolute;
                margin-top: 5px;
                margin-left: 5px;
                z-index: 1000;
                height: 32px;
                background: rgba(17, 17, 17, 0.8);
                box-shadow: 0px 1px 2px rgba(0, 0, 0, 0.25), 0px 4px 8px rgba(0, 0, 0, 0.1), inset 0px 0px 0px 1px rgba(255, 255, 255, 0.25);
                backdrop-filter: blur(4px);
                -webkit-backdrop-filter: blur(4px);
                border-radius: 4px;
                transition: 0.15s linear background;
            }

            .ddg-overlay a.ddg-play-privately {
                color: white;
                text-decoration: none;
                font-style: normal;
                font-weight: 600;
                font-size: 12px;
            }

            .ddg-overlay .ddg-dax,
            .ddg-overlay .ddg-play-icon {
                display: inline-block;

            }

            .ddg-overlay .ddg-dax {
                float: left;
                padding: 4px 4px;
                width: 24px;
                height: 24px;
                background: rgba(255, 255, 255, 0.1);
                border-right: 1px solid rgba(0, 0, 0, 0.1);
            }

            .ddg-overlay .ddg-play-text-container {
                width: 0px;
                overflow: hidden;
                float: left;
                transition: 0.15s linear width;
            }

            .ddg-overlay .ddg-play-text {
                line-height: 14px;

                margin-top: 10px;
                margin-left: 5px;
                width: 200px;
            }

            .ddg-overlay .ddg-play-icon {
                float: right;
                width: 24px;
                height: 20px;
                padding: 6px 4px;
            }

            .ddg-overlay:hover {
                background: #3969EF;
                box-shadow: 0px 1px 2px rgba(0, 0, 0, 0.25), 0px 4px 8px rgba(0, 0, 0, 0.1);
            }

            .ddg-overlay:hover .ddg-play-text-container {
                width: 90px;
            }

            .ddg-overlay[data-size="title"] {
                position: relative;
                margin: 0;
                float: right;
            }

            .ddg-overlay[data-size="title"] .ddg-play-text-container {
                width: 90px;
            }

            .ddg-overlay[data-size="fixed"] {
                position: absolute;
                top: 0;
                left: 0;
                display: none;
                z-index: 10;
            }

            #preview .ddg-overlay {
                transition: transform 160ms ease-out 200ms;
                /*TODO: scale needs to equal 1/--ytd-video-preview-initial-scale*/
                transform: scale(1.15) translate(5px, 4px);
            }

            #preview ytd-video-preview[active] .ddg-overlay {
                transform:scale(1) translate(0px, 0px);
            }

            /* -- VIDEO PLAYER OVERLAY */
            .ddg-video-player-overlay {
                position: absolute;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                background: rgba(0,0,0,0.6);
                color: white;
                text-align: center;
            }

            .ddg-vpo-content {
                position: relative;
                top: 50%;
                transform: translate(-50%, -50%);
                width: 496px;
                left: 50%;
            }

            .ddg-vpo-eyeball {
                margin-bottom: 18px;
            }

            .ddg-vpo-title {
                font-size: 22px;
                line-height: 26px;
                letter-spacing: -0.26px;
                color: rgba(255, 255, 255, 0.9);
                margin-bottom: 8px;
            }

            .ddg-vpo-text {
                font-size: 13px;
                line-height: 16px;
                text-align: center;
                letter-spacing: -0.08px;
                color: rgba(255, 255, 255, 0.8);
                margin-bottom: 30px;
            }

            .ddg-vpo-cancel {
                padding: 6px 16px;
                width: 101px;
                background: rgba(255, 255, 255, 0.25);
                box-shadow: 0px 0px 0px 0.5px rgba(0, 0, 0, 0.1), 0px 0px 1px rgba(0, 0, 0, 0.05), 0px 1px 1px rgba(0, 0, 0, 0.2), inset 0px 0.5px 0px rgba(255, 255, 255, 0.2), inset 0px 1px 0px rgba(255, 255, 255, 0.05);
                border-radius: 8px;
                display: inline-block;
                font-size: 16px;
                margin-right: 10px;
                cursor: pointer;
            }

            .ddg-vpo-open {
                display: inline-block;
                width: 98px;
                padding: 6px 16px;
                background: linear-gradient(180deg, #4266D8 0%, #224CD2 100%);
                border: 0.5px solid rgba(40, 145, 255, 0.05);
                box-shadow: 0px 0px 1px rgba(40, 145, 255, 0.05), 0px 1px 1px rgba(40, 145, 255, 0.1);
                border-radius: 8px;
                font-size: 16px;
                color: white;
                text-decoration: none;
            }
        `,

        /**
         * Initialize the CSS by adding it to the page in a <style> tag
         */
        init: () => {
            let style = document.createElement("style");
            style.innerText = CSS.styles;
            Util.appendElement(document.head, style);
        }
    }

    const Util = {
        /**
         * Add an event listener to an element that is only executed if it actually comes from a user action
         * @param {HTMLElement} element - to attach event to
         * @param {string} event
         * @param {function} callback
         */
        addTrustedEventListener: (element, event, callback) => {
            element.addEventListener(event, (e) => {
                if (e.isTrusted) {
                    callback(e);
                }
            });
        },

        /**
         * Same as $(elem).parents(selector)
         * @param {HTMLElement} elem
         * @param {string} selector
         */
        getClosest: function (elem, selector) {
            for ( ; elem && elem !== document; elem = elem.parentNode ) {
                if ( elem.matches( selector ) ) return elem;
            }
            return null;
        },

        /**
         * Appends an element. This may change if we go with Shadow DOM approach
         * @param {HTMLElement} to - which element to append to
         * @param {HTMLElement} element - to be appended
         */
        appendElement: (to, element) => {
            to.appendChild(element);
        },

        /**
         * NATIVE NOTE: Returns the URL we use for telling the MacOS app to open the private player
         * @param {string} relativePath - for now, it's expected to always be something like /watch?v=VIDEO_ID, there is no validation yet.
         */
        getPrivatePlayerURL: (relativePath) => {
            let videoId = relativePath.replace('/watch?v=', '');

            return 'privateplayer:' + videoId;
        }
    }

    const IconOverlay = {
        /**
         * Special class used for the overlay hover. For hovering, we use a
         * single element and move it around to the hovered video element.
         */
        HOVER_CLASS: 'ddg-overlay-hover',

        /**
         * Creates an Icon Overlay.
         * @param {string} size - currently kind-of unused
         * @param {string} href - what, if any, href to set the link to by default.
         * @param {string} extraClass - whether to add any extra classes, such as hover
         * @returns {HTMLElement}
         */
        create: (size, href, extraClass) => {
            let overlayElement = document.createElement('div');
            let videoURL = Util.getPrivatePlayerURL(href);

            overlayElement.setAttribute('class', 'ddg-overlay' + (extraClass ? ' ' + extraClass : ''));
            overlayElement.setAttribute('data-size', size);
            overlayElement.innerHTML = `
                <a class="ddg-play-privately" href="${videoURL}">
                    <div class="ddg-dax">
                        ${Icons.dax}
                    </div>
                    <div class="ddg-play-text-container">
                        <div class="ddg-play-text">
                            Watch Privately
                        </div>
                    </div>
                    <div class="ddg-play-icon">
                        ${Icons.play}
                    </div>
                </a>`;

            return overlayElement;
        },

        /**
         * Util to return the hover overlay
         * @returns {HTMLElement}
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

            if (overlay) {
                let offset = (el) => {
                    box = el.getBoundingClientRect();
                    docElem = document.documentElement;
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

                overlay.querySelector('a').setAttribute('href', Util.getPrivatePlayerURL(videoElement.getAttribute('href')));
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

                    let getThumbnailSize = (videoElement) => {
                        let imagesByArea = {};
                        let images = Array.from(videoElement.querySelectorAll('img')).forEach(image => {
                            imagesByArea[(image.offsetWidth * image.offsetHeight)] = image;
                        });

                        let largestImage = Math.max.apply(this, Object.keys(imagesByArea));

                        let getSizeType = (width, height) => {
                            if (width < 200 && height < 100) {
                                return 'small';
                            } else if (width < 300 && height < 175) {
                                return 'medium';
                            } else {
                                return 'large';
                            }
                        }

                        return getSizeType(imagesByArea[largestImage].offsetWidth, imagesByArea[largestImage].offsetHeight);
                    }

                    Util.appendElement(
                        videoElement,
                        IconOverlay.create(
                            getThumbnailSize(videoElement), videoElement.getAttribute('href')
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

    const VideoPlayerOverlay = {
        /**
         * Creates the video player overlay and returns the element
         * @returns {HTMLElement}
         */
        overlay: () => {
            let loc = window.location;
            let videoURL = Util.getPrivatePlayerURL(loc.pathname + loc.search);
            let overlayElement = document.createElement('div');
            overlayElement.setAttribute('class', 'ddg-video-player-overlay');
            overlayElement.innerHTML = `
                <div class="ddg-vpo-content">
                    <div class="ddg-eyeball">
                        ${Icons.eyeball}
                    </div>
                    <div class="ddg-vpo-title">
                        Watch without creepy ads and trackers
                    </div>
                    <div class="ddg-vpo-text">
                        YouTube does not let you watch videos anonymously... but the DuckDuckGo video player does! Watch this video with fewer trackers and no creepy ads.
                    </div>
                    <div class="ddg-vpo-buttons">
                        <div class="ddg-vpo-cancel">No Thanks</div>
                        <a class="ddg-vpo-open" href="${videoURL}">Try it now</a>
                    </div>
                </div>
            `;

            return overlayElement;
        },

        /**
         * Sets up buttons being clickable, right now just the cancel button
         */
        setupButtons: () => {
            Util.addTrustedEventListener(document.querySelector('.ddg-vpo-cancel'), 'click', () => {
                VideoPlayerOverlay.cancel(true);
            });
        },

        /**
         * Hide the video player overview
         * TODO: Refactor
         * @param {manuallyCancelled} - for now, set this true if hiding it from clicking the button
         */
        cancel: (manuallyCancelled) => {
            if (VideoPlayerOverlay.interval) {
                clearInterval(VideoPlayerOverlay.interval);
            }

            document.querySelector('.ddg-video-player-overlay').remove();
            let playerContainer = document.querySelector('#player');

            playerContainer.classList.remove('has-ddg-video-player-overlay');

            if (manuallyCancelled) {
                playerContainer.classList.add('ddg-has-cancelled');
                playerContainer.querySelector('video').play();
            }
        },

        /**
         * Set up the overlay
         */
        create: () => {
            let player = document.querySelector('#player:not(.has-ddg-video-player-overlay)'),
                playerVideo = document.querySelector('#player:not(.has-ddg-video-player-overlay) video');

            if (player && playerVideo) {
                VideoPlayerOverlay.callPauseUntilPaused();
                player.classList.add('has-ddg-video-player-overlay');
                Util.appendElement(player, VideoPlayerOverlay.overlay());
                VideoPlayerOverlay.setupButtons();
            }
        },

        /**
         * Determine when to add the overlay to a video player
         */
        watchForVideoBeingAdded: () => {
            if (window.location.pathname === '/watch') {
                if (!!document.querySelector('#player:not(.ddg-has-cancelled) video')) {
                    VideoPlayerOverlay.create();
                }
            // In case user navigates away from the player page, stop trying to pause videos.
            } else if (VideoPlayerOverlay.interval) {
                clearInterval(VideoPlayerOverlay.interval);
                VideoPlayerOverlay.cancel(false);
            }
        },

        interval: null,

        /**
         * Just brute-force calling video.pause() for as long as the user is seeing the overlay.
         */
        callPauseUntilPaused: () => {
            let playerVideo = document.querySelector('#player video');

            VideoPlayerOverlay.interval = setInterval(() => {
                playerVideo.pause();
            }, 1);
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
            });

            Site.onDOMChanged(() => {
                VideoThumbnail.bindEventsToAll();
                Preview.init();
                VideoPlayerOverlay.watchForVideoBeingAdded();
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

function disable() {
    console.log("I'm injected, but disabled =D")
}
