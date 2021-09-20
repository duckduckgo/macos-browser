//
//  PrivacyIconViewModel.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Foundation

struct PrivacyIconViewModel {

    private static let maxNumberOfIcons = 4

    static func trackerImages(from trackerInfo: TrackerInfo) -> [CGImage] {
        let sortedEntities = sortedEntityLetters(from: trackerInfo).prefix(maxNumberOfIcons)
        var images: [CGImage] = sortedEntities.map {
            if let image = trackerImages[$0] {
                return image
            } else {
                return blankTrackerImage
            }
        }
        if images.count == maxNumberOfIcons {
            images[maxNumberOfIcons - 1] = shadowTrackerImage
        }
        return images
    }

    private static func sortedEntityLetters(from trackerInfo: TrackerInfo) -> [Character] {
        struct LightEntity: Hashable {
            let name: String
            let prevalence: Double
        }

        let blockedEntities: Set<LightEntity> =
            // Filter entity duplicates by using Set
            Set(trackerInfo.trackersBlocked
                    // Filter trackers without entity or entity name
                    .compactMap {
                        if let entityName = $0.entity?.displayName {
                            return LightEntity(name: entityName, prevalence: $0.entity?.prevalence ?? 0)
                        }
                        return nil
                    })

        return blockedEntities
            // Sort by prevalence
            .sorted { l, r -> Bool in
                return l.prevalence > r.prevalence
            }
            // Get first character
            .map {
                guard $0.name.count > 0 else { return " " }
                return $0.name.uppercased()[$0.name.startIndex]
            }
            // Prioritise entities with images
            .sorted { _, r -> Bool in
                return "AEIOU".contains(r)
            }
    }

    // MARK: - Images

    static var shadowTrackerImage: CGImage {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return shadowTrackerImageAqua
        } else {
            return shadowTrackerImageDark
        }
    }

    private static let shadowTrackerImageAqua = NSImage(named: "ShadowTracker")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
    private static let shadowTrackerImageDark = NSImage(named: "ShadowTrackerDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!

    static var blankTrackerImage: CGImage {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return blankTrackerImageAqua
        } else {
            return blankTrackerImageDark
        }
    }

    static let blankTrackerImageAqua = NSImage(named: "BlankTracker")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
    static let blankTrackerImageDark = NSImage(named: "BlankTrackerDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!

    static var trackerImages: [Character: CGImage] {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return trackerImagesAqua
        } else {
            return trackerImagesDark
        }
    }

    private static let trackerImagesAqua: [Character: CGImage] = {
        return [
            "A": NSImage(named: "A")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "B": NSImage(named: "B")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "C": NSImage(named: "C")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "D": NSImage(named: "D")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "E": NSImage(named: "E")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "F": NSImage(named: "F")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "G": NSImage(named: "G")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "H": NSImage(named: "H")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "I": NSImage(named: "I")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "J": NSImage(named: "J")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "K": NSImage(named: "K")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "L": NSImage(named: "L")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "M": NSImage(named: "M")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "N": NSImage(named: "N")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "O": NSImage(named: "O")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "P": NSImage(named: "P")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Q": NSImage(named: "Q")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "R": NSImage(named: "R")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "S": NSImage(named: "S")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "T": NSImage(named: "T")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "U": NSImage(named: "U")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "V": NSImage(named: "V")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "W": NSImage(named: "W")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "X": NSImage(named: "X")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Y": NSImage(named: "Y")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Z": NSImage(named: "Z")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

    private static let trackerImagesDark: [Character: CGImage] = {
        return [
            "A": NSImage(named: "ADark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "B": NSImage(named: "BDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "C": NSImage(named: "CDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "D": NSImage(named: "DDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "E": NSImage(named: "EDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "F": NSImage(named: "FDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "G": NSImage(named: "GDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "H": NSImage(named: "HDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "I": NSImage(named: "IDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "J": NSImage(named: "JDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "K": NSImage(named: "KDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "L": NSImage(named: "LDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "M": NSImage(named: "MDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "N": NSImage(named: "NDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "O": NSImage(named: "ODark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "P": NSImage(named: "PDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Q": NSImage(named: "QDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "R": NSImage(named: "RDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "S": NSImage(named: "SDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "T": NSImage(named: "TDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "U": NSImage(named: "UDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "V": NSImage(named: "VDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "W": NSImage(named: "WDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "X": NSImage(named: "XDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Y": NSImage(named: "YDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Z": NSImage(named: "ZDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

}
