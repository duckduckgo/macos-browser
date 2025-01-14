//
//  NewTabPageDataModel+CustomBackground.swift
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

import AppKitExtensions
import Foundation

public extension NewTabPageDataModel {

    struct CustomizerData: Encodable, Equatable {
        public let background: Background
        public let theme: Theme?
        public let userColor: Background?
        public let userImages: [UserImage]

        public init(background: Background, theme: Theme?, userColor: NSColor?, userImages: [UserImage]) {
            self.background = background
            self.theme = theme
            self.userImages = userImages
            if let hex = userColor?.hex() {
                self.userColor = Background.hexColor(hex)
            } else {
                self.userColor = nil
            }
        }

        enum CodingKeys: CodingKey {
            case background
            case theme
            case userColor
            case userImages
        }

        public func encode(to encoder: any Encoder) throws {
            var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.background, forKey: CodingKeys.background)
            try container.encode(self.theme?.rawValue ?? "system", forKey: CodingKeys.theme)
            try container.encode(self.userColor, forKey: CodingKeys.userColor)
            try container.encode(self.userImages, forKey: CodingKeys.userImages)
        }
    }

    struct ThemeData: Codable, Equatable {
        let theme: Theme?

        enum CodingKeys: CodingKey {
            case theme
        }

        public init(theme: Theme?) {
            self.theme = theme
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(self.theme?.rawValue ?? "system", forKey: CodingKeys.theme)
        }

        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            let themeRawValue = try container.decode(String.self, forKey: CodingKeys.theme)
            theme = Theme(rawValue: themeRawValue)
        }
    }

    enum Theme: String, Codable {
        case dark, light
    }

    enum Background: Codable, Equatable {
        case `default`
        case solidColor(String)
        case hexColor(String)
        case gradient(String)
        case userImage(UserImage)

        /**
         * Custom implementation of this function is here to perform case-insensitive comparison for hex colors.
         */
        public static func == (lhs: Background, rhs: Background) -> Bool {
            switch (lhs, rhs) {
            case (.default, .default):
                return true
            case (.solidColor(let lColor), .solidColor(let rColor)):
                return lColor == rColor
            case (.hexColor(let lColor), .hexColor(let rColor)):
                return lColor.lowercased() == rColor.lowercased()
            case (.gradient(let lGradient), .gradient(let rGradient)):
                return lGradient == rGradient
            case (.userImage(let lUserImage), .userImage(let rUserImage)):
                return lUserImage == rUserImage
            default:
                return false
            }
        }

        enum CodingKeys: CodingKey {
            case kind
            case value
        }

        enum Kind: String, Codable {
            case `default`, color, hex, gradient, userImage
        }

        var kind: Kind {
            switch self {
            case .default:
                return .default
            case .solidColor:
                return .color
            case .hexColor:
                return .hex
            case .gradient:
                return .gradient
            case .userImage:
                return .userImage
            }
        }

        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Kind.self, forKey: CodingKeys.kind)
            switch kind {
            case .color, .hex:
                let value = try container.decode(String.self, forKey: CodingKeys.value)
                self = .solidColor(value)
            case .gradient:
                let value = try container.decode(String.self, forKey: CodingKeys.value)
                self = .gradient(value)
            case .userImage:
                let value = try container.decode(UserImage.self, forKey: CodingKeys.value)
                self = .userImage(value)
            default:
                self = .default
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind, forKey: CodingKeys.kind)
            switch self {
            case .default:
                break
            case .solidColor(let value), .hexColor(let value), .gradient(let value):
                try container.encode(value, forKey: CodingKeys.value)
            case .userImage(let image):
                try container.encode(image, forKey: CodingKeys.value)
            }
        }
    }

    struct UserImage: Codable, Equatable {
        public let colorScheme: Theme
        public let id: String
        public let src: String
        public let thumb: String

        public init(colorScheme: Theme, id: String, src: String, thumb: String) {
            self.colorScheme = colorScheme
            self.id = id
            self.src = src
            self.thumb = thumb
        }
    }
}

extension NewTabPageDataModel {

    struct BackgroundData: Codable, Equatable {
        let background: Background
    }

    struct UserImagesData: Codable, Equatable {
        let userImages: [UserImage]
    }

    struct DeleteImageData: Codable, Equatable {
        let id: String
    }

    struct UserImageContextMenu: Codable, Equatable {
        let target: Target
        let id: String

        enum Target: String, Codable, Equatable {
            case userImage
        }
    }
}
