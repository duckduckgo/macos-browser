//
//  AppCreator.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

protocol AppCreatorProtocol {

    func createStandaloneApp(from url: URL, name: String)

}

final class AppCreator: AppCreatorProtocol {

    static var shared = AppCreator()

    private let faviconService: FaviconService

    init(faviconService: FaviconService = LocalFaviconService.shared) {
        self.faviconService = faviconService
    }

    func createStandaloneApp(from url: URL, name: String) {
        let iconPath = "/tmp/appIcon@2x.png"

        guard let host = url.host else {
            assertionFailure("No host, no fun")
            return
        }

        func saveIcon(_ favicon: NSImage) {
            let imageURL = URL(fileURLWithPath: iconPath)
            guard let png = favicon.png else {
                assertionFailure("No png, no fun")
                return
            }

            do {
                try png.write(to: imageURL)
            } catch {
                assertionFailure("png is angry")
            }
        }

        func runCreationScript(url: URL) {
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = [
                Bundle.main.url(forResource: "create-app", withExtension: "sh")!.absoluteString.drop(prefix: "file://"),
                iconPath,
                name,
                url.absoluteString]
            process.launch()
        }

        if let favicon = faviconService.getCachedFavicon(for: host,
                                                         mustBeFromUserScript: true) {
            saveIcon(favicon)
        }

        runCreationScript(url: url)
    }

}

fileprivate extension NSBitmapImageRep {

    var png: Data? { representation(using: .png, properties: [:]) }

}

fileprivate extension Data {

    var bitmap: NSBitmapImageRep? { NSBitmapImageRep(data: self) }

}

fileprivate extension NSImage {

    var png: Data? { tiffRepresentation?.bitmap?.png }

}
