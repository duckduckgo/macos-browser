//
//  DismissAction+macOS11Support.swift
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
import SwiftUI

@available(macOS, introduced: 10.15, obsoleted: 12.0, message: "Use Apple's DismissAction")
public struct DismissAction: EnvironmentKey {
    public static var defaultValue: () -> Void = {}
}

public extension EnvironmentValues {

    @available(macOS, introduced: 10.15, obsoleted: 12.0, message: "Use Apple's EnvironmentValues.dismiss")
    var dismiss: () -> Void {
        get {
            self[DismissAction.self]
        }

        set {
            self[DismissAction.self] = newValue
        }
    }
}
