//
//  ClickToLoadModel.swift
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

struct ClickToLoadModel {

    private static func loadFile(name: String) -> String? {
        let pathPrefix = "social_images/"
        let fileArgs = name.split(separator: ".")
        let fileName = String(fileArgs[0])
        let fileExt = String(fileArgs[1])

        let filePath = pathPrefix + fileName

        let imgURL = Bundle.main.url(
            forResource: filePath,
            withExtension: fileExt
        )
        if imgURL == nil {
            return nil
        }
        guard let base64String = try? Data(contentsOf: imgURL!).base64EncodedString() else { return nil }
        let image = "data:image/" + (fileExt == "svg" ? "svg+xml" : fileExt) + ";base64," + base64String
        return image
    }

    static let getImage: [String: String] = {
        return [
            "dax.png": Self.loadFile(name: "dax.png")!,
            "loading_light.svg": Self.loadFile(name: "loading_light.svg")!,
            "loading_dark.svg": Self.loadFile(name: "loading_dark.svg")!,
            "blocked_facebook_logo.svg": Self.loadFile(name: "blocked_facebook_logo.svg")!,
            "blocked_group.svg": Self.loadFile(name: "blocked_group.svg")!,
            "blocked_page.svg": Self.loadFile(name: "blocked_page.svg")!,
            "blocked_post.svg": Self.loadFile(name: "blocked_post.svg")!,
            "blocked_video.svg": Self.loadFile(name: "blocked_video.svg")!
        ]
    }()
}
