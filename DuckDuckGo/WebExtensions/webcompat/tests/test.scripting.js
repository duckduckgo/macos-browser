import { loadPageAndWaitForLoad } from "./utils.js";

const { expect } = chai;

describe("chrome.scripting.executeScript", () => {
  it("Returns an array of InjectionResult (https://developer.chrome.com/docs/extensions/reference/scripting/#type-InjectionResult)", async () => {
    const url = "https://privacy-test-pages.glitch.me/";
    const tab = await loadPageAndWaitForLoad(url)
    const result = await chrome.scripting.executeScript({
      target: {
        tabId: tab.id,
      },
      world: 'ISOLATED',
      func: () => {
        return document.location.href;
      },
    });
    chrome.tabs.remove(tab.id);
    expect(result).to.be.an("array");
    expect(result).to.have.lengthOf(1);
    expect(result[0]).to.be.an('object');
    const injectionResultProperties = ["frameId", "result"];
    injectionResultProperties.forEach((prop) =>
      expect(result[0]).to.have.property(prop)
    );
    expect(result[0].frameId).to.equal(0);
    expect(result[0].result).to.equal(url);
  });
});

describe('chrome.scripting.registerContentScripts', () => {

  afterEach(async () => {
    await chrome.scripting.unregisterContentScripts()
  })

  it('Can register content-scripts at document_start', async () => {
    // register a script at document_start
    const scriptOptions = {
      id: '1-document-start-cs',
      allFrames: false,
      matches: ['https://example.com/'],
      persistAcrossSessions: false,
      runAt: 'document_start',
      world: 'ISOLATED',
      js: ['/content-script.js']
    }
    await chrome.scripting.registerContentScripts([scriptOptions])
    // check the registration
    const registered = await chrome.scripting.getRegisteredContentScripts()
    expect(registered).to.be.an("array");
    expect(registered).to.have.lengthOf(1);
    Object.keys(scriptOptions).forEach((k) => {
      expect(registered[0]).to.have.property(k)
    })
    expect(registered[0].runAt).to.equal(scriptOptions.runAt)
  })

  it('Does not affect content-scripts declared in the manifest', async () => {
    const scriptOptions = {
      id: '1-document-start-cs',
      allFrames: false,
      matches: ['https://example.com/'],
      persistAcrossSessions: false,
      runAt: 'document_start',
      world: 'ISOLATED',
      js: ['/content-script.js']
    }
    await chrome.scripting.registerContentScripts([scriptOptions])

    // check that content-script declared in the manifest is not affected
    const messageReceived = new Promise((resolve) => {
      function messageListener(m) {
        resolve(m);
        chrome.runtime.onMessage.removeListener(messageListener);
      }
      chrome.runtime.onMessage.addListener(messageListener);
    });
    const tab = await loadPageAndWaitForLoad("https://example.com/");
    const response = await messageReceived
    chrome.tabs.remove(tab.id)
    expect(response).to.be.an('object')
    expect(response.greeting).to.equal('hello')
  })
})
