//
//  NibLoadable.swift
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

protocol NibLoadable {

    static var nibName: String { get }
    static func createFromNib(in bundle: Bundle) -> Self

}

extension NibLoadable where Self: NSView {

    static var nibName: String {
        return String(describing: Self.self)
    }

    static func createFromNib(in bundle: Bundle = Bundle.main) -> Self {
        var objects: NSArray!
        bundle.loadNibNamed(NSNib.Name(nibName), owner: self, topLevelObjects: &objects)
        guard objects != nil else {
            fatalError("NibLoadable: Could not load nib")
        }
        let views = objects.filter { $0 is Self }

        // swiftlint:disable force_cast
        return views.last as! Self
        // swiftlint:enable force_cast
    }
}
