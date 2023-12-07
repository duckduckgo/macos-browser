//
//  LetterIconView.swift
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

import SwiftUI

public struct LetterIconView: View {

    public var title: String
    public var size: CGFloat
    public var prefferedFirstCharacters: String?
    public var characterCount: Int
    private var padding: CGFloat = 0.33
    private static let wwwPreffix = "www."

    private var characters: String {
        if let prefferedFirstCharacters = prefferedFirstCharacters,
           prefferedFirstCharacters != "" {
            return String(prefferedFirstCharacters.prefix(characterCount))
        }
        return String(title.replacingOccurrences(of: Self.wwwPreffix, with: "").prefix(characterCount))
    }

    public init(title: String, size: CGFloat = 32, prefferedFirstCharacters: String? = nil, characterCount: Int = 2) {
        self.title = title
        self.size = size
        self.prefferedFirstCharacters = prefferedFirstCharacters
        self.characterCount = characterCount
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.125)
                .foregroundColor(Color.forString(title))
                .frame(width: size, height: size)

            Text(characters.capitalized(with: .current))
                .frame(width: size - (size * padding), height: size - (size * padding))
                .foregroundColor(.white)
                .minimumScaleFactor(0.01)
                .font(.system(size: size, weight: .semibold))
        }
        .padding(.leading, 8)
    }
}
