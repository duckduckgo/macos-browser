/** global mocha, chai */

describe("API scopes", () => {
  it("chrome is present in extension pages", () => {
    chai.expect(typeof chrome).to.equal("object");
  });

  const apis = ["tabs", "declarativeNetRequest", "runtime"];

  apis.forEach((api) => {
    it(`chrome.${api} is present on extension pages`, () => {
      chai.expect(typeof chrome[api]).to.equal("object");
    });
  });
});
