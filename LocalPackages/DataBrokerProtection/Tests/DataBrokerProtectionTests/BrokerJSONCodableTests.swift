//
//  BrokerJSONCodableTests.swift
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

import XCTest
@testable import DataBrokerProtection

final class BrokerJSONCodableTests: XCTestCase {
    let verecorWithURLJSONString = """
               {
                 "name": "Verecor",
                 "url": "verecor.com",
                 "version": "0.1.0",
                 "addedDatetime": 1677128400000,
                 "mirrorSites": [
                   {
                     "name": "Potato",
                     "url": "potato.com",
                     "addedAt": 1705599286529,
                     "removedAt": null
                   },
                   {
                     "name": "Tomato",
                     "url": "tomato.com",
                     "addedAt": 1705599286529,
                     "removedAt": null
                   }
                 ],
                 "steps": [
                   {
                     "stepType": "scan",
                     "scanType": "templatedUrl",
                     "actions": [
                       {
                         "actionType": "navigate",
                         "id": "84aa05bc-1ca0-4f16-ae74-dfb352ce0eee",
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
                         "actionType": "extract",
                         "id": "92252eb5-ccaf-4b00-a3fe-019110ce0534",
                         "selector": ".search-item",
                         "profile": {
                           "name": {
                             "selector": "h4"
                           },
                           "alternativeNamesList": {
                             "selector": ".//div[@class='col-sm-24 col-md-16 name']//li",
                             "findElements": true
                           },
                           "age": {
                             "selector": ".age"
                           },
                           "addressCityStateList": {
                             "selector": ".//div[@class='col-sm-24 col-md-8 location']//li",
                             "findElements": true
                           },
                           "profileUrl": {
                             "selector": ".link-to-details",
                             "identifierType": "path",
                             "identifier": "https://www.advancedbackgroundchecks.com/${id}"
                           }
                         }
                       }
                     ]
                   },
                   {
                     "stepType": "optOut",
                     "optOutType": "formOptOut",
                     "actions": [
                       {
                         "actionType": "navigate",
                         "id": "49f9aa73-4f97-47c0-b8bf-1729e9c169c0",
                         "url": "https://verecor.com/ng/control/privacy"
                       },
                       {
                         "actionType": "fillForm",
                         "id": "55b1d0bb-d303-4b6f-bf9e-3fd96746f27e",
                         "selector": ".ahm",
                         "elements": [
                           {
                             "type": "fullName",
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
                         "actionType": "getCaptchaInfo",
                         "id": "9efb1153-8f52-41e4-a8fb-3077a97a586d",
                         "selector": ".g-recaptcha"
                       },
                       {
                         "actionType": "solveCaptcha",
                         "id": "ed49e4c3-0cfa-4f1e-b3d1-06ad7b8b9ba4",
                         "selector": ".g-recaptcha"
                       },
                       {
                         "actionType": "click",
                         "id": "6b986aa4-3d1b-44d5-8b2b-5463ee8916c9",
                         "elements": [
                           {
                             "type": "button",
                             "selector": ".btn-sbmt"
                           }
                         ]
                       },
                       {
                         "actionType": "expectation",
                         "id": "d4c64d9b-1004-487e-ab06-ae74869bc9a7",
                         "expectations": [
                           {
                             "type": "text",
                             "selector": "body",
                             "expect": "Your removal request has been received"
                           }
                         ]
                       },
                       {
                         "actionType": "emailConfirmation",
                         "id": "3b4c611a-61ab-4792-810e-d5b3633ea203",
                         "pollingTime": 30
                       },
                       {
                         "actionType": "expectation",
                         "id": "afe805a0-d422-473c-b47f-995a8672d476",
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
                 ],
                 "schedulingConfig": {
                   "retryError": 48,
                   "confirmOptOutScan": 72,
                   "maintenanceScan": 120,
                   "maxAttempts": -1
                 }
               }

               """
    let verecorNoURLJSONString = """
               {
                 "name": "verecor.com",
                 "version": "0.1.0",
                 "addedDatetime": 1677128400000,
                 "mirrorSites": [
                   {
                     "name": "tomato.com",
                     "addedAt": 1705599286529,
                     "removedAt": null
                   },
                   {
                     "name": "potato.com",
                     "addedAt": 1705599286529,
                     "removedAt": null
                   }
                 ],
                 "steps": [
                   {
                     "stepType": "scan",
                     "scanType": "templatedUrl",
                     "actions": [
                       {
                         "actionType": "navigate",
                         "id": "84aa05bc-1ca0-4f16-ae74-dfb352ce0eee",
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
                         "actionType": "extract",
                         "id": "92252eb5-ccaf-4b00-a3fe-019110ce0534",
                         "selector": ".search-item",
                         "profile": {
                           "name": {
                             "selector": "h4"
                           },
                           "alternativeNamesList": {
                             "selector": ".//div[@class='col-sm-24 col-md-16 name']//li",
                             "findElements": true
                           },
                           "age": {
                             "selector": ".age"
                           },
                           "addressCityStateList": {
                             "selector": ".//div[@class='col-sm-24 col-md-8 location']//li",
                             "findElements": true
                           },
                           "profileUrl": {
                             "selector": "a"
                           }
                         }
                       }
                     ]
                   },
                   {
                     "stepType": "optOut",
                     "optOutType": "formOptOut",
                     "actions": [
                       {
                         "actionType": "navigate",
                         "id": "49f9aa73-4f97-47c0-b8bf-1729e9c169c0",
                         "url": "https://verecor.com/ng/control/privacy"
                       },
                       {
                         "actionType": "fillForm",
                         "id": "55b1d0bb-d303-4b6f-bf9e-3fd96746f27e",
                         "selector": ".ahm",
                         "elements": [
                           {
                             "type": "fullName",
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
                         "actionType": "getCaptchaInfo",
                         "id": "9efb1153-8f52-41e4-a8fb-3077a97a586d",
                         "selector": ".g-recaptcha"
                       },
                       {
                         "actionType": "solveCaptcha",
                         "id": "ed49e4c3-0cfa-4f1e-b3d1-06ad7b8b9ba4",
                         "selector": ".g-recaptcha"
                       },
                       {
                         "actionType": "click",
                         "id": "6b986aa4-3d1b-44d5-8b2b-5463ee8916c9",
                         "elements": [
                           {
                             "type": "button",
                             "selector": ".btn-sbmt"
                           }
                         ]
                       },
                       {
                         "actionType": "expectation",
                         "id": "d4c64d9b-1004-487e-ab06-ae74869bc9a7",
                         "expectations": [
                           {
                             "type": "text",
                             "selector": "body",
                             "expect": "Your removal request has been received"
                           }
                         ]
                       },
                       {
                         "actionType": "emailConfirmation",
                         "id": "3b4c611a-61ab-4792-810e-d5b3633ea203",
                         "pollingTime": 30
                       },
                       {
                         "actionType": "expectation",
                         "id": "afe805a0-d422-473c-b47f-995a8672d476",
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
                 ],
                 "schedulingConfig": {
                   "retryError": 48,
                   "confirmOptOutScan": 72,
                   "maintenanceScan": 120,
                   "maxAttempts": -1
                 }
               }

               """

