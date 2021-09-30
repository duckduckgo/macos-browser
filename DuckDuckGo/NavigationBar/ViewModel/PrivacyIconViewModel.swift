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
        let sortedEntities = sortedEntities(from: trackerInfo).prefix(maxNumberOfIcons)
        var images: [CGImage] = sortedEntities.map {
            if let logo = logos[$0] {
                return logo
            } else if let letter = letters[$0[$0.startIndex].uppercased()] {
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
                        if let entityName = $0.entity?.displayName, entityName.count > 0 {
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
                return $0.name
            }
            // Prioritise entities with images
            .sorted { _, r -> Bool in
                return "AEIOU".contains(r[r.startIndex])
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

    static var letters: [String: CGImage] {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return lettersAqua
        } else {
            return lettersDark
        }
    }

    private static let lettersAqua: [String: CGImage] = {
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

    private static let lettersDark: [String: CGImage] = {
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

    static var logos: [String: CGImage] {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return logosAqua
        } else {
            return logosDark
        }
    }

    private static let logosAqua: [String: CGImage] = {
        return [
            "Adform": NSImage(named: "Adform")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Adobe": NSImage(named: "Adobe")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Amazon": NSImage(named: "Amazon")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Amobee": NSImage(named: "Amobee")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Appnexus": NSImage(named: "Appnexus")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Centro": NSImage(named: "Centro")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Cloudflare": NSImage(named: "Cloudflare")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Comscore": NSImage(named: "Comscore")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Conversant": NSImage(named: "Conversant")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Criteo": NSImage(named: "Criteo")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Dataxu": NSImage(named: "Dataxu")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Facebook": NSImage(named: "Facebook")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Google": NSImage(named: "Google")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Hotjar": NSImage(named: "Hotjar")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Indexexchange": NSImage(named: "Indexexchange")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "IPONWEB": NSImage(named: "Iponweb")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "LinkedIn": NSImage(named: "LinkedIn")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Lotame": NSImage(named: "Lotame")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Mediamath": NSImage(named: "Mediamath")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Neustar": NSImage(named: "Neustar")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Newrelic": NSImage(named: "Newrelic")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Nielsen": NSImage(named: "Nielsen")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Openx": NSImage(named: "Openx")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Oracle": NSImage(named: "Oracle")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "PubMatic": NSImage(named: "PubMatic")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Qwantcast": NSImage(named: "Qwantcast")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Rubicon": NSImage(named: "Rubicon")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Salesforce": NSImage(named: "Salesforce")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Smartadserver": NSImage(named: "Smartadserver")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "SpotX": NSImage(named: "SpotX")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "StackPath": NSImage(named: "StackPath")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Taboola": NSImage(named: "Taboola")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Tapad": NSImage(named: "Tapad")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "The Trade Desk": NSImage(named: "TheTradeDesk")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "TowerData": NSImage(named: "TowerData")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Twitter": NSImage(named: "Twitter")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Verizon Media": NSImage(named: "VerizonMedia")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Windows": NSImage(named: "Windows")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Xaxis": NSImage(named: "Xaxis")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

    private static let logosDark: [String: CGImage] = {
        return [
            "Adform": NSImage(named: "AdformDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Adobe": NSImage(named: "AdobeDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Amazon": NSImage(named: "AmazonDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Amobee": NSImage(named: "AmobeeDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Appnexus": NSImage(named: "AppnexusDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Centro": NSImage(named: "CentroDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Cloudflare": NSImage(named: "CloudflareDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Comscore": NSImage(named: "ComscoreDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Conversant": NSImage(named: "ConversantDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Criteo": NSImage(named: "CriteoDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Dataxu": NSImage(named: "DataxuDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Facebook": NSImage(named: "FacebookDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Google": NSImage(named: "GoogleDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Hotjar": NSImage(named: "HotjarDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Indexexchange": NSImage(named: "IndexexchangeDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "IPONWEB": NSImage(named: "IponwebDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "LinkedIn": NSImage(named: "LinkedInDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Lotame": NSImage(named: "LotameDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Mediamath": NSImage(named: "MediamathDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Neustar": NSImage(named: "NeustarDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Newrelic": NSImage(named: "NewrelicDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Nielsen": NSImage(named: "NielsenDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Openx": NSImage(named: "OpenxDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Oracle": NSImage(named: "OracleDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "PubMatic": NSImage(named: "PubMaticDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Qwantcast": NSImage(named: "QwantcastDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Rubicon": NSImage(named: "RubiconDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Salesforce": NSImage(named: "SalesforceDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Smartadserver": NSImage(named: "SmartadserverDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "SpotX": NSImage(named: "SpotXDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "StackPath": NSImage(named: "StackPathDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Taboola": NSImage(named: "TaboolaDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Tapad": NSImage(named: "TapadDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "The Trade Desk": NSImage(named: "TheTradeDeskDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "TowerData": NSImage(named: "TowerDataDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Twitter": NSImage(named: "TwitterDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Verizon Media": NSImage(named: "VerizonMediaDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Windows": NSImage(named: "WindowsDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "Xaxis": NSImage(named: "XaxisDark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

}
