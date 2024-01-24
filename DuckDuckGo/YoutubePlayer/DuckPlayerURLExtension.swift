//
//  DuckPlayerURLExtension.swift
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
    static func effectiveDuckPlayer(_ videoID: String, timestamp: String? = nil) -> URL {
        if DuckPlayer.usesSimulatedRequests {
            return .youtubeNoCookie(videoID, timestamp: timestamp)
        }
        return .duckPlayer(videoID, timestamp: timestamp)
    }

    static func duckPlayer(_ videoID: String, timestamp: String? = nil) -> URL {
        let url = "\(NavigationalScheme.duck.rawValue)://player/\(videoID)".url!
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

    var isDuckURLScheme: Bool {
        navigationalScheme == .duck
    }

    /**
     * Returns true if a URL represents a Private Player URL.
     *
     * It primarily checks for `duck://player/` URL, but on macOS 12 and above (when using simulated requests),
     * the Duck Scheme URL is eventually replaced by `www.youtube-nocookie.com/embed/VIDEOID` URL so this
     * is checked too and this function returns `true` if any of the two is true on macOS 12.
     */
    var isDuckPlayer: Bool {
        let isPrivatePlayer = isDuckURLScheme && host == DuckPlayer.duckPlayerHost
        if DuckPlayer.usesSimulatedRequests {
            return isPrivatePlayer || isYoutubeNoCookie
        } else {
            return isPrivatePlayer
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
        if isDuckURLScheme {
            guard let components = URLComponents(string: absoluteString) else {
                return nil
            }
            let unsafeVideoID = components.path
            let timestamp = components.queryItems?.first(where: { $0.name == "t" })?.value
            return (unsafeVideoID.removingCharacters(in: .youtubeVideoIDNotAllowed), timestamp)
        }

        if isDuckPlayer {
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

    private var isYoutubeNoCookie: Bool {
        host == "www.youtube-nocookie.com" && pathComponents.count == 3 && pathComponents[safe: 1] == "embed"
    }

    private var isYoutubeWatch: Bool {
        guard let host else { return false }
        return host.contains("youtube.com") && path == "/watch"
    }

    private func addingTimestamp(_ timestamp: String?) -> URL {
        guard let timestamp = timestamp,
              let regex = try? NSRegularExpression(pattern: "^(\\d+[smh]?)+$"),
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