    func testVerecorJSONNoURL_isCorrectlyParsed() {
        do {
            let broker = try JSONDecoder().decode(DataBroker.self, from: verecorNoURLJSONString.data(using: .utf8)!)
            XCTAssertEqual(broker.url, broker.name)
            for mirror in broker.mirrorSites {
                XCTAssertEqual(mirror.url, mirror.name)
            }
        } catch {
            XCTFail("JSON string should be parsed correctly.")
        }
    }

    func testVerecorJSONWithURL_isCorrectlyParsed() {
        do {
            let broker = try JSONDecoder().decode(DataBroker.self, from: verecorWithURLJSONString.data(using: .utf8)!)
            XCTAssertEqual(broker.url, "verecor.com")
            XCTAssertEqual(broker.name, "Verecor")

            for mirror in broker.mirrorSites {
                XCTAssertNotEqual(mirror.url, mirror.name)
            }
        } catch {
            XCTFail("JSON string should be parsed correctly.")
        }
    }

    func testVerecorJSONProfileURLSelector_isCorrectlyParsed() {
        do {
            let broker = try JSONDecoder().decode(DataBroker.self, from: verecorWithURLJSONString.data(using: .utf8)!)
            let scanStep = try broker.scanStep()
            let extractAction = scanStep.actions.first(where: { $0.actionType == .extract })! as! ExtractAction
            XCTAssertEqual(extractAction.profile.profileUrl?.identifierType, "path")
            XCTAssertEqual(extractAction.profile.profileUrl?.identifier, "https://www.advancedbackgroundchecks.com/${id}")
        } catch {
            XCTFail("JSON string should be parsed correctly.")
        }
    }

    func testParentSelector_isCorrectlyParsed() {
        let json  = """
            {
              "name": "BeenVerified",
              "url": "beenverified.com",
              "version": "0.1.4",
              "addedDatetime": 1677110400000,
              "steps": [
                {
                  "stepType": "optOut",
                  "optOutType": "formOptOut",
                  "actions": [
                    {
                      "actionType": "navigate",
                      "id": "f64d27f1-abf8-4469-a8b1-6ee8d03c107b",
                      "url": "https://www.beenverified.com/app/search/person?age=${age}&city=${city}&fname=${firstName}&ln=${lastName}&mn=${middleName}&optout=true&state=${state}"
                    },
                    {
                      "actionType": "click",
                      "id": "51d52217-de3b-4a6b-a055-13af9b613034",
                      "elements": [
                        {
                          "type": "button",
                          "selector": ".",
                          "parent": {
                            "profileMatch": {
                              "selector": ".person-search-result-card",
                              "profile": {
                                "name": {
                                  "selector": ".person-name",
                                  "beforeText": ", "
                                },
                                "alternativeNamesList": {
                                  "selector": ".person-aliases",
                                  "findElements": true
                                },
                                "age": {
                                  "selector": ".person-name",
                                  "afterText": ", "
                                },
                                "addressCityState": {
                                  "selector": ".person-city"
                                },
                                "addressCityStateList": {
                                  "selector": ".person-locations"
                                },
                                "relativesList": {
                                  "selector": ".person-relatives"
                                }
                              }
                            }
                          }
                        }
                      ]
                    }
                  ]
                }
              ],
              "schedulingConfig": {
                "retryError": 48,
                "confirmOptOutScan": 72,
                "maintenanceScan": 120,
                "maxAttempts": -1
              }
            }
            """
        do {
            _ = try JSONDecoder().decode(DataBroker.self, from: json.data(using: .utf8)!)
        } catch {
            XCTFail("JSON string should be parsed correctly.")
        }
    }
}
