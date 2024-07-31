//
//  DebugInformationViewModel.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Foundation
import NetworkProtection
import SwiftUI

public final class DebugInformationViewModel: ObservableObject {

    let showDebugInformation: Bool
    let bundlePath: String
    let version: String
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization & Deinitialization

    public init(showDebugInformation: Bool,
                bundle: Bundle = .main) {

        self.showDebugInformation = showDebugInformation
        bundlePath = bundle.bundlePath

        // swiftlint:disable:next force_cast
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String

        // swiftlint:disable:next force_cast
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        version = shortVersion + " (build: " + buildNumber + ")"
    }
}
