(() => {
  // DuckDuckGo/Youtube Player/Resources/youtube-inject.js
  window.enable = function enable(args) {
    console.log("enable", args);
    const Icons = {
      dax: `
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 23C18.0751 23 23 18.0751 23 12C23 5.92487 18.0751 1 12 1C5.92487 1 1 5.92487 1 12C1 18.0751 5.92487 23 12 23Z" fill="#DE5833"/>
            <path d="M14.1404 21.001C13.7872 20.3171 13.4179 19.3192 13.202 18.889C12.5118 17.4948 11.8167 15.5303 12.1324 14.2629C12.1896 14.0322 11.4814 5.73576 10.981 5.46712C10.4249 5.16882 9.21625 4.77493 8.58985 4.66945C8.15317 4.59859 8.05504 4.72219 7.87186 4.75021C8.04522 4.76834 8.86625 5.17541 9.02489 5.19848C8.86625 5.30726 8.39686 5.19519 8.09756 5.32868C7.94546 5.39955 7.83261 5.65994 7.83588 5.7819C8.69125 5.69455 10.0275 5.78025 10.819 6.13294C10.1894 6.20546 9.2326 6.28621 8.82209 6.50376C7.62817 7.13662 7.10154 8.61824 7.41555 10.3949C7.70667 12.0479 8.99561 18.4844 9.51734 21.001C10.4365 21.3174 11.1214 21.4768 12.1453 21.4768C13.1398 21.4768 13.5844 21.1081 14.1404 21.001Z" fill="#D5D7D8"/>
            <path fill-rule="evenodd" clip-rule="evenodd" d="M9.98431 21.1699C9.80923 19.9162 9.49398 18.6007 9.23216 17.3624C8.65596 14.6372 7.93939 11.248 7.72236 10.0352C7.40449 8.25212 7.72236 6.97898 8.9359 6.33992C9.35145 6.12139 9.94414 5.96245 10.5799 5.89126C9.77859 5.53531 8.82828 5.3979 7.9591 5.48564C7.95693 5.2445 8.23556 5.17084 8.49618 5.10193C8.63279 5.06582 8.76446 5.03101 8.84815 4.97407C8.77135 4.96299 8.64002 4.87503 8.50451 4.78428C8.35667 4.68527 8.20384 4.58292 8.11142 4.57342C9.21403 4.38468 10.3481 4.56183 11.3381 5.08168C11.8431 5.3532 12.2007 5.64292 12.4209 5.9459C12.9954 6.05682 13.5036 6.26377 13.8364 6.59654C14.8579 7.61637 15.7685 9.94412 15.3877 11.2835C15.2801 11.6543 15.035 11.9258 14.7271 12.1493C14.49 12.3221 14.3637 12.2786 14.2048 12.2239C13.9631 12.1407 13.6463 12.0316 12.7503 12.6179C12.6178 12.7039 12.576 13.1735 12.5437 13.5358C12.5288 13.7031 12.5159 13.8476 12.497 13.9208C12.1792 15.194 12.8795 17.1658 13.5798 18.568C13.7139 18.8353 13.8898 19.1724 14.0885 19.5531C14.1984 19.7636 14.5199 20.5797 14.6405 20.8125C12.4209 21.639 12.1751 21.7333 9.98431 21.1699Z" fill="white"/>
            <path d="M9.85711 10.5714C10.2516 10.5714 10.5714 10.2916 10.5714 9.94641C10.5714 9.60123 10.2516 9.32141 9.85711 9.32141C9.46262 9.32141 9.14282 9.60123 9.14282 9.94641C9.14282 10.2916 9.46262 10.5714 9.85711 10.5714Z" fill="#2D4F8E"/>
            <path d="M10.1723 9.93979C10.2681 9.93979 10.3458 9.86211 10.3458 9.76628C10.3458 9.67046 10.2681 9.59277 10.1723 9.59277C10.0765 9.59277 9.99878 9.67046 9.99878 9.76628C9.99878 9.86211 10.0765 9.93979 10.1723 9.93979Z" fill="white"/>
            <path d="M14.2664 10.3734C14.5539 10.3734 14.7869 10.1015 14.7869 9.7661C14.7869 9.43071 14.5539 9.15881 14.2664 9.15881C13.9789 9.15881 13.7458 9.43071 13.7458 9.7661C13.7458 10.1015 13.9789 10.3734 14.2664 10.3734Z" fill="#2D4F8E"/>
            <path d="M14.469 9.67966C14.5489 9.67966 14.6137 9.60198 14.6137 9.50615C14.6137 9.41032 14.5489 9.33264 14.469 9.33264C14.389 9.33264 14.3242 9.41032 14.3242 9.50615C14.3242 9.60198 14.389 9.67966 14.469 9.67966Z" fill="white"/>
            <path d="M9.9291 8.17747C9.9291 8.17747 9.46635 7.96895 9.01725 8.24947C8.56968 8.52849 8.58485 8.81201 8.58485 8.81201C8.58485 8.81201 8.34664 8.28697 8.98084 8.02896C9.61959 7.77394 9.9291 8.17747 9.9291 8.17747Z" fill="#2D4F8E"/>
            <path d="M14.6137 8.07779C14.6137 8.07779 14.2487 7.93456 13.9655 7.93685C13.3839 7.94144 13.2256 8.1179 13.2256 8.1179C13.2256 8.1179 13.3239 7.69738 14.0671 7.78217C14.3087 7.81196 14.5137 7.92196 14.6137 8.07779Z" fill="#2D4F8E"/>
            <path d="M12.0108 12.7346C12.0749 12.338 13.061 11.5901 13.7612 11.5432C14.4613 11.4979 14.6786 11.5092 15.2615 11.3635C15.846 11.2194 17.3526 10.831 17.7668 10.6319C18.1841 10.4327 19.9501 10.7306 18.7061 11.4509C18.1669 11.7633 16.715 12.3364 15.6772 12.6585C14.6411 12.979 14.0112 12.3509 13.6674 12.8803C13.3939 13.2995 13.6127 13.8742 14.8505 13.9939C16.5243 14.1542 18.1278 13.2137 18.3044 13.7139C18.481 14.2141 16.8681 14.8357 15.8835 14.8567C14.9005 14.8761 12.9188 14.1833 12.6234 13.9697C12.3249 13.756 11.9295 13.2542 12.0108 12.7346Z" fill="#FDD20A"/>
            <path d="M15.438 16.6617C15.1403 16.5928 13.9974 17.4122 13.5492 17.7446C13.531 17.6708 13.5161 17.6103 13.5012 17.5767C13.4285 17.3937 12.3286 17.4978 12.0375 17.7749C11.3429 17.4239 9.91387 16.754 9.8841 17.1654C9.8411 17.7127 9.8841 19.9425 10.1735 20.112C10.3852 20.2363 11.5479 19.5966 12.1599 19.2423C12.1781 19.249 12.1946 19.2541 12.2161 19.2608C12.5883 19.3464 13.2928 19.2608 13.5426 19.0929C13.5674 19.0761 13.5872 19.0475 13.6021 19.014C14.1661 19.2356 15.3156 19.6621 15.562 19.5697C15.8928 19.4388 15.8101 16.7473 15.438 16.6617Z" fill="#65BC46"/>
            <path d="M12.3032 19.1199C11.9194 19.0371 12.0491 18.6648 12.0491 17.7943L12.0474 17.7926C12.0474 17.791 12.0491 17.7877 12.0491 17.786C11.9484 17.8439 11.8836 17.9118 11.8836 17.9879H11.8853C11.8853 18.8584 11.7557 19.2324 12.1394 19.3151C12.5249 19.3979 13.2514 19.3151 13.509 19.1497C13.5516 19.1215 13.5806 19.0669 13.5994 18.9941C13.2992 19.1331 12.6562 19.1976 12.3032 19.1199Z" fill="#43A244"/>
            <path fill-rule="evenodd" clip-rule="evenodd" d="M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22ZM12 21C16.9706 21 21 16.9706 21 12C21 7.02944 16.9706 3 12 3C7.02944 3 3 7.02944 3 12C3 16.9706 7.02944 21 12 21Z" fill="white"/>
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

                background: rgba(0, 0, 0, 0.6);
                box-shadow: 0px 1px 2px rgba(0, 0, 0, 0.25), 0px 4px 8px rgba(0, 0, 0, 0.1), inset 0px 0px 0px 1px rgba(0, 0, 0, 0.18);
                backdrop-filter: blur(2px);
                -webkit-backdrop-filter: blur(2px);
                border-radius: 6px;

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
            }

            .ddg-overlay .ddg-play-text-container {
                width: 0px;
                overflow: hidden;
                float: left;
                opacity: 0;
                transition: all 0.15s linear;
            }

            .ddg-overlay .ddg-play-text {
                line-height: 14px;
                margin-top: 10px;
                width: 200px;
            }

            .ddg-overlay .ddg-play-icon {
                float: right;
                width: 24px;
                height: 20px;
                padding: 6px 4px;
            }

            .ddg-overlay:not([data-size="fixed small"]):hover .ddg-play-text-container {
                width: 91px;
                opacity: 1;
            }

            .ddg-overlay[data-size^="video-player"].hidden {
                display: none;
            }

            .ddg-overlay[data-size="video-player"] {
                top: 5px;
                left: 5px;
            }

            .ddg-overlay[data-size="video-player-with-title"] {
                top: 40px;
                left: 10px;
            }

            .ddg-overlay[data-size="video-player-with-paid-content"] {
                top: 65px;
                left: 11px;
            }

            .ddg-overlay[data-size="title"] {
                position: relative;
                margin: 0;
                float: right;
            }

            .ddg-overlay[data-size="title"] .ddg-play-text-container {
                width: 90px;
            }

            .ddg-overlay[data-size^="fixed"] {
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
      init: () => {
        let style = document.createElement("style");
        style.innerText = CSS.styles;
        Util.appendElement(document.head, style);
      }
    };
    const OverlaySettings = {
      enabled: {
        thumbnails: true,
        video: true
      },
      enableThumbnails: () => {
        IconOverlay.appendHoverOverlay();
        VideoThumbnail.bindEventsToAll();
        OverlaySettings.enabled.thumbnails = true;
      },
      disableThumbnails: () => {
        let overlays = document.querySelectorAll("." + IconOverlay.OVERLAY_CLASS);
        console.log("overlays", overlays);
        overlays.forEach((overlay) => {
          overlay.remove();
        });
        OverlaySettings.enabled.thumbnails = false;
      },
      disableVideo: () => {
        VideoPlayerOverlay.cancel();
        OverlaySettings.enabled.video = false;
      }
    };
    const Util = {
      addTrustedEventListener: (element, event, callback) => {
        element.addEventListener(event, (e) => {
          if (e.isTrusted) {
            callback(e);
          }
        });
      },
      getClosest: function(elem, selector) {
        for (; elem && elem !== document; elem = elem.parentNode) {
          if (elem.matches(selector))
            return elem;
        }
        return null;
      },
      appendElement: (to, element) => {
        to.appendChild(element);
      },
      getPrivatePlayerURL: (relativePath) => {
        let videoId = relativePath.replace("/watch?v=", "");
        return "privateplayer:" + videoId;
      }
    };
    const IconOverlay = {
      HOVER_CLASS: "ddg-overlay-hover",
      OVERLAY_CLASS: "ddg-overlay",
      create: (size, href, extraClass) => {
        let overlayElement = document.createElement("div");
        let videoURL = Util.getPrivatePlayerURL(href);
        overlayElement.setAttribute("class", "ddg-overlay" + (extraClass ? " " + extraClass : ""));
        overlayElement.setAttribute("data-size", size);
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
                </a>`;
        return overlayElement;
      },
      getHoverOverlay: () => {
        return document.querySelector("." + IconOverlay.HOVER_CLASS);
      },
      moveHoverOverlayToVideoElement: (videoElement) => {
        let overlay = IconOverlay.getHoverOverlay();
        if (overlay) {
          let offset = (el) => {
            box = el.getBoundingClientRect();
            docElem = document.documentElement;
            return {
              top: box.top + window.pageYOffset - docElem.clientTop,
              left: box.left + window.pageXOffset - docElem.clientLeft
            };
          };
          let videoElementOffset = offset(videoElement);
          overlay.setAttribute(
            "style",
            "top: " + videoElementOffset.top + "px;left: " + videoElementOffset.left + "px;display:block;"
          );
          overlay.setAttribute("data-size", "fixed " + IconOverlay.getThumbnailSize(videoElement));
          overlay.querySelector("a").setAttribute("href", Util.getPrivatePlayerURL(videoElement.getAttribute("href")));
        }
      },
      hideHoverOverlay: (event, force) => {
        let overlay = IconOverlay.getHoverOverlay();
        let toElement = event.toElement;
        if (overlay) {
          if (toElement === overlay || overlay.contains(toElement) || force) {
            return;
          }
          IconOverlay.hideOverlay(overlay);
        }
      },
      hideOverlay: (overlay) => {
        overlay.setAttribute("style", "display:none;");
      },
      appendHoverOverlay: () => {
        let el = IconOverlay.create("fixed", "", IconOverlay.HOVER_CLASS);
        Util.appendElement(document.body, el);
        Util.addTrustedEventListener(document.body, "mouseup", (event) => {
          IconOverlay.hideHoverOverlay(event);
        });
      },
      appendToVideo: (videoElement) => {
        let appendOverlayToThumbnail = (videoElement2) => {
          if (videoElement2) {
            Util.appendElement(
              videoElement2,
              IconOverlay.create(
                IconOverlay.getThumbnailSize(videoElement2),
                videoElement2.getAttribute("href")
              )
            );
            videoElement2.classList.add("has-dgg-overlay");
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
        let images = Array.from(videoElement.querySelectorAll("img")).forEach((image) => {
          imagesByArea[image.offsetWidth * image.offsetHeight] = image;
        });
        let largestImage = Math.max.apply(this, Object.keys(imagesByArea));
        let getSizeType = (width, height) => {
          if (width < 123 + 10) {
            return "small";
          } else if (width < 300 && height < 175) {
            return "medium";
          } else {
            return "large";
          }
        };
        return getSizeType(imagesByArea[largestImage].offsetWidth, imagesByArea[largestImage].offsetHeight);
      }
    };
    const VideoThumbnail = {
      findAll: () => {
        const linksToVideos = (item) => {
          let href = item.getAttribute("href");
          return href && (href.includes("/watch?v=") && !href.includes("&list=") || href.includes("/watch?v=") && href.includes("&list=") && href.includes("&index=")) && !href.includes("&pp=");
        };
        const linksWithImages = (item) => {
          return item.querySelector("img");
        };
        const linksWithoutSubLinks = (item) => {
          return !item.querySelector('a[href^="/watch?v="]');
        };
        const linksNotInVideoPreview = (item) => {
          let linksInVideoPreview = Array.from(document.querySelectorAll("#preview a"));
          return linksInVideoPreview.indexOf(item) === -1;
        };
        return Array.from(document.querySelectorAll("a:not(.has-ddg-overlay,.ddg-play-privately)")).filter(linksToVideos).filter(linksWithoutSubLinks).filter(linksNotInVideoPreview).filter(linksWithImages);
      },
      bindEvents: (video) => {
        if (video) {
          Util.addTrustedEventListener(video, "mouseover", () => {
            IconOverlay.moveHoverOverlayToVideoElement(video);
          });
          Util.addTrustedEventListener(video, "mouseout", IconOverlay.hideHoverOverlay);
          video.classList.add("has-ddg-overlay");
        }
      },
      bindEventsToAll: () => {
        VideoThumbnail.findAll().forEach(VideoThumbnail.bindEvents);
      }
    };
    const VideoPlayerIcon = {
      hasAddedVideoPlayerIcon: false,
      init: () => {
        let onVideoPage = document.location.pathname === "/watch";
        if (onVideoPage) {
          let videoPlayer = document.querySelector("#player:not(.has-ddg-overlay)");
          if (videoPlayer) {
            console.log("add vpi");
            Util.appendElement(
              videoPlayer,
              IconOverlay.create("video-player", window.location.pathname + window.location.search, "hidden")
            );
            console.log("addClass", videoPlayer);
            videoPlayer.classList.add("has-ddg-overlay");
            VideoPlayerIcon.hasAddedVideoPlayerIcon = true;
          }
          if (VideoPlayerIcon.hasAddedVideoPlayerIcon) {
            let hasTitle = !document.querySelector("#player .ytp-hide-info-bar");
            let hasPaidContent = document.querySelector(".ytp-paid-content-overlay-link").offsetWidth > 0;
            let isAds = document.querySelector("#player .ad-showing");
            let vpiClasses = document.querySelector('.ddg-overlay[data-size^="video-player"]').classList;
            if (isAds) {
              if (!vpiClasses.contains("hidden")) {
                console.log("isAds, hide");
                vpiClasses.add("hidden");
              }
            } else {
              if (vpiClasses.contains("hidden")) {
                console.log("is not ads, show after 50ms");
                setTimeout(() => {
                  if (!document.querySelector("#player .ad-showing") && vpiClasses.contains("hidden")) {
                    vpiClasses.remove("hidden");
                  }
                }, 50);
              }
            }
            if (hasPaidContent) {
              console.log("they just showed paid content, update position");
              if (document.querySelector('.ddg-overlay[data-size="video-player"]')) {
                document.querySelector('.ddg-overlay[data-size="video-player"]').setAttribute("data-size", "video-player-with-paid-content");
              }
            } else {
              console.log("they just hid paid content, update position");
              if (document.querySelector('.ddg-overlay[data-size="video-player-with-paid-content"]')) {
                document.querySelector('.ddg-overlay[data-size="video-player-with-paid-content"]').setAttribute("data-size", "video-player");
              }
            }
          }
        }
      }
    };
    const Preview = {
      previewContainer: false,
      getPreviewVideoLink: () => {
        let linkSelector = 'a[href^="/watch?v="]';
        let previewVideo = document.querySelector("#preview " + linkSelector + " video");
        return Util.getClosest(previewVideo, linkSelector);
      },
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
      update: () => {
        let updateOverlayVideoId = (element) => {
          let overlay = element && element.querySelector(".ddg-overlay");
          if (overlay) {
            overlay.querySelector("a.ddg-play-privately").setAttribute("href", Util.getPrivatePlayerURL(element.getAttribute("href")));
          }
        };
        let videoElement = Preview.getPreviewVideoLink();
        updateOverlayVideoId(videoElement);
      },
      fixLinkClick: () => {
        let previewLink = Preview.getPreviewVideoLink().querySelector("a.ddg-play-privately");
        Util.addTrustedEventListener(previewLink, "click", () => {
          window.location = previewLink.getAttribute("href");
        });
      },
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
      CLASS_OVERLAY: "ddg-video-player-overlay",
      overlay: () => {
        let loc = window.location;
        let videoURL = Util.getPrivatePlayerURL(loc.pathname + loc.search);
        let overlayElement = document.createElement("div");
        overlayElement.setAttribute("class", VideoPlayerOverlay.CLASS_OVERLAY);
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
      setupButtons: () => {
        Util.addTrustedEventListener(document.querySelector(".ddg-vpo-cancel"), "click", () => {
          VideoPlayerOverlay.cancel(true);
        });
      },
      cancel: (manuallyCancelled) => {
        if (VideoPlayerOverlay.interval) {
          clearInterval(VideoPlayerOverlay.interval);
        }
        document.querySelector("." + VideoPlayerOverlay.CLASS_OVERLAY).remove();
        let playerContainer = document.querySelector("#player");
        playerContainer.classList.remove("has-ddg-video-player-overlay");
        if (manuallyCancelled) {
          playerContainer.classList.add("ddg-has-cancelled");
          playerContainer.querySelector("video").play();
        }
      },
      create: () => {
        if (!OverlaySettings.enabled.video) {
          return;
        }
        let player = document.querySelector("#player:not(.has-ddg-video-player-overlay)"), playerVideo = document.querySelector("#player:not(.has-ddg-video-player-overlay) video");
        if (player && playerVideo) {
          VideoPlayerOverlay.callPauseUntilPaused();
          player.classList.add("has-ddg-video-player-overlay");
          Util.appendElement(player, VideoPlayerOverlay.overlay());
          VideoPlayerOverlay.setupButtons();
        }
      },
      watchForVideoBeingAdded: () => {
        if (window.location.pathname === "/watch") {
          if (!!document.querySelector("#player:not(.ddg-has-cancelled) video")) {
            VideoPlayerOverlay.create();
          }
        } else if (VideoPlayerOverlay.interval) {
          clearInterval(VideoPlayerOverlay.interval);
          VideoPlayerOverlay.cancel(false);
        }
      },
      interval: null,
      callPauseUntilPaused: () => {
        let playerVideo = document.querySelector("#player video");
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
        observer.observe(document.querySelector("body"), {
          subtree: true,
          childList: true,
          attributeFilter: ["src"]
        });
      },
      init: () => {
        Site.onDOMLoaded(() => {
          CSS.init();
          IconOverlay.appendHoverOverlay();
          VideoThumbnail.bindEventsToAll();
          VideoPlayerIcon.init();
        });
        Site.onDOMChanged(() => {
          if (OverlaySettings.enabled.thumbnails) {
            VideoThumbnail.bindEventsToAll();
            Preview.init();
            VideoPlayerIcon.init();
          }
          VideoPlayerOverlay.watchForVideoBeingAdded();
        });
      }
    };
    Site.init();
  };
  window.disable = function disable(args) {
    console.log("I'm injected, but disabled", args);
  };
})();
