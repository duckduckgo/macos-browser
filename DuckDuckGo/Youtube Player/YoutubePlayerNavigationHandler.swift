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
    static let privatePlayerHost = "www.youtube-nocookie.com"

    static var htmlTemplatePath: String {
        guard let file = Bundle.main.path(forResource: Self.htmlTemplateFileName, ofType: "html") else {
            assertionFailure("YouTube Private Player HTML template not found")
            return ""
        }
        return file
    }

    func makePrivatePlayerRequest(from originalRequest: URLRequest) -> URLRequest {
       
        let videoID: String
        if let query = originalRequest.url?.absoluteString.split(separator: ":").last,
           let components = URLComponents(string: "?\(query)"),
           let urlVideoID = components.queryItems?.first(where: { $0.value == nil })?.name {

            videoID = urlVideoID.removingCharacters(in: .youtubeVideoIDNotAllowed)
        } else {
            assertionFailure("Request should have ID")
            videoID = ""
        }

        return makePrivatePlayerRequest(for: videoID)
    }

    func makePrivatePlayerRequest(for videoID: String) -> URLRequest {
        var request = URLRequest(url: .youtubeNoCookie(videoID))
        request.addValue("http://localhost/", forHTTPHeaderField: "Referer")
        request.httpMethod = "GET"

        return request
    }

    func makeHTMLFromTemplate() -> String {
        guard let html = try? String(contentsOfFile: Self.htmlTemplatePath) else {
            assertionFailure("Should be able to load template")
            return ""
        }
        return html
    }

    private static let htmlTemplateFileName = "youtube_player_template"
}
