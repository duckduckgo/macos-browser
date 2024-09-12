
chrome.action.onClicked.addListener(() => {
    chrome.tabs.create({ url: chrome.runtime.getURL('/test.html')})
})

chrome.runtime.onInstalled.addListener(() => {
    chrome.tabs.create({ url: chrome.runtime.getURL('/test.html')})
})
