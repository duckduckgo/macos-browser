//
//  DataBrokerProtectionDataBase.swift
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

import Foundation

protocol DataBase {
    func brokerProfileQueryData(for profileQuery: ProfileQuery, dataBroker: DataBroker) -> BrokerProfileQueryData?
    func saveOperationData(_ data: BrokerOperationData)
    func scanOperationData(for profileQueryID: UUID) -> ScanOperationData
    func optOutOperationData(for profileQueryID: UUID) -> [OptOutOperationData]
    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData]
    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData?
}

final class DataBrokerProtectionDataBase: DataBase {
    // Data in memory for tests
    public var dataBrokers = [DataBroker]()
    public var brokerProfileQueriesData = [BrokerProfileQueryData]()
    public var testProfileQuery: ProfileQuery?

    func brokerProfileQueryData(for profileQuery: ProfileQuery, dataBroker: DataBroker) -> BrokerProfileQueryData? {
        brokerProfileQueriesData.filter {
            $0.profileQuery.fullName == profileQuery.fullName
            && dataBroker.id == $0.dataBroker.id
        }.first
    }

    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData? {
        brokerProfileQueriesData.filter { $0.id == id }.first
    }

    func saveOperationData(_ data: BrokerOperationData) {

    }

    func scanOperationData(for profileQueryID: UUID) -> ScanOperationData {

        return ScanOperationData(brokerProfileQueryID: profileQueryID,
                                 preferredRunDate: Date(),
                                 historyEvents: [HistoryEvent]())
    }

    func optOutOperationData(for profileQueryID: UUID) -> [OptOutOperationData] {
        let extractedProfile = ExtractedProfile(name: "Duck")
        let data = OptOutOperationData(brokerProfileQueryID: profileQueryID,
                                       preferredRunDate: Date(),
                                       historyEvents: [HistoryEvent](),
                                       extractedProfile: extractedProfile)
        return [data]
    }

    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData] {
        return brokerProfileQueriesData
    }

    func setupFakeData() {
        self.dataBrokers.removeAll()
        self.brokerProfileQueriesData.removeAll()

        let dataBroker = TestData().dataBroker
        let profileQuery = testProfileQuery!
        let queryData = BrokerProfileQueryData(id: UUID(), profileQuery: profileQuery, dataBroker: dataBroker)

        self.dataBrokers.append(dataBroker)
        self.brokerProfileQueriesData.append(queryData)
    }
}

private struct TestData {

    let verecorJSONString = """
               {
                 "name": "verecor",
               "schedulingConfig" : {
                    "retryError": 700,
                    "confirmOptOutScan": 480,
                    "maintenanceScan": 600,
                    "emailConfirmation": 60,
               },
                 "steps": [
                   {
                     "stepType": "scan",
                     "actions": [
                       {
                         "id": "fe235f94-1c33-11ee-be56-0242ac120002",
                         "actionType": "navigate",
                         "url": "https://verecor.com/profile/search?fname=${firstName}&lname=${lastName}&state=${state}&city=${city}&fage=${ageRange}",
                         "ageRange": [
                           "18-30",
                           "31-40",
                           "41-50",
                           "51-60",
                           "61-70",
                           "71-80",
                           "81+"
                         ]
                       },
                       {
                         "id": "fe236548-1c33-11ee-be56-0242ac120002",
                         "actionType": "extract",
                         "selector": ".search-item",
                         "profile": {
                           "name": "//div[@class='col-sm-24 col-md-19 col-text']",
                           "alternativeNamesList": ".name",
                           "age": ".age",
                           "addressCityStateList": ".location",
                           "profileUrl": "a"
                         }
                       }
                     ]
                   },
                   {
                     "stepType": "optOut",
                     "actions": [
                       {
                         "id": "fe23669c-1c33-11ee-be56-0242ac120002",
                         "actionType": "navigate",
                         "url": "https://verecor.com/ng/control/privacy"
                       },
                       {
                         "id": "fe2367be-1c33-11ee-be56-0242ac120002",
                         "actionType": "fillForm",
                         "selector": ".ahm",
                         "elements": [
                           {
                             "type": "name",
                             "selector": "#user_name"
                           },
                           {
                             "type": "email",
                             "selector": "#user_email"
                           },
                           {
                             "type": "profileUrl",
                             "selector": "#url"
                           }
                         ]
                       },
                       {
                         "id": "fe2369f8-1c33-11ee-be56-0242ac120002",
                         "actionType": "getCaptchaInfo",
                         "selector": ".g-recaptcha"
                       },
                       {
                         "id": "fe2368e0-1c33-11ee-be56-0242ac120002",
                         "actionType": "solveCaptcha",
                         "selector": ".g-recaptcha"
                       },
                       {
                         "id": "fe236b10-1c33-11ee-be56-0242ac120002",
                         "actionType": "click",
                         "elements": [
                           {
                             "type": "button",
                             "selector": ".btn-sbmt"
                           }
                         ]
                       },
                       {
                         "id": "fe236c32-1c33-11ee-be56-0242ac120002",
                         "actionType": "expectation",
                         "expectations": [
                           {
                             "type": "text",
                             "selector": "body",
                             "expect": "Your removal request has been received"
                           }
                         ]
                       },
                       {
                         "id": "fe236d4a-1c33-11ee-be56-0242ac120002",
                         "actionType": "emailConfirmation",
                         "pollingTime": 30
                       },
                       {
                         "id": "fe2371be-1c33-11ee-be56-0242ac120002",
                         "actionType": "expectation",
                         "expectations": [
                           {
                             "type": "text",
                             "selector": "body",
                             "expect": "Your information control request has been confirmed."
                           }
                         ]
                       }
                     ]
                   }
                 ]
               }
               """

    var dataBroker: DataBroker {
        // swiftlint:disable:next force_try
        try! JSONDecoder().decode(DataBroker.self, from: verecorJSONString.data(using: .utf8)!)
    }
}
