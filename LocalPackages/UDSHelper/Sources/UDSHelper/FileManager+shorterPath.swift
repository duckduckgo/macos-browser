//
//  File.swift
//  
//
//  Created by ddg on 11/19/23.
//

import Foundation

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
            // Can't shorten
            return fileURL
        }

        // Just make extra sure there's nothing there
        try? removeItem(at: shortenedFileURL)
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

        do {
            try removeItem(at: shortSocketURL)
        } catch let error as CocoaError {
            switch error.code {
            case .fileNoSuchFile:
                // Ignored because this means "No such file"... so it's ok if we can't delete a
                // file that does not exist.
                break
            default:
                throw error
            }
        }

        return shortSocketURL
    }
}
