//
//  NSSizeExtension.swift
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
import DeveloperToolsSupport

extension NSSize {

    static var faviconSize: NSSize { NSSize(width: 16, height: 16) }

    // Smaller in both width and height, not area
    func isSmaller(than size: CGSize) -> Bool {
        width < size.width && height < size.height
    }

    func scaled(by scaleFactor: CGFloat) -> NSSize {
        NSSize(width: width * scaleFactor, height: height * scaleFactor)
    }

}

extension CGSize {
    /// #Preview helper to convert CGSize to Preview Traits
    @available(macOS 14.0, *)
    var fixedLayout: PreviewTrait<Preview.ViewTraits> {
        MainActor.assumeIsolated {
            .fixedLayout(width: width, height: height)
        }
    }
}
