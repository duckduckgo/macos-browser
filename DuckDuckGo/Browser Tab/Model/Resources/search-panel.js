let createShadow = () => {
    let shadowAbove = document.createElement('div'),
        shadowBelow = document.createElement('div'),
        whiteLimit = document.createElement('div'),
        shadowStyle = `
            position:absolute;
            top:0px;
            bottom:0px;
            right:3px;
            width:20px;
            background: linear-gradient(to left, rgba(0,0,0,0.1), rgba(0,0,0,0));
            z-index:1000000000;
            border-right: 1px solid rgba(150,150,150,0.3);
        `;

        shadowAbove.setAttribute('style', shadowStyle);
        shadowBelow.setAttribute('style', shadowStyle + 'display:none;');
        shadowAbove.setAttribute('id', 'shadowAbove');
        shadowBelow.setAttribute('id', 'shadowBelow');

        whiteLimit.setAttribute('style', `
            position:fixed;
            top:0px;
            bottom:0px;
            right:0px;
            width:3px;
            background: white;
            z-index:1000000000;
        `);


    document.body.appendChild(shadowAbove);
    document.body.appendChild(shadowBelow);
    document.body.appendChild(whiteLimit);

}

let createFocus = (resultId) => {
    let resultPosition = document.querySelector(resultId).getBoundingClientRect();
    let top = resultPosition.top - 5 + window.scrollY;
    let height = (resultPosition.height + 10);
    let left = resultPosition.left - 5;
    let right = window.innerWidth - resultPosition.left - resultPosition.width - 5;
    let hasFocusEl = document.querySelector('#organic-focus')

    if (hasFocusEl) {
        hasFocusEl.style['top'] = top + 'px';
        hasFocusEl.style['height'] = height + 'px';
    } else {
        let focus = document.createElement('div');
        focus.setAttribute('style', `
            border: 1px solid rgba(150,150,150,0.3);
            position: absolute;
            top: ${top}px;
            left: ${left}px;
            right: ${right}px;
            height: ${height}px;
            pointer-events: none;
            border: 2px solid #3969EF;
            border-radius: 12px;
        `);
        focus.setAttribute('id', 'organic-focus');
        document.body.appendChild(focus);
    }

    /*let shadowAbove = document.querySelector('#shadowAbove');
    let shadowBelow = document.querySelector('#shadowBelow');

    shadowAbove.style['bottom'] = 'auto';
    shadowAbove.style['height'] = top + 'px';

    shadowBelow.style['display'] = 'block';
    shadowBelow.style['top'] = (top + height) + 'px';*/

}

let makeSlim = () => {
    document.querySelector('.results--sidebar').setAttribute('style', 'display:none;');
    document.querySelector('body').setAttribute('style', 'min-width:0px;');
    document.querySelector('html').setAttribute('style', 'min-width:0px;');
    document.querySelector('.site-wrapper').setAttribute('style', 'min-width:0px;');
    document.querySelector('#links_wrapper').setAttribute('style', 'min-width:0px;');
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
    //createShadow();

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
    createFocus('#'+findResultIdBasedOnURL(event.data.highlightSearchResult));
});

// Send swipeForward if swiping forward in the SERP Panel
document.addEventListener('wheel', (event) => {
    if (event.deltaX > 1 && event.deltaY === 0) {
        window.webkit.messageHandlers.swipeForward.postMessage(true);
    }
});


