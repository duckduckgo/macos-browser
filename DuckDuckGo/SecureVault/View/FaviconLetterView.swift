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

struct AutofillIconLetterView: View {

    enum Constants {
        static let randomColor = "RandomColor"
        static let totalRandomColors = 15
    }

    var title: String
    var size: CGFloat = 32
    var prefferedFirstCharacter: String?

    var color: Color {                
        Color("\(Constants.randomColor)\(abs(title.hashValue) % Constants.totalRandomColors)")
    }
    
    var letter: Character {
        if let prefferedFirstCharacter {
            return Character(prefferedFirstCharacter)
        } 
        return title.first ?? "#"
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.125)
                .foregroundColor(color)
                .frame(width: size, height: size)

            Text(letter.uppercased())
                .font(.system(size: size * 0.76, weight: .bold, design: .default))
                .foregroundColor(.white)
        }
        .padding(.leading, 8)
    }
}
