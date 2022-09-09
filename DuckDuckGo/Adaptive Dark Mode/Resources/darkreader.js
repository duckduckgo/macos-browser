function enable() {
    var odmcss = `
    :root {
        filter: invert(90%) hue-rotate(180deg) brightness(100%) contrast(100%);
        background: #fff;
    }
    iframe, img, image, video, [style*="background-image"] {
        filter: invert() hue-rotate(180deg) brightness(105%) contrast(105%);
    }
    `;
      
    id="orion-browser-dark-theme";
    ee = document.getElementById(id);
    if (null != ee) ee.parentNode.removeChild(ee);
    else {
      style = document.createElement('style');
      style.type = "text/css";
      style.id = id;
      if (style.styleSheet) style.styleSheet.cssText = odmcss;
      else style.appendChild(document.createTextNode(odmcss));
      document.head.appendChild(style);
    }
}
