//
//  YoutubePlayer.swift
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

extension URL {
    var youtubeVideoID: String? {
        guard let components = URLComponents.init(url: self, resolvingAgainstBaseURL: false),
              components.host?.dropWWW() == "youtube.com",
              components.path == "/watch"
        else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "v" })?.value
    }

    var youtubeURL: URL? {
        let youtubeVideoID = self.lastPathComponent
        guard deletingLastPathComponent() == Self.localYoutubePlayerURL else {
            return nil
        }
        return Self.youtubeURL(for: youtubeVideoID)
    }

    static func localYoutubeURL(for videoID: String) -> URL {
        Self.localYoutubePlayerURL.appendingPathComponent(videoID)
    }

    static func youtubeURL(for videoID: String) -> URL {
        "https://www.youtube.com/watch?v=\(videoID)".url!
    }

    static let localYoutubePlayerURL = Bundle.main.bundleURL
}

struct YoutubePlayer {

    static let templateHTML: String = {
        guard let fileURL = Bundle.main.url(forResource: "youtube_player_template", withExtension: "html"),
            let template = try? String(contentsOf: fileURL)
        else {
            preconditionFailure("Failed to read Private Player template")
        }
        return template
    }()

    let htmlString: String
    private let videoID: String

    init(videoID: String) {
        self.videoID = videoID
        htmlString = Self.templateHTML.replacingOccurrences(of: "%%VIDEOID%%", with: videoID)
    }

    func load(in webView: WKWebView) {
        webView.loadHTMLString(htmlString, baseURL: .localYoutubeURL(for: videoID))
        guard let fileURL = Bundle.main.url(forResource: "private-player-inject", withExtension: "js"),
              let template = try? String(contentsOf: fileURL) else { return }

        webView.evaluateJavaScript(template)
    }
}
