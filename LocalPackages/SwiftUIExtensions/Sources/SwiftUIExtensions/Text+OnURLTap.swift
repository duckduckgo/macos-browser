//
//  Text+OnURLTap.swift
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

import SwiftUI

public extension Text {

    /// We only support URL tap handler in `Text` views on iOS 15+ and macOS 12+.
    /// Right now there's no simple way to offer this in lower versions.
    ///
    @ViewBuilder
    func onURLTap(onTap: @escaping (URL) -> Void) -> some View {
        if #available(iOS 15.0, macOS 12.0, *) {
            self.environment(\.openURL, OpenURLAction { url in
                onTap(url)
                return .handled
            })
        }
    }
}
