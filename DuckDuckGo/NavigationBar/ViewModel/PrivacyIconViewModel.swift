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

    static func sortedEntities(from trackerInfo: TrackerInfo) -> [String] {
        struct LightEntity: Hashable {
            let lowercasedName: String
            let prevalence: Double
        }

        let blockedEntities: Set<LightEntity> =
            // Filter entity duplicates by using Set
            Set(trackerInfo.trackersBlocked
                    // Filter trackers without entity or entity name
                    .compactMap {
                        if let entityName = $0.entity?.displayName?.lowercased(), entityName.count > 0 {
                            return LightEntity(lowercasedName: entityName, prevalence: $0.entity?.prevalence ?? 0)
                        }
                        return nil
                    })

        return blockedEntities
            // Sort by prevalence
            .sorted { l, r -> Bool in
                return l.prevalence > r.prevalence
            }
            // Prioritise entities with images
            .sorted { _, r -> Bool in
                return trackerImages[r.lowercasedName] == nil
            }
            .map { $0.lowercasedName }
    }

    static func trackerImages(from trackerInfo: TrackerInfo) -> [CGImage] {
        let sortedEntities = sortedEntities(from: trackerInfo).prefix(maxNumberOfIcons)
        var images: [CGImage] = sortedEntities.map {
            if let image = trackerImages[$0] {
                return image
            } else {
                return blankImage
            }
        }
        if images.count == maxNumberOfIcons {
            images[maxNumberOfIcons - 1] = lastImage
        }
        return images
    }

    static let blankImage = NSImage(named: "tracker-icon-blank")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
    static let lastImage = NSImage(named: "tracker-icon-last")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!

    static let trackerImages: [String: CGImage] = {
        return [
            "criteo": NSImage(named: "tracker-icon-criteo")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "newrelic": NSImage(named: "tracker-icon-newrelic")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "stackpath": NSImage(named: "tracker-icon-stackpath")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "adform": NSImage(named: "tracker-icon-adform")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "dataxu": NSImage(named: "tracker-icon-dataxu")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "nielsen": NSImage(named: "tracker-icon-nielsen")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "taboola": NSImage(named: "tracker-icon-taboola")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "adobe": NSImage(named: "tracker-icon-adobe")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "facebook": NSImage(named: "tracker-icon-facebook")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "openx": NSImage(named: "tracker-icon-openx")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "tapad": NSImage(named: "tracker-icon-tapad")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "amazon": NSImage(named: "tracker-icon-amazon")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "google": NSImage(named: "tracker-icon-google")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "oracle": NSImage(named: "tracker-icon-oracle")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "thetradedesk": NSImage(named: "tracker-icon-thetradedesk")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "amobee": NSImage(named: "tracker-icon-amobee")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "hotjar": NSImage(named: "tracker-icon-hotjar")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "pubmatic": NSImage(named: "tracker-icon-pubmatic")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "towerdata": NSImage(named: "tracker-icon-towerdata")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "appnexus": NSImage(named: "tracker-icon-appnexus")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "indexexchange": NSImage(named: "tracker-icon-indexexchange")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "qwantcast": NSImage(named: "tracker-icon-qwantcast")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "twitter": NSImage(named: "tracker-icon-twitter")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "iponweb": NSImage(named: "tracker-icon-iponweb")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "rubicon": NSImage(named: "tracker-icon-rubicon")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "centro": NSImage(named: "tracker-icon-centro")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "linkedin": NSImage(named: "tracker-icon-linkedin")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "salesforce": NSImage(named: "tracker-icon-salesforce")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "verizonmedia": NSImage(named: "tracker-icon-verizonmedia")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "cloudflare": NSImage(named: "tracker-icon-cloudflare")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "lotame": NSImage(named: "tracker-icon-lotame")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "shadowTracker": NSImage(named: "tracker-icon-shadowTracker")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "windows": NSImage(named: "tracker-icon-windows")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "comscore": NSImage(named: "tracker-icon-comscore")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "mediamath": NSImage(named: "tracker-icon-mediamath")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "smartadserver": NSImage(named: "tracker-icon-smartadserver")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "xaxis": NSImage(named: "tracker-icon-xaxis")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "conversant": NSImage(named: "tracker-icon-conversant")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "neustar": NSImage(named: "tracker-icon-neustar")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "spotx": NSImage(named: "tracker-icon-spotx")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

}
