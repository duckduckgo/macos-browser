//
//  NEOnDemandRuleExtension.swift
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

import NetworkExtension

extension NEOnDemandRule {

    convenience init(dnsSearchDomain: [String]? = nil,
                     dnsServerAddress: [String]? = nil,
                     interfaceType: NEOnDemandRuleInterfaceType? = nil,
                     ssid: [String]? = nil,
                     probeURL: URL? = nil) {
        self.init()

        if let dnsSearchDomain {
            self.dnsSearchDomainMatch = dnsSearchDomain
        }
        if let dnsServerAddress {
            self.dnsServerAddressMatch = dnsServerAddress
        }
        if let interfaceType {
            self.interfaceTypeMatch = interfaceType
        }
        if let ssid {
            self.ssidMatch = ssid
        }
        if let probeURL {
            self.probeURL = probeURL
        }
    }

}
