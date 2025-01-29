//
//  DockCustomizerMock.swift
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

import Combine
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class DockCustomizerMock: DockCustomization {
    private var featureShownSubject = CurrentValueSubject<Bool, Never>(false)

    var wasFeatureShownPublisher: AnyPublisher<Bool, Never> {
        featureShownSubject.eraseToAnyPublisher()
    }

    var wasFeatureShownFromMoreOptionsMenu: Bool {
        get { featureShownSubject.value }
        set { featureShownSubject.send(newValue) }
    }

    var dockStatus: Bool = false

    var isAddedToDock: Bool {
        return dockStatus
    }

    @discardableResult
    func addToDock() -> Bool {
        if !dockStatus {
            dockStatus = true
            return true
        } else {
            return false
        }
    }
}
