let createFocus = (resultId) => {
    document.querySelectorAll('.nrn-react-div article').forEach(function(element) {
        element.setAttribute('style','');
    });

    var focus = document.querySelector(resultId);
    focus.setAttribute('style', 'border:2px solid #3969EF !important;padding:calc(var(--px-in-rem)*5.2) 8px !important;');
}

let makeSlim = () => {
    var styles = `
        .results--sidebar, .acp__search-fill {
            display: none !important;
        }
        html, body, .site-wrapper, #links_wrapper {
            min-width: 0px !important;
        }

        #links .nrn-react-div article,
        #ads .nrn-react-div article {
            border: none !important;
            box-shadow: none !important;
        }

        .nav-menu--slideout:not(.is-open) {
            opacity: 0 !important;
        }

        .set-header--floating #header_wrapper {
            margin-top: 42px !important;
        }
    `

    var styleSheet = document.createElement("style")
    styleSheet.type = "text/css"
    styleSheet.innerText = styles
    document.head.appendChild(styleSheet);
    document.querySelector('html').classList.remove('is-mobile');
}

let hijackOrganicClicks = () => {
    document.querySelectorAll('.nrn-react-div').forEach((item) => {
        item.addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();

            let clickedDiv = event.target.closest('.nrn-react-div');
            let url = clickedDiv?.querySelector('a[data-testid="result-title-a"]')?.getAttribute('href');

            console.log('url', url);
            window.webkit.messageHandlers.selectedSearchResult.postMessage(url);

            let clickedResultId = clickedDiv.querySelector('article').getAttribute('id');

            createFocus('#' + clickedResultId);

        }, true);
    });
}

var findResultIdBasedOnURL = (url) => {
    let link = document.querySelector('a[data-testid="result-title-a"][href="'+url+'"]');
    let div = link.closest('article[data-testid="result"]');

    if (!link || !div) {
        document.body.innerHTML = 'Error, url: ' + url;
    }

    return div.getAttribute('id');
}

document.addEventListener('DOMContentLoaded', () => {
    let deepLoaded = setInterval(() => {
        let resultId = '#r1-1';
        if (document.querySelector(resultId)) {
            console.log('finished!');
            //createFocus(resultId);
            makeSlim();
            hijackOrganicClicks();
            clearInterval(deepLoaded);
        } else {
            console.log('deep not loaded, wait');
        }
    });

});

// Listen for message from Native
window.addEventListener('message', (event) => {
    let focusElementId = '#'+findResultIdBasedOnURL(event.data.highlightSearchResult);
    createFocus(focusElementId);

    setTimeout(function() {
        document.querySelector(focusElementId).scrollIntoView({ block: 'center' });
    }, 1000);
});

// Send swipeForward if swiping forward in the SERP Panel
document.addEventListener('wheel', (event) => {
    if (event.deltaX > 1 && event.deltaY === 0) {
        window.webkit.messageHandlers.swipeForward.postMessage(true);
    }
});
