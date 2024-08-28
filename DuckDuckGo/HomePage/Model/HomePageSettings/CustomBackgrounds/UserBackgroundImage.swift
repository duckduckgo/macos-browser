//
//  UserBackgroundImage.swift
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

import AppKit
import SwiftUI

struct UserBackgroundImage: Hashable, Equatable, Identifiable, LosslessStringConvertible, ColorSchemeProviding, CustomBackgroundConvertible {
    let fileName: String
    let colorScheme: ColorScheme

    var id: String {
        fileName
    }

    var customBackground: CustomBackground {
        .userImage(self)
    }

    init(fileName: String, colorScheme: ColorScheme) {
        self.fileName = fileName
        self.colorScheme = colorScheme
    }

    // MARK: - LosslessStringConvertible

    init?(_ description: String) {
        let components = description.split(separator: "|", maxSplits: 1)
        guard components.count == 2, let colorScheme = ColorScheme(String(components[1])) else {
            return nil
        }
        self.fileName = String(components[0])
        self.colorScheme = colorScheme
    }

    var description: String {
        "\(fileName)|\(colorScheme.description)"
    }
}
