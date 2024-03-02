//
//  ClickToLoadUserScript.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import WebKit
import Common
import UserScript

protocol ClickToLoadUserScriptDelegate: AnyObject {

    func clickToLoadUserScriptAllowFB() -> Bool
}

final class ClickToLoadUserScript: NSObject, WKNavigationDelegate, Subfeature {

    weak var broker: UserScriptMessageBroker?
    weak var webView: WKWebView?

    weak var delegate: ClickToLoadUserScriptDelegate?

#if DEBUG
    var devMode: Bool = true
#else
    var devMode: Bool = false
#endif

    // this isn't an issue to be set to 'all' because the page
    public let messageOriginPolicy: MessageOriginPolicy = .all
    public let featureName: String = "clickToLoad"

    // MARK: - Subfeature

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - MessageNames

    enum MessageNames: String, CaseIterable {
        case getClickToLoadState
        case unblockClickToLoadContent
        case updateFacebookCTLBreakageFlags
        case addDebugFlag
    }

    public func handler(forMethodNamed methodName: String) -> Handler? {
        switch MessageNames(rawValue: methodName) {
        case .getClickToLoadState:
            return handleGetClickToLoadState
        case .unblockClickToLoadContent:
            return handleUnblockClickToLoadContent
        case .updateFacebookCTLBreakageFlags:
            return handleDebugFlagsMock
        case .addDebugFlag:
            return handleDebugFlagsMock
        default:
            assertionFailure("ClickToLoadUserScript: Failed to parse User Script message: \(methodName)")
            return nil
        }
    }

    private func handleGetClickToLoadState(params: Any, message: UserScriptMessage) -> Encodable? {
        webView = message.messageWebView
        print("handleGetClickToLoadState for url \(String(describing: message)) for webView \(webView?.url)")
        return [
            "devMode": devMode,
            "youtubePreviewsEnabled": false
        ]
    }

    private func handleUnblockClickToLoadContent(params: Any, message: UserScriptMessage) -> Encodable? {
        struct UnblockMessage: Decodable {
            let action: String
            let isLogin: Bool
            let isSurrogateLogin: Bool
            let entity: String
        }

        guard let delegate = delegate else { return false }

        // only worry about CTL FB for now
        return delegate.clickToLoadUserScriptAllowFB()
    }

    private func handleDebugFlagsMock(params: Any, message: UserScriptMessage) -> Encodable? {
        // breakage flags not supported on Mac yet
        return nil
    }

