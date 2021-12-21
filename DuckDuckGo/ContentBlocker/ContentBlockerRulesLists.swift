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

final class ContentBlockerRulesLists: DefaultContentBlockerRulesListsSource {
    static var FBTrackers: URL {
        return Bundle.main.url(forResource: "fb-tds", withExtension: "json")!
    }
    
    override var contentBlockerRulesLists: [ContentBlockerRulesList] {
        var result = super.contentBlockerRulesLists
        
        // Add new ones
        do {
            let dataFile = (try? Data(contentsOf: Self.FBTrackers)) ?? Data()
            let trackerData = try JSONDecoder().decode(TrackerData.self, from: dataFile)
            // TODO generate real etag here for above list?
            let dataSet: TrackerDataManager.DataSet = TrackerDataManager.DataSet(trackerData, "etag-fb")
            let additionalRulesList = ContentBlockerRulesList(name: "fb", trackerData: nil, fallbackTrackerData: dataSet)
    
            result.append(additionalRulesList)
                    
        } catch {
            print(error)
        }
        return result
    }
}
