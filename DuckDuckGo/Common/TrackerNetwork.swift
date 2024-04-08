//
//  TrackerNetwork.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

enum TrackerNetwork: String, CaseIterable {

    case adform = "adform"
    case adobe = "adobe"
    case amazon = "amazon"
    case amobee = "amobee"
    case appnexus = "appnexus"
    case centro = "centro"
    case cloudflare = "cloudflare"
    case comscore = "comscore"
    case conversant = "conversant"
    case criteo = "criteo"
    case dataxu = "dataxu"
    case facebook = "facebook"
    case google = "google"
    case hotjar = "hotjar"
    case indexexchange = "indexexchange"
    case iponweb = "iponweb"
    case linkedin = "linkedin"
    case lotame = "lotame"
    case mediamath = "mediamath"
    case microsoft = "microsoft"
    case neustar = "neustar"
    case newrelic = "newrelic"
    case nielsen = "nielsen"
    case openx = "openx"
    case oracle = "oracle"
    case pubmatic = "pubmatic"
    case qwantcast = "qwantcast"
    case rubicon = "rubicon"
    case salesforce = "salesforce"
    case smartadserver = "smartadserver"
    case spotx = "spotx"
    case stackpath = "stackpath"
    case taboola = "taboola"
    case tapad = "tapad"
    case theTradeDesk = "the trade desk"
    case towerdata = "towerdata"
    case twitter = "twitter"
    case verizonMedia = "verizon media"
    case windows = "windows"
    case xaxis = "xaxis"

}

extension TrackerNetwork {

    init?(trackerNetworkName name: String) {
        if let some = TrackerNetwork(rawValue: name) {
            self = some
            return
        }
        switch name {
        case "quancast": self = .qwantcast
        case "lotamesolutions": self = .lotame
        case "thenielsencompany": self = .nielsen
        default: return nil
        }
    }

}
