//
//  PrivatePlayerURLExtension.swift
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

extension URL {
    static func privatePlayer(_ videoID: String, timestamp: String? = nil) -> URL {
        let url = "\(PrivatePlayer.privatePlayerScheme)://\(videoID)".url!
        return url.addingTimestamp(timestamp)
    }

    static func youtubeNoCookie(_ videoID: String, timestamp: String? = nil) -> URL {
        let url = "https://\(PrivatePlayer.privatePlayerHost)/embed/\(videoID)".url!
        return url.addingTimestamp(timestamp)
    }

    static func youtube(_ videoID: String, timestamp: String? = nil) -> URL {
        let url = "https://www.youtube.com/watch?v=\(videoID)".url!
        return url.addingTimestamp(timestamp)
    }

    var isPrivatePlayerScheme: Bool {
        scheme == PrivatePlayer.privatePlayerScheme
    }

    var isPrivatePlayer: Bool {
        host == PrivatePlayer.privatePlayerHost && pathComponents.count == 3 && pathComponents[safe: 1] == "embed"
    }

    /// Returns true only if the video represents a playlist itself, i.e. doesn't have `index` query parameter
    var isYoutubePlaylist: Bool {
        guard isYoutubeWatch, let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return false
        }

        let isPlaylistURL = components.queryItems?.contains(where: { $0.name == "list" }) == true &&
        components.queryItems?.contains(where: { $0.name == "v" }) == true &&
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
        youtubeVideoParams?.videoID
    }

    var youtubeVideoParams: (videoID: String, timestamp: String?)? {
        if isPrivatePlayerScheme {
#warning("Remove this once Private Player URLs get fixed on the JS side")
            let fixedAbsoluteString = absoluteString.replacingOccurrences(of: "&", with: "?")
            guard let components = URLComponents(string: fixedAbsoluteString), let unsafeVideoID = components.host else {
                return nil
            }
            let timestamp = components.queryItems?.first(where: { $0.name == "t" })?.value
            return (unsafeVideoID.removingCharacters(in: .youtubeVideoIDNotAllowed), timestamp)
        }

        if isPrivatePlayer {
            let unsafeVideoID = lastPathComponent
            let timestamp = getParameter(named: "t")
            return (unsafeVideoID.removingCharacters(in: .youtubeVideoIDNotAllowed), timestamp)
        }

        guard isYoutubeVideo,
              let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let unsafeVideoID = components.queryItems?.first(where: { $0.name == "v" })?.value
        else {
            return nil
        }

        let timestamp = components.queryItems?.first(where: { $0.name == "t" })?.value
        return (unsafeVideoID.removingCharacters(in: .youtubeVideoIDNotAllowed), timestamp)
    }

    // MARK: - Private

    private func addingTimestamp(_ timestamp: String?) -> URL {
        guard let timestamp = timestamp,
              let regex = try? NSRegularExpression.init(pattern: "(\\d+[smh])+"),
              timestamp.matches(regex)
        else {
            return self
        }
        return appendingParameter(name: "t", value: timestamp)
    }
}

extension CharacterSet {
    static let youtubeVideoIDNotAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_").inverted
}
