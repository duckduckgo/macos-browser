//
//  NSColorExtension.swift
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

import Cocoa

extension NSColor {
    
    static var addressBarFocusedBackgroundColor: NSColor {
        NSColor(named: "AddressBarFocusedBackgroundColor")!
    }
    
    static var addressBarBackgroundColor: NSColor {
        NSColor(named: "AddressBarBackgroundColor")!
    }
    
    static var addressBarSuffixColor: NSColor {
        NSColor(named: "AddressBarSuffixColor")!
    }
    
    static var findInPageFocusedBackgroundColor: NSColor {
        NSColor(named: "FindInPageFocusedBackgroundColor")!
    }
    
    static var suggestionTextColor: NSColor {
        NSColor(named: "SuggestionTextColor")!
    }
    
    static var suggestionIconColor: NSColor {
        NSColor(named: "SuggestionIconColor")!
    }
    
    static var selectedSuggestionTintColor: NSColor {
        NSColor(named: "SelectedSuggestionTintColor")!
    }
    
    static var selectedSuggestionBackgroundColor: NSColor {
        NSColor(named: "SelectedSuggestionBackgroundColor")!
    }
    
    static var interfaceBackgroundColor: NSColor {
        NSColor(named: "InterfaceBackgroundColor")!
    }
    
    static var tabMouseOverColor: NSColor {
        NSColor(named: "TabMouseOverColor")!
    }
}
