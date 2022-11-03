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
            left: 0px;
            right: 0px;
            height: ${height}px;
            box-shadow: 0 0 10px rgba(0,0,0,0.3);
            pointer-events: none;
        `);
        focus.setAttribute('id', 'organic-focus');
        document.body.appendChild(focus);
    }

    let shadowAbove = document.querySelector('#shadowAbove');
    let shadowBelow = document.querySelector('#shadowBelow');

    shadowAbove.style['bottom'] = 'auto';
    shadowAbove.style['height'] = top + 'px';

    shadowBelow.style['display'] = 'block';
    shadowBelow.style['top'] = (top + height) + 'px';

}

let makeSlim = () => {
    document.querySelector('.results--sidebar').setAttribute('style', 'display:none;');
    document.querySelector('body').setAttribute('style', 'min-width:0px;');
    document.querySelector('html').setAttribute('style', 'min-width:0px;');
    document.querySelector('.site-wrapper').setAttribute('style', 'min-width:0px;');
    document.querySelector('#links_wrapper').setAttribute('style', 'min-width:0px;');
}

document.addEventListener('DOMContentLoaded', () => {
    createShadow();

    let deepLoaded = setInterval(() => {
        let resultId = '#r1-1';
        if (document.querySelector(resultId)) {
            console.log('finished!');
            createFocus(resultId);
            makeSlim();
            clearInterval(deepLoaded);
        } else {
            console.log('deep not loaded, wait');
        }
    });

});

// Listen for message from Native
window.addEventListener('message', (event) => {
    alert('got message');
    alert('message data:' + (event.data && JSON.stringify(event.data)));
});

// Send swipeForward if swiping forward in the SERP Panel
document.addEventListener('wheel', (event) => {
    if (event.deltaX > 1 && event.deltaY === 0) {
        window.webkit.messageHandlers.swipeForward.postMessage(true);
    }
});
