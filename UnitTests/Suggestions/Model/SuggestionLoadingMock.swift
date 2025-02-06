//
//  SuggestionLoadingMock.swift
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

import XCTest
import Suggestions
@testable import DuckDuckGo_Privacy_Browser

final class SuggestionLoadingMock: SuggestionLoading {

    var getSuggestionsCalled = false
    weak var dataSource: SuggestionLoadingDataSource?
    var completion: ((SuggestionResult?, Error?) -> Void)?

    func getSuggestions(query: Query,
                        usingDataSource dataSource: SuggestionLoadingDataSource,
                        completion: @escaping (SuggestionResult?, Error?) -> Void) {
        getSuggestionsCalled = true
        self.dataSource = dataSource
        self.completion = completion
    }

}
