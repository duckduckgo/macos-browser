//
//  FaviconLetterView.swift
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

struct LetterIconView: View {

    var title: String
    var size: CGFloat = 32
    var prefferedFirstCharacters: String?
    var characterCount = 2

    var characters: String {
        if let prefferedFirstCharacters = prefferedFirstCharacters,
           prefferedFirstCharacters != "" {
            return String(prefferedFirstCharacters.prefix(characterCount))
        }
        return String(title.prefix(characterCount))
    }
    
    

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.125)
                .foregroundColor(Color.forString(title))
                .frame(width: size, height: size)

            Text(characters.capitalized(with: .current))
                .frame(width: size - 10, height: size - 10)
                .foregroundColor(.white)
                .minimumScaleFactor(0.01)
                .font(.system(size: size, weight: .bold))
        }
        .padding(.leading, 8)
    }
}
