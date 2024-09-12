import { loadPageAndWaitForLoad } from "./utils.js";

const { expect } = chai;

describe("content_scripts manifest entry", () => {
  beforeEach(async () => {
    if (chrome.scripting?.unregisterContentScript) {
      await chrome.scripting.unregisterContentScripts();
    }
  });

  it("adds a script that runs on matching pages and communicate with the extension background", async () => {
    const messageReceived = new Promise((resolve) => {
      function messageListener(m) {
        resolve(m);
        chrome.runtime.onMessage.removeListener(messageListener);
      }
      chrome.runtime.onMessage.addListener(messageListener);
    });
    const tab = await loadPageAndWaitForLoad("https://example.com/");
    const response = await messageReceived;
    chrome.tabs.remove(tab.id);
    expect(response).to.be.an("object");
    expect(response.greeting).to.equal("hello");
  });
});
