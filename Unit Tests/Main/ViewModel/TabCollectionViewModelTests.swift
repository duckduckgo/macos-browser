//
//  TabCollectionViewModelTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser

class TabCollectionViewModelTests: XCTestCase {

    func testWhenSelectionIndexIsNilThenSelectedTabViewModelIsNil() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)
    }
    
    func testWhenSelectionIndexIsOutOfBoundsThenSelectedTabViewModelIsNil() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        
        tabCollectionViewModel.selectionIndex = 1
        
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)
    }
    
    func testWhenSelectionIndexPointsToTabThenSelectedTabViewModelReturnsTheTab() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        let tab1 = Tab()
        tabCollection.prepend(tab: tab1)
        
        let tab2 = Tab()
        tabCollection.prepend(tab: tab2)
        
        let selectionIndex = 1
        tabCollectionViewModel.selectionIndex = selectionIndex
        
        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab, tab1)
    }
    
    func testWhenTabViewModelIndexIsOutOfBoundsThenTabViewModelReturnsNil() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        let tab = Tab()
        tabCollection.prepend(tab: tab)
        
        XCTAssertNil(tabCollectionViewModel.tabViewModel(at: 1))
    }
    
    func testWhenTabViewModelIsCalledWithSameIndexThenTheResultHasSameIdentity() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        let tab = Tab()
        tabCollection.prepend(tab: tab)
        
        XCTAssert(tabCollectionViewModel.tabViewModel(at: 0) === tabCollectionViewModel.tabViewModel(at: 0))
        XCTAssertEqual(tabCollectionViewModel.tabViewModel(at: 0)?.tab, tab)
    }

}
