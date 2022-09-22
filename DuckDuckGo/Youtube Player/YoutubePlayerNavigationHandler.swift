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
    static let privatePlayerFragment = "privateplayer"

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

            videoID = urlVideoID
        } else {
            assertionFailure("Request should have ID")
            videoID = ""
        }

        return makePrivatePlayerRequest(for: videoID)
    }

    func makePrivatePlayerRequest(for videoID: String) -> URLRequest {
        #warning("Check if all these queries are required or not")
        let url = URL(string: "https://\(Self.privatePlayerHost)/embed/\(videoID)?wmode=transparent&iv_load_policy=3&autoplay=1&html5=1&showinfo=0&rel=0&modestbranding=1&playsinline=0#\(Self.privatePlayerFragment)")!

        var request = URLRequest(url: url)
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

extension URL {
    static func privatePlayer(_ videoID: String) -> URL {
        "\(PrivatePlayerSchemeHandler.scheme):\(videoID)".url!
    }

    static func youtubeNoCookie(_ videoID: String) -> URL {
        "https://\(YoutubePlayerNavigationHandler.privatePlayerHost)/embed/\(videoID)?wmode=transparent&iv_load_policy=3&autoplay=1&html5=1&showinfo=0&rel=0&modestbranding=1&playsinline=0#\(YoutubePlayerNavigationHandler.privatePlayerFragment)".url!
    }

    static func youtube(_ videoID: String) -> URL {
        "https://www.youtube.com/watch?v=\(videoID)".url!
    }

    var isPrivatePlayerScheme: Bool {
        scheme == PrivatePlayerSchemeHandler.scheme
    }

    var isPrivatePlayer: Bool {
        host == YoutubePlayerNavigationHandler.privatePlayerHost && fragment == YoutubePlayerNavigationHandler.privatePlayerFragment
    }

    /// Returns true only if the video represents a playlist itself, i.e. doesn't have `index` query parameter
    var isYoutubePlaylist: Bool {
        guard isYoutubeWatch, let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return false
        }

        let isPlaylistURL = components.queryItems?.contains(where: { $0.name == "list" }) == true &&
        components.queryItems?.contains(where: { $0.name == "index" }) == false

        return isPlaylistURL
    }

    var isYoutubeVideo: Bool {
        isYoutubeWatch && !isYoutubePlaylist
    }

    var isYoutubeVideoRecommendation: Bool {
        guard isYoutubeVideo,
              let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let featureQueryParameter = components.queryItems?.first(where: { $0.name == "feature" })?.value
        else {
            return false
        }

        let recommendationFeatures = [ "emb_rel_end", "emb_rel_pause" ]

        return recommendationFeatures.contains(featureQueryParameter)
    }

    private var isYoutubeWatch: Bool {
        host?.droppingWwwPrefix() == "youtube.com" && path == "/watch"
    }

    var youtubeVideoID: String? {
        if isPrivatePlayerScheme {
            return absoluteString.split(separator: ":").last.flatMap(String.init)
        }

        if isPrivatePlayer {
            return lastPathComponent
        }

        guard isYoutubeVideo, let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "v" })?.value
    }
}
