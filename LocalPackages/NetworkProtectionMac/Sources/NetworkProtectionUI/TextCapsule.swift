//
//  File.swift
//  
//
//  Created by ddg on 1/24/24.
//

import Foundation
import SwiftUI

struct TextCapsule: View {
    var index: Int
    var text: String
    var color: Color

    init(index: Int, text: String, color: Color) {
        self.index = index
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .fontWeight(.bold)
            .multilineText()
            .frame(width: 300, height: 40)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}
