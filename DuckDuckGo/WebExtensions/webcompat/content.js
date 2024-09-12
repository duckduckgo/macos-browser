console.log('CS start')

chrome.runtime.sendMessage({ greeting: "hello" }).then((response) => {
    console.log("Received response: ", response);
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log("Received request: ", request);
});