    // swiftlint:disable function_body_length
    public func displayClickToLoadPlaceholders() {
        print("displayClickToLoadPlaceholders for url \(String(describing: webView?.url)) for broker \(broker)")
        if let webView = webView {
            let fbSurrogate =  """
                (() => {
                'use strict';
                console.warn('fb-sdk document.currentScript.src', document.currentScript, document.currentScript?.src);
                console.warn('in fbSurrogate, location is', window.location.href);
                debugger;
                return;
                window.fbTest = "inline surrogate";
                const facebookEntity = 'Facebook, Inc.';
                const originalFBURL = 'https://connect.facebook.net/en_US/sdk.js?XFBML=false' //FIXME: document.currentScript.src;
                let siteInit = function () {};
                let fbIsEnabled = false;
                let initData = {};
                let runInit = false;
                const parseCalls = [];
                const popupName = Math.random().toString(36).replace(/[^a-z]+/g, '').substr(0, 12);
                const fbLogin = {
                    callback: function () {},
                    params: undefined,
                    shouldRun: false
                };
                function messageAddon (detailObject) {
                    detailObject.entity = facebookEntity;
                    const event = new CustomEvent('ddg-ctp', {
                        detail: detailObject,
                        bubbles: false,
                        cancelable: false,
                        composed: false
                    });
                    dispatchEvent(event);
                }
                /**
                 * When setting up the Facebook SDK, the site may define a function called window.fbAsyncInit.
                 * Once the SDK loads, it searches for and calls window.fbAsyncInit. However, some sites may
                 * not use this, and just call FB.init directly at some point (after ensuring that the script has loaded).
                 *
                 * Our surrogate (defined below in window.FB) captures calls made to init by page scripts. If at a
                 * later point we load the real sdk here, we then re-call init with whatever arguments the page passed in
                 * originally. The runInit param should be true when a page has called init directly.
                 * Because we put it in asyncInit, the flow will be something like:
                 *
                 * FB SDK loads -> SDK calls window.fbAsyncInit -> Our function calls window.FB.init (maybe) ->
                 * our function calls original fbAsyncInit (if it existed)
                 */
                function enableFacebookSDK () {
                    if (!fbIsEnabled) {
                        window.FB = undefined;
                        window.fbAsyncInit = function () {
                            if (runInit && initData) {
                                window.FB.init(initData);
                            }
                            siteInit();
                            if (fbLogin.shouldRun) {
                                window.FB.login(fbLogin.callback, fbLogin.params);
                            }
                        };
                        const fbScript = document.createElement('script');
                        fbScript.setAttribute('crossorigin', 'anonymous');
                        fbScript.setAttribute('async', '');
                        fbScript.setAttribute('defer', '');
                        fbScript.src = originalFBURL;
                        fbScript.onload = function () {
                            for (const node of parseCalls) {
                                window.FB.XFBML.parse.apply(window.FB.XFBML, node);
                            }
                        };
                        document.head.appendChild(fbScript);
                        fbIsEnabled = true;
                    } else {
                        if (initData) {
                            window.FB.init(initData);
                        }
                    }
                }
                function runFacebookLogin () {
                    fbLogin.shouldRun = true;
                    replaceWindowOpen();
                    loginPopup();
                    enableFacebookSDK();
                }
                function replaceWindowOpen () {
                    const oldOpen = window.open;
                    window.open = function (url, name, windowParams) {
                        const u = new URL(url);
                        if (u.origin === 'https://www.facebook.com') {
                            name = popupName;
                        }
                        return oldOpen.call(window, url, name, windowParams);
                    };
                }
                function loginPopup () {
                    const width = Math.min(window.screen.width, 450);
                    const height = Math.min(window.screen.height, 450);
                    const popupParams = `width=${width},height=${height},scrollbars=1,location=1`;
                    window.open('about:blank', popupName, popupParams);
                }
                window.addEventListener('ddg-ctp-load-sdk', event => {
                    if (event.detail.entity === facebookEntity) {
                        enableFacebookSDK();
                    }
                });
                window.addEventListener('ddg-ctp-run-login', event => {
                    if (event.detail.entity === facebookEntity) {
                        runFacebookLogin();
                    }
                });
                window.addEventListener('ddg-ctp-cancel-modal', event => {
                    if (event.detail.entity === facebookEntity) {
                        fbLogin.callback({ });
                    }
                });
                // Instead of using fbAsyncInit, some websites create a list of FB API calls
                // that should be made after init.
                const bufferCalls = window.FB && window.FB.__buffer && window.FB.__buffer.calls;
                function init () {
                    if (window.fbAsyncInit) {
                        siteInit = window.fbAsyncInit;
                        window.fbAsyncInit();
                    }
                    if (bufferCalls) {
                        for (const [method, params] of bufferCalls) {
                            if (Object.prototype.hasOwnProperty.call(window.FB, method)) {
                                window.FB[method].apply(window.FB, params);
                            }
                        }
                    }
                }
                if (!window.FB || window.FB.__buffer) {
                    window.FB = {
                        api: function (url, cb) { cb(); },
                        init: function (obj) {
                            if (obj) {
                                initData = obj;
                                runInit = true;
                                messageAddon({
                                    appID: obj.appId
                                });
                            }
                        },
                        ui: function (obj, cb) {
                            if (obj.method && obj.method === 'share') {
                                const shareLink = 'https://www.facebook.com/sharer/sharer.php?u=' + obj.href;
                                window.open(shareLink, 'share-facebook', 'width=550,height=235');
                            }
                            // eslint-disable-next-line node/no-callback-literal
                            cb({});
                        },
                        getAccessToken: function () {},
                        getAuthResponse: function () {
                            return { status: '' };
                        },
                        // eslint-disable-next-line node/no-callback-literal
                        getLoginStatus: function (callback) { callback({ status: 'unknown' }); },
                        getUserID: function () {},
                        login: function (cb, params) {
                            fbLogin.callback = cb;
                            fbLogin.params = params;
                            messageAddon({
                                action: 'login'
                            });
                        },
                        logout: function () {},
                        AppEvents: {
                            EventNames: {},
                            logEvent: function (a, b, c) {},
                            logPageView: function () {}
                        },
                        Event: {
                            subscribe: function (event, callback) {
                                if (event === 'xfbml.render') {
                                    callback();
                                }
                            },
                            unsubscribe: function () {}
                        },
                        XFBML: {
                            parse: function (n) {
                                parseCalls.push(n);
                            }
                        }
                    };
                    if (document.readyState === 'complete') {
                        init();
                    } else {
                        // sdk script loaded before page content, so wait for load.
                        window.addEventListener('load', (event) => {
                            init();
                        });
                    }
                }
                window.dispatchEvent(new CustomEvent('ddg-ctp-surrogate-load'));
                console.warn('dispatched event');
                })();
            """
            broker?.push(method: "displayClickToLoadPlaceholders", params: ["ruleAction": ["block"]], for: self, into: webView)
            webView.evaluateJavaScript(fbSurrogate, in: nil, in: WKContentWorld.page)
        }
    }
}
