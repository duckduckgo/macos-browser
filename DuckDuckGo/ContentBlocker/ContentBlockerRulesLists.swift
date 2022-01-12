//
//  ContentBlockerRulesLists.swift
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
import TrackerRadarKit
import BrowserServicesKit
import CryptoKit

final class ContentBlockerRulesLists: DefaultContentBlockerRulesListsSource {
    
    enum Constants {
        static let clickToLoadRulesListName = "ClickToLoad"
    }
    
    static var fbTrackerDataFile: Data = {
        let url = Bundle.main.url(forResource: "fb-tds", withExtension: "json")!
        return (try? Data(contentsOf: url)) ?? Data()
    }()

    static var fbTrackerDataSet: TrackerRadarKit.TrackerData = {
        let trackerData = (try? JSONDecoder().decode(TrackerData.self, from: fbTrackerDataFile)) ?? nil
        return trackerData!
    }()
    
    func MD5(data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)

        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }    
    
    override var contentBlockerRulesLists: [ContentBlockerRulesList] {
        var result = super.contentBlockerRulesLists
        
        // Add new ones
        let etag = MD5(data: Self.fbTrackerDataFile)
        let dataSet: TrackerDataManager.DataSet = TrackerDataManager.DataSet(Self.fbTrackerDataSet, etag)
        let additionalRulesList = ContentBlockerRulesList(name: Constants.clickToLoadRulesListName,
                                                          trackerData: nil,
                                                          fallbackTrackerData: dataSet)

        result.append(additionalRulesList)
        return result
    }
}
