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

import AppKit
import Foundation
import PrivacyDashboard

struct PrivacyIconViewModel {

    private static let maxNumberOfIcons = 4

    static func trackerImages(from trackerInfo: TrackerInfo) -> [CGImage] {
        let sortedEntities = sortedEntities(from: trackerInfo).prefix(maxNumberOfIcons)
        var images: [CGImage] = sortedEntities.map {
            if let logo = logo(for: $0) {
                return logo
            } else if let letter = letters[$0[$0.startIndex]] {
                return letter
            } else {
                return blankTrackerImage
            }
        }
        if images.count == maxNumberOfIcons {
            images[maxNumberOfIcons - 1] = shadowTrackerImage
        }
        return images
    }

    private static func sortedEntities(from trackerInfo: TrackerInfo) -> [String] {
        struct LightEntity: Hashable {
            let name: String
            let prevalence: Double
        }

        let blockedEntities: Set<LightEntity> =
            // Filter entity duplicates by using Set
            Set(trackerInfo.trackersBlocked
                    // Filter trackers without entity or entity name
                    .compactMap {
                        if let entityName = $0.entityName, entityName.count > 0 {
                            return LightEntity(name: entityName, prevalence: $0.prevalence ?? 0)
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
                return $0.name.lowercased()
            }
            // Prioritise entities with images
            .sorted { _, r -> Bool in
                return "aeiou".contains(r[r.startIndex])
            }
    }

    // MARK: - Images

    static var shadowTrackerImage: CGImage! {
        {
            if NSApp.effectiveAppearance.name == .aqua {
                NSImage.shadowtracker
            } else {
                NSImage.shadowtrackerDark
            }
        }().cgImage(forProposedRect: nil, context: .current, hints: nil)
    }

    static var blankTrackerImage: CGImage! {
        {
            if NSApp.effectiveAppearance.name == .aqua {
                NSImage.blanktracker
            } else {
                NSImage.blanktrackerDark
            }
        }().cgImage(forProposedRect: nil, context: .current, hints: nil)
    }

    static var letters: [Character: CGImage] {
        if NSApp.effectiveAppearance.name == .aqua {
            return lettersAqua
        } else {
            return lettersDark
        }
    }

    private static let lettersAqua: [Character: CGImage] = {
        Character.reduceCharacters(from: "a", to: "z", into: [:]) {
            $0[$1] = NSImage(named: "\($1)")!.cgImage(forProposedRect: nil, context: .current, hints: nil)
        }
    }()

    private static let lettersDark: [Character: CGImage] = {
        Character.reduceCharacters(from: "a", to: "z", into: [:]) {
            $0[$1] = NSImage(named: "\($1)_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)
        }
    }()

    static func logo(for trackerNetworkName: String) -> CGImage? {
        guard let trackerNetwork = TrackerNetwork(trackerNetworkName: trackerNetworkName) else { return nil }
        return {
            if NSApp.effectiveAppearance.name == .aqua {
                aquaLogo(for: trackerNetwork)
            } else {
                darkLogo(for: trackerNetwork)
            }
        }()?.cgImage(forProposedRect: nil, context: .current, hints: nil)
    }

    private static func aquaLogo(for trackerNetwork: TrackerNetwork) -> NSImage? {
        switch trackerNetwork {
        case .adform:            .adform
        case .adobe:             .adobe
        case .amazon:            .amazon
        case .amobee:            .amobee
        case .appnexus:          .appnexus
        case .centro:            .centro
        case .cloudflare:        .cloudflare
        case .comscore:          .comscore
        case .conversant:        .conversant
        case .criteo:            .criteo
        case .dataxu:            .dataxu
        case .facebook:          .facebook
        case .google:            .google
        case .hotjar:            .hotjar
        case .indexexchange:     .indexexchange
        case .iponweb:           .iponweb
        case .linkedin:          .linkedin
        case .lotame:            .lotame
        case .mediamath:         .mediamath
        case .microsoft:         .microsoft
        case .neustar:           .neustar
        case .newrelic:          .newrelic
        case .nielsen:           .nielsen
        case .openx:             .openx
        case .oracle:            .oracle
        case .pubmatic:          .pubmatic
        case .qwantcast:         .qwantcast
        case .rubicon:           .rubicon
        case .salesforce:        .salesforce
        case .smartadserver:     .smartadserver
        case .spotx:             .spotx
        case .stackpath:         .stackpath
        case .taboola:           .taboola
        case .tapad:             .tapad
        case .theTradeDesk:      .thetradedesk
        case .towerdata:         .towerdata
        case .twitter:           .twitter
        case .verizonMedia:      .verizonmedia
        case .windows:           .windows
        case .xaxis:             .xaxis
        }
    }

    private static func darkLogo(for trackerNetwork: TrackerNetwork) -> NSImage? {
        switch trackerNetwork {
        case .adform:            .adformDark
        case .adobe:             .adobeDark
        case .amazon:            .amazonDark
        case .amobee:            .amobeeDark
        case .appnexus:          .appnexusDark
        case .centro:            .centroDark
        case .cloudflare:        .cloudflareDark
        case .comscore:          .comscoreDark
        case .conversant:        .conversantDark
        case .criteo:            .criteoDark
        case .dataxu:            .dataxuDark
        case .facebook:          .facebookDark
        case .google:            .googleDark
        case .hotjar:            .hotjarDark
        case .indexexchange:     .indexexchangeDark
        case .iponweb:           .iponwebDark
        case .linkedin:          .linkedinDark
        case .lotame:            .lotameDark
        case .mediamath:         .mediamathDark
        case .microsoft:         .microsoftDark
        case .neustar:           .neustarDark
        case .newrelic:          .newrelicDark
        case .nielsen:           .nielsenDark
        case .openx:             .openxDark
        case .oracle:            .oracleDark
        case .pubmatic:          .pubmaticDark
        case .qwantcast:         .qwantcastDark
        case .rubicon:           .rubiconDark
        case .salesforce:        .salesforceDark
        case .smartadserver:     .smartadserverDark
        case .spotx:             .spotxDark
        case .stackpath:         .stackpathDark
        case .taboola:           .taboolaDark
        case .tapad:             .tapadDark
        case .theTradeDesk:      .thetradedeskDark
        case .towerdata:         .towerdataDark
        case .twitter:           .twitterDark
        case .verizonMedia:      .verizonmediaDark
        case .windows:           .windowsDark
        case .xaxis:             .xaxisDark
        }
    }
}

extension Character {

    @inlinable static func reduceCharacters<Result>(from startCharacter: Character, to endCharacter: Character, into initialResult: Result, _ updateAccumulatingResult: (_ partialResult: inout Result, Character) throws -> Void) rethrows -> Result {
        assert(startCharacter.unicodeScalars.count == 1)
        assert(endCharacter.unicodeScalars.count == 1)
        guard let start = startCharacter.unicodeScalars.first?.value,
              let end = endCharacter.unicodeScalars.first?.value,
              start <= end else {
            assertionFailure("Characters \(startCharacter) and \(endCharacter) do not form sequence")
            return initialResult
        }

        return try (start...end).reduce(into: initialResult) { result, char in
            try updateAccumulatingResult(&result, Character(UnicodeScalar(char)!))
        }
    }

}
