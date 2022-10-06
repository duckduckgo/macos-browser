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
    /**
     * Returns the actual URL of the Private Player page.
     *
     * Depending on the use of simulated requests, it's either the custom scheme URL
     * (without simulated requests, macOS <12), or youtube-nocookie.com URL (macOS 12 and newer).
     */
    static func effectivePrivatePlayer(_ videoID: String, timestamp: String? = nil) -> URL {
        if PrivatePlayer.usesSimulatedRequests {
            return .youtubeNoCookie(videoID, timestamp: timestamp)
        }
        return .privatePlayer(videoID, timestamp: timestamp)
    }

    static func privatePlayer(_ videoID: String, timestamp: String? = nil) -> URL {
        let url = "\(PrivatePlayer.privatePlayerScheme)://player/\(videoID)".url!
        return url.addingTimestamp(timestamp)
    }

    static func youtubeNoCookie(_ videoID: String, timestamp: String? = nil) -> URL {
        let url = "https://www.youtube-nocookie.com/embed/\(videoID)".url!
        return url.addingTimestamp(timestamp)
    }

    static func youtube(_ videoID: String, timestamp: String? = nil) -> URL {
        let url = "https://www.youtube.com/watch?v=\(videoID)".url!
        return url.addingTimestamp(timestamp)
    }

    var isPrivatePlayerScheme: Bool {
        scheme == PrivatePlayer.privatePlayerScheme
    }

    /**
     * Returns true if a URL represents a Private Player URL.
     *
     * When simulated requests are in use (macOS 12 and above), the Private Player Scheme URL is replaced by
     * `www.youtube-nocookie.com/embed/VIDEOID` URL. Otherwise, checks for `duck://player/` URL.
     */
    var isPrivatePlayer: Bool {
        if PrivatePlayer.usesSimulatedRequests {
            return host == PrivatePlayer.privatePlayerHost && pathComponents.count == 3 && pathComponents[safe: 1] == "embed"
        } else {
            return isPrivatePlayerScheme && host == PrivatePlayer.privatePlayerHost
        }
    }

    /// Returns true only if the URL represents a playlist itself, i.e. doesn't have `index` query parameter
    var isYoutubePlaylist: Bool {
        guard isYoutubeWatch, let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return false
        }

        let isPlaylistURL = components.queryItems?.contains(where: { $0.name == "list" }) == true &&
        components.queryItems?.contains(where: { $0.name == "v" }) == true &&
        components.queryItems?.contains(where: { $0.name == "index" }) == false

        return isPlaylistURL
    }

    /// Returns true if the URL represents a YouTube video, but not the playlist (playlists are not supported by Private Player)
    var isYoutubeVideo: Bool {
        isYoutubeWatch && !isYoutubePlaylist
    }

    /**
     * Returns true if the URL represents a YouTube video recommendation.
     *
     * Recommendations are shown at the end of the embedded video or while it's paused.
     */
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

    /// Attempts extracting video ID and timestamp from the URL. Works with all types of YouTube URLs.
    var youtubeVideoParams: (videoID: String, timestamp: String?)? {
        if isPrivatePlayerScheme {
            guard let components = URLComponents(string: absoluteString) else {
                return nil
            }
            let unsafeVideoID = components.path
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

    var youtubeVideoID: String? {
        youtubeVideoParams?.videoID
    }

    // MARK: - Private

    private var isYoutubeWatch: Bool {
        host?.droppingWwwPrefix() == "youtube.com" && path == "/watch"
    }

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
