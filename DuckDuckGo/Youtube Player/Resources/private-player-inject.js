alert("Private Player Content Script was loaded.");

window.addEventListener('message', (e) => {
   alert('Private Player Content Script received a message from the Private Player HTML-page');
});
