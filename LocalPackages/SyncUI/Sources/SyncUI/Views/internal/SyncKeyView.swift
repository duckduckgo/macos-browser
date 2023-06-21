//
//  SyncKeyView.swift
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

struct SyncKeyView: View {
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(paddedText.prefix(64)).chunked(into: 16)) { rowChunk in
                HStack {
                    Text(String(rowChunk[0..<4]))
                        .font(monospaceFont)
                    Spacer()
                    Text(String(rowChunk[4..<8]))
                        .font(monospaceFont)
                    Spacer()
                    Text(String(rowChunk[8..<12]))
                        .font(monospaceFont)
                    Spacer()
                    Text(String(rowChunk[12..<16]))
                        .font(monospaceFont)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var paddedText: String {
        text.count > 64 ? String(text.prefix(63) + "…") : String(text.padding(toLength: 64, withPad: " ", startingAt: 0))
    }

    private var monospaceFont: Font {
        if #available(macOS 12.0, *) {
            return .system(size: 15, weight: .semibold).monospaced()
        }
        return Font.custom("SF Mono", size: 15).weight(.semibold)
    }
}
