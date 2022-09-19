//
//  PrivatePlayerSchemeHandler.swift
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
import WebKit

final class PrivatePlayerSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "privateplayer"
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        print("Scheme Start")
        guard let file = Bundle.main.url(forResource: "youtube_player_template", withExtension: "html"),
        let requestURL = urlSchemeTask.request.url else { return }
        guard let data = try? String(contentsOf: file).data(using: .utf8) else { return }
        
        let response = URLResponse(url: requestURL,
                                   mimeType: "text/html",
                                   expectedContentLength: data.count,
                                   textEncodingName: nil)
        
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        print("Scheme Stop")
    }
}
