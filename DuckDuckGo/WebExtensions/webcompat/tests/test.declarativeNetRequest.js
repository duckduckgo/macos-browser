/** global mocha, chai */
import { loadPageAndWaitForLoad } from "./utils.js";
const { expect } = chai;

const testUrl =
  "https://bad.third-party.site/privacy-protections/request-blocking/block-me/script.js";

async function dnrTest(addRules, test) {
  try {
    await chrome.declarativeNetRequest.updateDynamicRules({
      // removeRuleIds: addRules.map((r) => r.id),
      addRules,
    });
    await test();
  } finally {
    await chrome.declarativeNetRequest.updateDynamicRules({
      removeRuleIds: addRules.map((r) => r.id),
    });
  }
}

/**
 * Unwraps the result of a chrome.scripting.executeScript call to handle inconsistencies
 * between Chrome and Safari return types.
 * @param {*} result
 * @returns
 */
function getExecuteScriptResults(result) {
  return result.map((r) => (r.hasOwnProperty("frameId") ? r.result : r));
}

async function runTestPageTest(testPageUrl, waitFor) {
  const tab = await loadPageAndWaitForLoad(testPageUrl);
  while (true) {
    const result = await getTestPageResults(tab.id);
    if (result && waitFor(result)) {
      await chrome.tabs.remove(tab.id);
      return result;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

async function executeScriptWorkaround(tabId, func, world = "ISOLATED") {
  // As executeScript doesn't return results properly on some tested platforms, this is a workaround
  // that dumps the test result into the url hash. We can then read that back out with the
  // chrome.tabs API
  await chrome.scripting.executeScript({
    target: {
      tabId,
    },
    world,
    func,
  });
  const hash = new URL((await chrome.tabs.get(tabId)).url).hash;
  if (hash.length > 0) {
    return decodeURIComponent(hash.slice(1));
  }
  return null;
}

async function getTestPageResults(tabId) {
  const result = await executeScriptWorkaround(
    tabId,
    () => {
      document.location.hash = JSON.stringify(results?.results);
    },
    "MAIN"
  );
  if (result) {
    return JSON.parse(result);
  }
}

describe("chrome.declarativeNetRequest", () => {
  afterEach(async () => {
    const rules = await chrome.declarativeNetRequest.getDynamicRules();
    await chrome.declarativeNetRequest.updateDynamicRules({
      removeRuleIds: rules.map((r) => r.id),
    });
    const rulesets = await chrome.declarativeNetRequest.getEnabledRulesets();
    await chrome.declarativeNetRequest.updateEnabledRulesets({
      disableRulesetIds: rulesets,
    });
    const sessionRules = await chrome.declarativeNetRequest.getSessionRules();
    await chrome.declarativeNetRequest.updateSessionRules({
      removeRuleIds: sessionRules.map((r) => r.id),
    });
  });

  it("urlFilter with anchor blocks requests on matched domains", async () => {
    await dnrTest(
      [
        {
          id: 1,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            urlFilter: "||bad.third-party.site/*",
          },
        },
      ],
      async () => {
        const result = await runTestPageTest(
          "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
          (results) =>
            results.find(
              (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
            )
        );
        expect(result[0].status).to.not.equal("loaded");
      }
    );
  });

  it("enabling static ruleset with anchor block rule blocks requests", async () => {
    await chrome.declarativeNetRequest.updateEnabledRulesets({
      enableRulesetIds: ["test_rules_blocking"],
    });
    await dnrTest([], async () => {
      const result = await runTestPageTest(
        "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
        (results) =>
          results.find(
            (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
          )
      );
      expect(result[0].status).to.not.equal("loaded");
    });
  });

  it("requestDomains condition triggers on matched domains", async () => {
    await dnrTest(
      [
        {
          id: 1,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            requestDomains: ["bad.third-party.site"],
          },
        },
      ],
      async () => {
        const result = await runTestPageTest(
          "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
          (results) =>
            results.find(
              (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
            )
        );
        expect(
          result.find((r) => r.id === "xmlhttprequest").status
        ).to.not.equal("loaded");
      }
    );
  });

  it("allowAllRequests disables blocking rules when document URL matches", async () => {
    await dnrTest(
      [
        {
          id: 1,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            urlFilter: "||bad.third-party.site/*",
          },
        },
        {
          id: 2,
          priority: 2,
          action: {
            type: "allowAllRequests",
          },
          condition: {
            urlFilter: "||privacy-test-pages.glitch.me/",
            resourceTypes: ["main_frame"],
          },
        },
      ],
      async () => {
        const result = await runTestPageTest(
          "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
          (results) =>
            results.find(
              (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
            )
        );
        expect(result.find((r) => r.id === "xmlhttprequest").status).to.equal(
          "loaded"
        );
      }
    );
  });

  it("allowAllRequests disables static blocking rules when document URL matches", async () => {
    await chrome.declarativeNetRequest.updateEnabledRulesets({
      enableRulesetIds: ["test_rules_blocking"],
    });
    await dnrTest(
      [
        {
          id: 2,
          priority: 2,
          action: {
            type: "allowAllRequests",
          },
          condition: {
            urlFilter: "||privacy-test-pages.glitch.me/",
            resourceTypes: ["main_frame"],
          },
        },
      ],
      async () => {
        const result = await runTestPageTest(
          "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
          (results) =>
            results.find(
              (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
            )
        );
        expect(result.find((r) => r.id === "xmlhttprequest").status).to.equal(
          "loaded"
        );
      }
    );
  });

  it("allowAllRequests rules work when `removeRuleIds` is used in the same updateDynamicRules call", async () => {
    await chrome.declarativeNetRequest.updateEnabledRulesets({
      enableRulesetIds: ["test_rules_blocking"],
    });
    await chrome.declarativeNetRequest.updateDynamicRules({
      removeRuleIds: [1],
      addRules: [
        {
          id: 2,
          priority: 2,
          action: {
            type: "allowAllRequests",
          },
          condition: {
            urlFilter: "||privacy-test-pages.glitch.me/",
            resourceTypes: ["main_frame"],
          },
        },
      ],
    });
    const result = await runTestPageTest(
      "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    );
    expect(result.find((r) => r.id === "xmlhttprequest").status).to.equal(
      "loaded"
    );
  });

  it("redirect to extension image url with anchored urlFilter", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 3,
          priority: 2,
          action: {
            type: "redirect",
            redirect: {
              extensionPath: "/images/icon-48.png",
            },
          },
          condition: {
            urlFilter: "||facebook.com/tr",
          },
        },
      ],
    });
    const tab = await loadPageAndWaitForLoad(
      "https://privacy-test-pages.glitch.me/tracker-reporting/1major-via-img.html"
    );
    const imgWidthResult = await executeScriptWorkaround(tab.id, () => {
      document.location.hash = document.querySelector("img").width;
    });

    chrome.tabs.remove(tab.id);
    // if image is 48px then our replacement image was loaded
    expect(parseInt(imgWidthResult, 10)).to.equal(48);
  });

  it("redirect to extension image url with explicit urlFilter", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 3,
          priority: 2,
          action: {
            type: "redirect",
            redirect: {
              extensionPath: "/images/icon-48.png",
            },
          },
          condition: {
            urlFilter: "https://facebook.com/tr",
          },
        },
      ],
    });
    const tab = await loadPageAndWaitForLoad(
      "https://privacy-test-pages.glitch.me/tracker-reporting/1major-via-img.html"
    );
    const imgWidthResult = await executeScriptWorkaround(tab.id, () => {
      document.location.hash = document.querySelector("img").width;
    });
    chrome.tabs.remove(tab.id);
    // if image is 48px then our replacement image was loaded
    expect(parseInt(imgWidthResult, 10)).to.equal(48);
  });

  it("redirect to extension script url with anchored urlFilter", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 4,
          priority: 2,
          action: {
            type: "redirect",
            redirect: {
              extensionPath: "/surrogate.js",
            },
          },
          condition: {
            urlFilter: "||doubleclick.net/instream/ad_status.js",
          },
        },
      ],
    });
    const tab = await loadPageAndWaitForLoad(
      "https://privacy-test-pages.glitch.me/tracker-reporting/1major-with-surrogate.html"
    );
    const surrogateScriptTest = await executeScriptWorkaround(
      tab.id,
      () => {
        document.location.hash = window.surrogate_test;
      },
      "MAIN"
    );
    chrome.tabs.remove(tab.id);
    expect(surrogateScriptTest).to.equal("success");
  });

  it("queryTransform can remove search parameters", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 5,
          priority: 2,
          action: {
            type: "redirect",
            redirect: {
              transform: {
                queryTransform: {
                  removeParams: ["fbclid"],
                },
              },
            },
          },
          condition: {
            resourceTypes: ["main_frame"],
            urlFilter: "||privacy-test-pages.glitch.me/*",
          },
        },
      ],
    });
    const tab = await loadPageAndWaitForLoad(
      "https://privacy-test-pages.glitch.me/privacy-protections/query-parameters/query.html?fbclid=12345&fb_source=someting&u=14"
    );
    const url = new URL((await chrome.tabs.get(tab.id)).url);
    chrome.tabs.remove(tab.id);
    expect(url.search).to.not.contain("fbclid");
  });

  it("queryTransform can add search parameters in main_frame requests", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 6,
          priority: 2,
          action: {
            type: "redirect",
            redirect: {
              transform: {
                queryTransform: {
                  addOrReplaceParams: [{ key: "test", value: "1" }],
                },
              },
            },
          },
          condition: {
            resourceTypes: ["main_frame"],
            urlFilter: "||example.com",
          },
        },
      ],
    });
    const tab = await loadPageAndWaitForLoad("https://example.com/");
    const tabUrl = new URL((await chrome.tabs.get(tab.id)).url);
    chrome.tabs.remove(tab.id);
    expect(tabUrl.searchParams.has("test")).to.equal(true);
    expect(tabUrl.searchParams.get("test")).to.equal("1");
  });

  it("modifyHeaders can add a Sec-GPC header", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 5,
          priority: 6,
          action: {
            type: "modifyHeaders",
            requestHeaders: [
              { header: "Sec-GPC", operation: "set", value: "1" },
            ],
          },
          condition: {
            urlFilter: "||global-privacy-control.glitch.me/",
            resourceTypes: ["main_frame", "sub_frame"],
          },
        },
      ],
    });
    const tab = await loadPageAndWaitForLoad(
      "https://global-privacy-control.glitch.me/"
    );
    const gpcTest = await chrome.scripting.executeScript({
      target: {
        tabId: tab.id,
      },
      injectImmediately: false,
      func: () => {
        return document.querySelector(".gpc-value > code").innerText;
      },
    });
    chrome.tabs.remove(tab.id);
    expect(getExecuteScriptResults(gpcTest)[0]).to.equal('Sec-GPC: "1"');
  });

  it("tabIds rule condition is supported in session rules", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 1,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            urlFilter: "||bad.third-party.site/*",
          },
        },
      ],
    });
    const tab = await loadPageAndWaitForLoad(
      "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/"
    );
    await chrome.declarativeNetRequest.updateSessionRules({
      addRules: [
        {
          id: 10,
          priority: 2,
          action: {
            type: "allow",
          },
          condition: {
            urlFilter:
              "||bad.third-party.site/privacy-protections/request-blocking/block-me/script.js",
            tabIds: [tab.id],
          },
        },
      ],
    });
    await new Promise((resolve) => setTimeout(resolve, 250));
    await chrome.scripting.executeScript({
      target: {
        tabId: tab.id,
      },
      func: () => {
        document.getElementById("start").click();
      },
    });
    while (true) {
      const result = await getTestPageResults(tab.id);
      if (
        result &&
        result.find((r) => r.id === "script" && r.status !== "not loaded")
      ) {
        await chrome.tabs.remove(tab.id);
        expect(result.find((r) => r.id === "script").status).to.equal("loaded");
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  });

  it("'initiatorDomains' condition limits matches to requests initiated by matching domain", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 11,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            urlFilter: "||bad.third-party.site/*",
            initiatorDomains: ["privacy-test-pages.glitch.me"],
          },
        },
      ],
    });
    const testBlocked = runTestPageTest(
      "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    ).then((result) => {
      return expect(result[0].status).to.not.equal("loaded");
    });

    const testAllowed = runTestPageTest(
      "https://good.third-party.site/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    ).then((result) => {
      expect(result[0].status, "initiatorDomains value was ignored").to.equal(
        "loaded"
      );
    });
    await Promise.all([testBlocked, testAllowed]);
  });

  it("'initiatorDomains' condition list matches initators' subdomains", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 11,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            urlFilter: "||bad.third-party.site/*",
            initiatorDomains: ["glitch.me"],
          },
        },
      ],
    });
    const testBlocked = runTestPageTest(
      "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    ).then((result) => {
      return expect(result[0].status).to.not.equal("loaded");
    });

    const testAllowed = runTestPageTest(
      "https://good.third-party.site/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    ).then((result) => {
      expect(result[0].status, "initiatorDomains value was ignored").to.equal(
        "loaded"
      );
    });
    await Promise.all([testBlocked, testAllowed]);
  });

  it("'domains' condition limits matches to requests initiated by matching domain", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 11,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            urlFilter: "||bad.third-party.site/*",
            domains: ["privacy-test-pages.glitch.me"],
          },
        },
      ],
    });
    const testBlocked = runTestPageTest(
      "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    ).then((result) => {
      return expect(result[0].status).to.not.equal("loaded");
    });

    const testAllowed = runTestPageTest(
      "https://good.third-party.site/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    ).then((result) => {
      expect(result[0].status, "initiatorDomains value was ignored").to.equal(
        "loaded"
      );
    });
    await Promise.all([testBlocked, testAllowed]);
  });

  it("'domains' condition list matches initators' subdomains", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 11,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            urlFilter: "||bad.third-party.site/*",
            domains: ["glitch.me"],
          },
        },
      ],
    });
    const testBlocked = runTestPageTest(
      "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    ).then((result) => {
      return expect(
        result[0].status,
        "rule did not trigger with matching initiator"
      ).to.not.equal("loaded");
    });

    const testAllowed = runTestPageTest(
      "https://good.third-party.site/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "xmlhttprequest" && r.status !== "not loaded"
        )
    ).then((result) => {
      expect(result[0].status, "initiatorDomains value was ignored").to.equal(
        "loaded"
      );
    });
    await Promise.all([testBlocked, testAllowed]);
  });

  it("redirect supports regexSubstitution", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 12,
          priority: 1,
          action: {
            type: "redirect",
            redirect: { regexSubstitution: "https://\\1" },
          },
          condition: {
            resourceTypes: ["main_frame"],
            regexFilter:
              "^https?:\\/\\/\\S+ampproject\\.org\\/\\S\\/s\\/(\\S+)$",
          },
        },
      ],
    });
    const tab = await loadPageAndWaitForLoad(
      "https://www-wpxi-com.cdn.ampproject.org/v/s/www.wpxi.com/news/top-stories/pihl-bans-armstrong-student-section-hockey-games-after-vulgar-chants-directed-female-goalie/G2RP5FZA3ZDYRLFSWGDGQH2MY4/?amp_js_v=a6&_gsa=1&outputType=amp&usqp=mq331AQKKAFQArABIIACAw%3D%3D&referrer=https%3A%2F%2Fwww.google.com&_tf=From%20%251%24s&ampshare=https%3A%2F%2Fwww.wpxi.com%2Fnews%2Ftop-stories%2Fpihl-bans-armstrong-student-section-hockey-games-after-vulgar-chants-directed-female-goalie%2FG2RP5FZA3ZDYRLFSWGDGQH2MY4%2F"
    );
    const tabUrl = (await chrome.tabs.get(tab.id)).url;
    chrome.tabs.remove(tab.id);
    expect(tabUrl.indexOf("https://www.wpxi.com/")).to.equal(0);
  });

  it("dynamic allow rule prevents blocking from more generic rule", async () => {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 1,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            urlFilter: "||bad.third-party.site/*",
          },
        },
        {
          id: 2,
          priority: 2,
          action: {
            type: "allow",
          },
          condition: {
            urlFilter:
              "||bad.third-party.site/privacy-protections/request-blocking/block-me/script.js",
          },
        },
      ],
    });
    const result = await runTestPageTest(
      "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "script" && r.status !== "not loaded"
        )
    );
    expect(result.find((r) => r.id === "xmlhttprequest").status).to.equal(
      "failed"
    );
    expect(result.find((r) => r.id === "script").status).to.equal("loaded");
  });

  it("dynamic allow rule prevents blocking from static ruleset", async () => {
    await chrome.declarativeNetRequest.updateEnabledRulesets({
      enableRulesetIds: ["test_rules_blocking"],
    });
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [
        {
          id: 1,
          priority: 2,
          action: {
            type: "allow",
          },
          condition: {
            urlFilter:
              "||bad.third-party.site/privacy-protections/request-blocking/block-me/script.js",
          },
        },
      ],
    });
    const result = await runTestPageTest(
      "https://privacy-test-pages.glitch.me/privacy-protections/request-blocking/?run",
      (results) =>
        results.find(
          (r) => r.id === "script" && r.status !== "not loaded"
        )
    );
    expect(result.find((r) => r.id === "xmlhttprequest").status).to.equal(
      "failed"
    );
    expect(result.find((r) => r.id === "script").status).to.equal("loaded");
  });

  it('adds dynamic block rule without regexFilter and urlFiler in condition', async () => {
    await dnrTest(
      [
        {
          id: 1,
          priority: 1,
          action: {
            type: "block",
          },
          condition: {
            domainType: 'thirdParty',
            domains: ['example.com'],
          },
        },
      ],
      async () => {
        const rules = await chrome.declarativeNetRequest.getDynamicRules();
        expect(rules.length).to.equal(1);
      }
    );
  });

  it('adding unsupported DNR rules dynamically', async () => {
    try {
      await chrome.declarativeNetRequest.updateDynamicRules({
        addRules: [
          {
            "id": 990,
            "priority": 1,
            "action": {
                "type": "block"
            },
            "condition": {
                "urlFilter": "||bad.third-party.site/*"
            }
        },
        {
            "id": 999,
            "priority": 1,
            "action": {
                "type": "invalid"
            },
            "condition": {
                "urlFilter": "||"
            }
        },
        {
          "id": 1000,
          "priority": 1,
          "action": {
              "type": "block"
          },
          "condition": {
              "urlFilter": "||bad.third-party.site/hello"
          }
        }
      ]})
      expect.fail('updateDynamicRules should throw')
    } catch(e) {
      console.log(e)
      expect(await chrome.declarativeNetRequest.getDynamicRules()).to.have.length(0)
    }
  })

  it('adding invalid DNR rules dynamically', async () => {
    try {
      await chrome.declarativeNetRequest.updateDynamicRules({
        addRules: [
          {
            "id": 990,
            "priority": 1,
            "action": {
                "type": "block"
            },
            "condition": {
                "urlFilter": "||bad.third-party.site/*"
            }
        },
        {
            "id": 1000,
            "priority": 1,
            "action": {
                "type": "block"
            },
            "condition": {
                "urlFilter": "||"
            }
        },
        {
          "id": 1000,
          "priority": 1,
          "action": {
              "type": "block"
          },
          "condition": {
              "urlFilter": "||bad.third-party.site/hello"
          }
        }
      ]})
      expect.fail('updateDynamicRules should throw')
    } catch(e) {
      console.log(e)
      expect(await chrome.declarativeNetRequest.getDynamicRules()).to.have.length(0)
    }
  })
});
