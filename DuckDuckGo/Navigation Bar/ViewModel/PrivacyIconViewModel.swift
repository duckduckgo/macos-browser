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

    static var shadowTrackerImage: CGImage {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return shadowTrackerImageAqua
        } else {
            return shadowTrackerImageDark
        }
    }

    static let shadowTrackerImageAqua = NSImage(named: "shadowtracker")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
    static let shadowTrackerImageDark = NSImage(named: "shadowtracker_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!

    static var blankTrackerImage: CGImage {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return blankTrackerImageAqua
        } else {
            return blankTrackerImageDark
        }
    }

    static let blankTrackerImageAqua = NSImage(named: "blanktracker")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
    static let blankTrackerImageDark = NSImage(named: "blanktracker_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!

    static var letters: [Character: CGImage] {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return lettersAqua
        } else {
            return lettersDark
        }
    }

    static let lettersAqua: [Character: CGImage] = {
        return [
            "a": NSImage(named: "a")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "b": NSImage(named: "b")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "c": NSImage(named: "c")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "d": NSImage(named: "d")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "e": NSImage(named: "e")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "f": NSImage(named: "f")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "g": NSImage(named: "g")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "h": NSImage(named: "h")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "i": NSImage(named: "i")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "j": NSImage(named: "j")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "k": NSImage(named: "k")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "l": NSImage(named: "l")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "m": NSImage(named: "m")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "n": NSImage(named: "n")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "o": NSImage(named: "o")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "p": NSImage(named: "p")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "q": NSImage(named: "q")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "r": NSImage(named: "r")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "s": NSImage(named: "s")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "t": NSImage(named: "t")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "u": NSImage(named: "u")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "v": NSImage(named: "v")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "w": NSImage(named: "w")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "x": NSImage(named: "x")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "y": NSImage(named: "y")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "z": NSImage(named: "z")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

    static let lettersDark: [Character: CGImage] = {
        return [
            "a": NSImage(named: "a_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "b": NSImage(named: "b_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "c": NSImage(named: "c_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "d": NSImage(named: "d_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "e": NSImage(named: "e_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "f": NSImage(named: "f_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "g": NSImage(named: "g_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "h": NSImage(named: "h_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "i": NSImage(named: "i_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "j": NSImage(named: "j_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "k": NSImage(named: "k_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "l": NSImage(named: "l_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "m": NSImage(named: "m_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "n": NSImage(named: "n_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "o": NSImage(named: "o_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "p": NSImage(named: "p_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "q": NSImage(named: "q_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "r": NSImage(named: "r_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "s": NSImage(named: "s_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "t": NSImage(named: "t_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "u": NSImage(named: "u_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "v": NSImage(named: "v_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "w": NSImage(named: "w_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "x": NSImage(named: "x_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "y": NSImage(named: "y_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "z": NSImage(named: "z_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

    static var logos: [String: CGImage] {
        if NSApp.effectiveAppearance.name == NSAppearance.Name.aqua {
            return logosAqua
        } else {
            return logosDark
        }
    }

    static let logosAqua: [String: CGImage] = {
        return [
            "adform": NSImage(named: "adform")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "adobe": NSImage(named: "adobe")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "amazon": NSImage(named: "amazon")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "amobee": NSImage(named: "amobee")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "appnexus": NSImage(named: "appnexus")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "centro": NSImage(named: "centro")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "cloudflare": NSImage(named: "cloudflare")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "comscore": NSImage(named: "comscore")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "conversant": NSImage(named: "conversant")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "criteo": NSImage(named: "criteo")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "dataxu": NSImage(named: "dataxu")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "facebook": NSImage(named: "facebook")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "google": NSImage(named: "google")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "hotjar": NSImage(named: "hotjar")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "indexexchange": NSImage(named: "indexexchange")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "iponweb": NSImage(named: "iponweb")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "linkedin": NSImage(named: "linkedin")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "lotame": NSImage(named: "lotame")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "mediamath": NSImage(named: "mediamath")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "microsoft": NSImage(named: "microsoft")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "neustar": NSImage(named: "neustar")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "newrelic": NSImage(named: "newrelic")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "nielsen": NSImage(named: "nielsen")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "openx": NSImage(named: "openx")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "oracle": NSImage(named: "oracle")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "pubmatic": NSImage(named: "pubmatic")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "qwantcast": NSImage(named: "qwantcast")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "rubicon": NSImage(named: "rubicon")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "salesforce": NSImage(named: "salesforce")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "smartadserver": NSImage(named: "smartadserver")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "spotx": NSImage(named: "spotx")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "stackpath": NSImage(named: "stackpath")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "taboola": NSImage(named: "taboola")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "tapad": NSImage(named: "tapad")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "the trade desk": NSImage(named: "thetradedesk")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "towerdata": NSImage(named: "towerdata")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "twitter": NSImage(named: "twitter")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "verizon media": NSImage(named: "verizonmedia")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "windows": NSImage(named: "windows")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "xaxis": NSImage(named: "xaxis")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

    static let logosDark: [String: CGImage] = {
        return [
            "adform": NSImage(named: "adform_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "adobe": NSImage(named: "adobe_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "amazon": NSImage(named: "amazon_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "amobee": NSImage(named: "amobee_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "appnexus": NSImage(named: "appnexus_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "centro": NSImage(named: "centro_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "cloudflare": NSImage(named: "cloudflare_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "comscore": NSImage(named: "comscore_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "conversant": NSImage(named: "conversant_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "criteo": NSImage(named: "criteo_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "dataxu": NSImage(named: "dataxu_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "facebook": NSImage(named: "facebook_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "google": NSImage(named: "google_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "hotjar": NSImage(named: "hotjar_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "indexexchange": NSImage(named: "indexexchange_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "lponweb": NSImage(named: "iponweb_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "linkedin": NSImage(named: "linkedin_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "lotame": NSImage(named: "lotame_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "mediamath": NSImage(named: "mediamath_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "microsoft": NSImage(named: "microsoft_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "neustar": NSImage(named: "neustar_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "newrelic": NSImage(named: "newrelic_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "nielsen": NSImage(named: "nielsen_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "openx": NSImage(named: "openx_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "oracle": NSImage(named: "oracle_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "pubmatic": NSImage(named: "pubmatic_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "qwantcast": NSImage(named: "qwantcast_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "rubicon": NSImage(named: "rubicon_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "salesforce": NSImage(named: "salesforce_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "smartadserver": NSImage(named: "smartadserver_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "spotx": NSImage(named: "spotx_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "stackpath": NSImage(named: "stackpath_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "taboola": NSImage(named: "taboola_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "tapad": NSImage(named: "tapad_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "the trade desk": NSImage(named: "thetradedesk_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "towerdata": NSImage(named: "towerdata_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "twitter": NSImage(named: "twitter_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "verizon media": NSImage(named: "verizonmedia_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "windows": NSImage(named: "windows_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!,
            "xaxis": NSImage(named: "xaxis_dark")!.cgImage(forProposedRect: nil, context: .current, hints: nil)!
        ]
    }()

}
