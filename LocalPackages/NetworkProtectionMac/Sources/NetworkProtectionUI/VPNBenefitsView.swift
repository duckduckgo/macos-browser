//
//  File.swift
//  
//
//  Created by ddg on 1/24/24.
//

import Foundation
import SwiftUI

private func randomColorDominant() -> Color {
    // Define a range for the dominant and non-dominant color values
    let dominantRange = 0.5...0.7
    let nonDominantRange = 0.0...0.5

    // Randomly choose which color component will be dominant
    let dominantColor = Int.random(in: 1...3)

    let red: Double
    let green: Double
    let blue: Double

    switch dominantColor {
    case 1: // Red dominant
        red = Double.random(in: dominantRange)
        green = Double.random(in: nonDominantRange)
        blue = Double.random(in: nonDominantRange)
    case 2: // Green dominant
        red = Double.random(in: nonDominantRange)
        green = Double.random(in: dominantRange)
        blue = Double.random(in: nonDominantRange)
    default: // Blue dominant
        red = Double.random(in: nonDominantRange)
        green = Double.random(in: nonDominantRange)
        blue = Double.random(in: dominantRange)
    }

    return Color(red: red, green: green, blue: blue)
}

private struct DomainEntry: Hashable {
    let domain: String
    let color: Color
}

private var entries = Set([
    DomainEntry(domain: "DuckDuckGo.com -> google.com", color: randomColorDominant()),
    DomainEntry(domain: "apple.com", color: randomColorDominant())
])

struct VPNBenefitsView: View {
    public var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(entries.enumerated()), id: \.element.domain) { index, entry in
                TextCapsule(index: index, text: entry.domain, color: entry.color)
            }
        }
    }
}
