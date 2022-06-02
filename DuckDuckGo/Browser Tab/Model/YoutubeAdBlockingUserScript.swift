//
//  YoutubeAdBlockingUserScript.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import Foundation
import BrowserServicesKit

// swiftlint:disable line_length
final class YoutubeAdBlockingUserScript: NSObject, StaticUserScript {
    var messageNames: [String] = []

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("test")
    }

    static let source =
        """
            // ==UserScript==
            // @name               Hide youtube google ad
            // @name:zh-CN         隐藏youtube google广告
            // @namespace          vince.youtube
            // @version            2.4.2
            // @description        hide youtube google ad,auto click "skip ad"
            // @description:zh-CN  隐藏youtube显示的google广告,自动点击"skip ad"
            // @author             vince ding
            // @match              *://www.youtube.com/*
            // ==/UserScript==

            (function() {
                'use strict';
                var closeAd=function (){
                    var css = '.video-ads,.video-ads .ad-container .adDisplay,#player-ads,.ytp-ad-module,.ytp-ad-image-overlay{ display: none!important; }',
                        head = document.head || document.getElementsByTagName('head')[0],
                        style = document.createElement('style');

                    style.type = 'text/css';
                    if (style.styleSheet){
                        style.styleSheet.cssText = css;
                    } else {
                        style.appendChild(document.createTextNode(css));
                    }

                    head.appendChild(style);
                };
                var skipInt;
                var log=function(msg){
                   // unsafeWindow.console.log (msg);
                };
                var skipAd=function(){
                    //ytp-ad-preview-text
                    //ytp-ad-skip-button
                    var skipbtn=document.querySelector(".ytp-ad-skip-button.ytp-button")||document.querySelector(".videoAdUiSkipButton ");
                    //var skipbtn=document.querySelector(".ytp-ad-skip-button ")||document.querySelector(".videoAdUiSkipButton ");
                    if(skipbtn){
                       skipbtn=document.querySelector(".ytp-ad-skip-button.ytp-button")||document.querySelector(".videoAdUiSkipButton ");
                       log("skip");
                       skipbtn.click();
                       if(skipInt) {clearTimeout(skipInt);}
                       skipInt=setTimeout(skipAd,500);
                     }else{
                          log("checking...");
                          if(skipInt) {clearTimeout(skipInt);}
                          skipInt=setTimeout(skipAd,500);
                     }
                };

                closeAd();
                skipAd();

            })();
    """

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentEnd }
    static var forMainFrameOnly: Bool { true }
    static var requiresRunInPageContentWorld: Bool { true }

    static var script = YoutubeAdBlockingUserScript.makeWKUserScript()
}
