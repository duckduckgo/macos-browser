//
//  PrivateYoutubePlayerChromeViewController.swift
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

import Cocoa
import WebKit

final class PrivateYoutubePlayerChromeViewController: NSViewController {

    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        webView.uiDelegate = self
        webView.navigationDelegate = self
    }
    
    private let HTML = #"""
<!DOCTYPE html>
<html>
    <head>
        <title>Private Player</title>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            .container{position: relative;width: 100%;height: 0;padding-bottom: 56.25%; background-color: black}
            iframe{position: absolute;top:0;left:0;width:100%;height:100%;}
            body {background-color: #222;}
            p {color: white; font-size: large;}
            li {color: white; font-size: large;}
        </style>
    </head>
    <body>
        <div class='container'>
            <div id='player'>
                <iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/$(VIDEOID)"  title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
                
            </div>
        </div>
    </body>
</html>
"""#
    
    func loadVideoID(videoID: String) {
        let videoHTML = HTML.replacingOccurrences(of: "$(VIDEOID)", with: videoID)
        
        webView.loadHTMLString(videoHTML, baseURL: nil)
    }
    
}

extension PrivateYoutubePlayerChromeViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("Decide policy for request [\(navigationAction.request)] HEADERS [\(String(describing: navigationAction.request.allHTTPHeaderFields))]")

        if navigationAction.request.url?.absoluteString.contains("nocookie") == true,
           navigationAction.request.value(forHTTPHeaderField: "Referer") == nil {
            decisionHandler(.cancel)
            var newRequest = navigationAction.request
            newRequest.addValue("http://localhost/", forHTTPHeaderField: "Referer")
            webView.load(newRequest)
        } else {
            decisionHandler(.allow)
        }
    }
}

extension PrivateYoutubePlayerChromeViewController: WKUIDelegate {
    
}
