//
//  URLExtension.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log

extension URL {

    // MARK: - Factory

    static func makeSearchUrl(from searchQuery: String) -> URL? {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            var searchUrl = Self.duckDuckGo
            searchUrl = try searchUrl.addParameter(name: DuckDuckGoParameters.search.rawValue, value: trimmedQuery)
            return searchUrl
        } catch let error {
            os_log("URL extension: %s", type: .error, error.localizedDescription)
            return nil
        }
    }

    static func makeURL(from addressBarString: String) -> URL? {
        if let addressBarUrl = addressBarString.url, addressBarUrl.isValid {
            return addressBarUrl
        }

        if let searchUrl = URL.makeSearchUrl(from: addressBarString) {
            return searchUrl
        }

        os_log("URL extension: Making URL from %s failed", type: .error, addressBarString)
        return nil
    }

    static var emptyPage: URL {
        return URL(string: "about:blank")!
    }

    // MARK: - Parameters

    enum ParameterError: Error {
        case parsingFailed
        case encodingFailed
        case creatingFailed
    }

    func addParameter(name: String, value: String) throws -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { throw ParameterError.parsingFailed }
        var queryItems = components.queryItems ?? [URLQueryItem]()
        let newQueryItem = URLQueryItem(name: name, value: value)
        queryItems.append(newQueryItem)
        components.queryItems = queryItems
        guard let encodedQuery = components.percentEncodedQuery else { throw ParameterError.encodingFailed }
        components.percentEncodedQuery = encodedQuery.encodingPluses()
        guard let newUrl = components.url else { throw ParameterError.creatingFailed }
        return newUrl
    }

    func getParameter(name: String) throws -> String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { throw ParameterError.parsingFailed }
        guard let encodedQuery = components.percentEncodedQuery else { throw ParameterError.encodingFailed }
        components.percentEncodedQuery = encodedQuery.encodingPlusesAsSpaces()
        let queryItem = components.queryItems?.first(where: { (queryItem) -> Bool in
            queryItem.name == name
        })
        return queryItem?.value
    }

    // MARK: - Components

    enum NavigationalScheme: String, CaseIterable {
        case http
        case https

        func separated() -> String {
            self.rawValue + "://"
        }
    }

    enum HostPrefix: String {
        case www

        func separated() -> String {
            self.rawValue + "."
        }
    }

    // MARK: - Validity

    var isValid: Bool {
        guard let scheme = scheme else { return false }

        if URL.NavigationalScheme(rawValue: scheme) != nil,
           let host = host, host.isValidHost,
           user == nil { return true }

        // This effectively allows external URLs
        return true
    }

    // MARK: - DuckDuckGo

    static var duckDuckGo: URL {
        let duckDuckGoUrlString = "https://duckduckgo.com/"
        return URL(string: duckDuckGoUrlString)!
    }

    static var duckDuckGoAutocomplete: URL {
        duckDuckGo.appendingPathComponent("ac/")
    }

    var isDuckDuckGo: Bool {
        absoluteString.starts(with: Self.duckDuckGo.absoluteString)
    }

    // swiftlint:disable unused_optional_binding
    var isDuckDuckGoSearch: Bool {
        if isDuckDuckGo, let _ = try? getParameter(name: DuckDuckGoParameters.search.rawValue) {
            return true
        }

        return false
    }
    // swiftlint:enable unused_optional_binding

    enum DuckDuckGoParameters: String {
        case search = "q"
    }

    // MARK: - Search

    var searchQuery: String? {
        guard isDuckDuckGo else { return nil }
        return try? getParameter(name: DuckDuckGoParameters.search.rawValue)
    }

    // MARK: - Feedback

#if FEEDBACK

    static var feedback: URL {
        return URL(string: "https://form.asana.com/?k=HzdxNoIgDZUBf4w0_cafIQ&d=137249556945")!
    }

#endif

    // MARK: - HTTPS

    func toHttps() -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        guard components.scheme == NavigationalScheme.http.rawValue else { return self }
        components.scheme = NavigationalScheme.https.rawValue
        return components.url
    }

    // MARK: - File Downloads

    func moveToDownloadsFolder(withFileName fileName: String) -> String? {

        func incrementFileName(in folder: URL, named name: String, copy: Int) -> URL {
            // Zero means we haven't tried anything yet, so use the suggested name.  Otherwise, simply prefix the file name with the copy number.
            let path = copy == 0 ? name : "\(copy)_\(name)"
            let file = folder.appendingPathComponent(path)
            return file
        }

        let fm = FileManager.default
        let folders = fm.urls(for: .downloadsDirectory, in: .userDomainMask)
        guard let folderUrl = folders.first,
              let resolvedFolderUrl = try? URL(resolvingAliasFileAt: folderUrl),
              fm.isWritableFile(atPath: resolvedFolderUrl.path) else {
            os_log("Failed to access Downloads folder")
            return nil
        }

        var copy = 0
        while copy < 1000 { // If it gets to 1000 of these then chances are something else is wrong

            let fileInDownloads = incrementFileName(in: folderUrl, named: fileName, copy: copy)
            do {
                try fm.moveItem(at: self, to: fileInDownloads)
                return fileInDownloads.path
            } catch {
                // This is expected, as moveItem throws an error if the file already exists
            }
            copy += 1
        }

        os_log("Failed to move file to Downloads folder, attempt %d", type: .error, copy)
        return nil
    }

}
