//
//  YoutubePlayerNavigationHandler.swift
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

struct YoutubePlayerNavigationHandler {
    
    func makePrivatePlayerRequest(from originalRequest: URLRequest) -> URLRequest {
       
        let videoID: String
        if let requestID = originalRequest.url?.absoluteString.split(separator: ":").last {
            videoID = String(requestID)
        } else {
            assertionFailure("Request should have ID")
            videoID = ""
        }
        
        #warning("Check if all these queries are required or not")
        let url = URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?wmode=transparent&iv_load_policy=3&autoplay=1&html5=1&showinfo=0&rel=0&modestbranding=1&playsinline=0")!
        
        var request = URLRequest(url: url)
        request.addValue("http://localhost/", forHTTPHeaderField: "Referer")
        request.httpMethod = "GET"
        
        return request
    }
    
    func makeHTMLFromTemplate(_ template: String = "youtube_player_template") -> String {
        guard let file = Bundle.main.url(forResource: template, withExtension: "html"),
              let html = try? String(contentsOf: file) else {
            assertionFailure("Should be able to load template")
            return ""
            
        }
        return html
    }
}

extension URL {
    var isPrivatePlayerScheme: Bool {
        scheme == PrivatePlayerSchemeHandler.scheme
    }
}
