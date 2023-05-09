//
//  HomePageDefaultBrowserModel.swift
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

extension HomePage.Models {

final class DefaultBrowserModel: ObservableObject {

    @Published var shouldShow: Bool = false

    var wasClosed: Bool {
        didSet {
            updateShowState()
        }
    }

    var isDefault: Bool {
        didSet {
            updateShowState()
        }
    }

    let requestSetDefault: () -> Void
    let close: () -> Void

    init(isDefault: Bool, wasClosed: Bool, requestSetDefault: @escaping () -> Void, close: @escaping () -> Void) {
        self.isDefault = isDefault
        self.wasClosed = wasClosed
        self.requestSetDefault = requestSetDefault
        self.close = close

        updateShowState()
    }

    private func updateShowState() {
        shouldShow = !wasClosed && !isDefault
    }
}

}
