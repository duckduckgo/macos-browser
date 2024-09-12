
export async function loadPageAndWaitForLoad(url, active = false) {
    let tab;
  const tabReady = new Promise((resolve) => {
    const onUpdated = (details) => {
      if (details.tabId === tab.id && details.frameId === 0) {
        resolve();
        chrome.webNavigation.onDOMContentLoaded.removeListener(onUpdated);
      }
    };
    chrome.webNavigation.onDOMContentLoaded.addListener(onUpdated);
  });
  tab = await chrome.tabs.create({ url, active });
  await tabReady
  return tab
}