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

extension ColorScheme: LosslessStringConvertible {
    public init?(_ description: String) {
        switch description {
        case "light":
            self = .light
        case "dark":
            self = .dark
        default:
            return nil
        }
    }

    public var description: String {
        self == .light ? "light" : "dark"
    }
}

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
        guard let index = description.lastIndex(of: "|") else {
            return nil
        }
        let fileName = String(description.prefix(upTo: index))
        let colorSchemeDescription = String(description.suffix(from: description.index(after: index)))

        guard !fileName.isEmpty, let colorScheme = ColorScheme(colorSchemeDescription) else {
            return nil
        }

        self.fileName = fileName
        self.colorScheme = colorScheme
    }

    var description: String {
        "\(fileName)|\(colorScheme.description)"
    }
}
