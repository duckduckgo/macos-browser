//
//  FileManager+shorterPath.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

public protocol UDSURLShortening {
    func shorten(_ url: URL, symlinkName: String) throws -> URL
}

/// Default shortener using the default `FileManager` singleton.
///
public struct UDSURLShortener: UDSURLShortening {

    public init() {}

    public func shorten(_ url: URL, symlinkName: String) throws -> URL {
        try FileManager.default.shortenSocketURL(socketFileURL: url, symlinkName: symlinkName)
    }
}

extension FileManager {

    /// Creates a shortened URL  for accessing the specified file (using symlinks).
    ///
    /// This is useful for turning a possibly long file path into a shorter one.  This is necessary for example for
    /// Unix Domain Sockets to access really long paths as they're limited to 104 bytes only.
    ///
    /// - Parameters:
    ///     - targetFileURL: the target file we want to get a symlink for.
    ///     - symlinkName: the identifier of the target file in the temp directory.  This is specified to ensure you can
    ///             pick a short name at the new location, rather than depending on the existing file name which
    ///             could turn out to be really long.
    ///
    private func shortenURL(for fileURL: URL, symlinkName: String) throws -> URL {
        let shortenedFileURL = temporaryDirectory.appendingPathComponent(symlinkName)

        guard fileURL.path.count > shortenedFileURL.path.count else {
            // The file URL is already shorter that what we can produce
            return fileURL
        }

        // Just make extra sure there's no pre-existing file at the shortened file path
        //try? removeItem(at: shortenedFileURL)
        try createSymbolicLink(at: shortenedFileURL, withDestinationURL: fileURL)

        return shortenedFileURL
    }

    /// Shortens the URL for a Unix Domain Socket so that it fits within the 104 bytes path limit imposed
    /// by `sockaddr_un.sun_addr`.
    ///
    /// - Parameters:
    ///     - socketURL: the socket file URL.
    ///     - symlinkName: an identified that will be used as the name of the symlink.  Since the purpose
    ///             of this method is to shorten the final URL, it is recommended for this name to
    ///             be short too.
    ///
    func shortenSocketURL(socketFileURL: URL, symlinkName: String) throws -> URL {
        let directoryURL = socketFileURL.deletingLastPathComponent()
        let shortenedDirectoryURL = try shortenURL(for: directoryURL, symlinkName: symlinkName)
        let shortSocketURL = shortenedDirectoryURL.appendingPathComponent(socketFileURL.lastPathComponent)
/*
        do {
            try removeItem(at: shortSocketURL)
        } catch let error as CocoaError {
            switch error.code {
            case .fileNoSuchFile:
                // Ignored because it's ok if we can't delete a file that we accept may not exist.
                break
            default:
                throw error
            }
        }*/

        return shortSocketURL
    }
}
