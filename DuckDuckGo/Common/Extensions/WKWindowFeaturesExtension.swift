//
//  WKWindowFeaturesExtension.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import WebKit

final class WindowFeatures: WKWindowFeatures {

    // TODO: norefferer noopener?
    static let backgroundTab = WindowFeatures(selected: false, menuBar: true, statusBar: true, toolbars: true, resizable: true, noReferrer: true, noOpener: true)
    static let selectedTab = WindowFeatures(selected: true, menuBar: true, statusBar: true, toolbars: true, resizable: true, noReferrer: true, noOpener: true)

    static let window = WindowFeatures(window: true, menuBar: true, statusBar: true, toolbars: true, resizable: true, noReferrer: true, noOpener: true)
    static let popup = WindowFeatures(toolbars: false)

    private let _menuBarVisibility: Bool?
    override var menuBarVisibility: NSNumber? { _menuBarVisibility.map(NSNumber.init) }
    private let _statusBarVisibility: Bool?
    override var statusBarVisibility: NSNumber? { _statusBarVisibility.map(NSNumber.init) }
    private let _toolbarsVisibility: Bool?
    override var toolbarsVisibility: NSNumber? { _toolbarsVisibility.map(NSNumber.init) }
    private let _allowsResizing: Bool?
    override var allowsResizing: NSNumber? { _allowsResizing.map(NSNumber.init) }
    private let _x: CGFloat?
    override var x: NSNumber? { _x.map { NSNumber(value: Double($0)) } }
    private let _y: CGFloat?
    override var y: NSNumber? { _y.map { NSNumber(value: Double($0)) } }
    private let _width: CGFloat?
    override var width: NSNumber? { _width.map { NSNumber(value: Double($0)) } }
    private let _height: CGFloat?
    override var height: NSNumber? { _height.map { NSNumber(value: Double($0)) } }

    let window: Bool?
    let selected: Bool?
    let noReferrer: Bool?
    let noOpener: Bool?

    init(window: Bool? = nil,
         selected: Bool? = nil,
         menuBar: Bool? = nil,
         statusBar: Bool? = nil,
         toolbars: Bool? = nil,
         resizable: Bool? = nil,
         x: CGFloat? = nil,
         y: CGFloat? = nil,
         width: CGFloat? = nil,
         height: CGFloat? = nil,
         noReferrer: Bool? = nil,
         noOpener: Bool? = nil) {

        self.window = window
        self.selected = selected
        self._menuBarVisibility = menuBar
        self._statusBarVisibility = statusBar
        self._toolbarsVisibility = toolbars
        self._allowsResizing = resizable
        self._x = x
        self._y = y
        self._width = width
        self._height = height
        self.noOpener = noOpener
        self.noReferrer = noReferrer
    }

    convenience init(wkWindowFeatures other: WKWindowFeatures,
                     window: Bool? = nil,
                     selected: Bool? = nil) {
        self.init(window: window,
                  selected: selected,
                  statusBar: other.statusBarVisibility?.boolValue,
                  toolbars: other.toolbarsVisibility?.boolValue,
                  resizable: other.allowsResizing?.boolValue,
                  x: other.x.map { CGFloat($0.doubleValue) },
                  y: other.y.map { CGFloat($0.doubleValue) },
                  width: other.width.map { CGFloat($0.doubleValue) },
                  height: other.height.map { CGFloat($0.doubleValue) })
    }

    func encoded() -> String {
        var result = ""
        func append(_ name: String, _ value: String) {
            result += "\(result.isEmpty ? "" : ",")\(name)=\(value)"
        }
        if _menuBarVisibility == true { append("menubar", "1") }
        if _statusBarVisibility == true { append("status", "1") }
        if _toolbarsVisibility == true { append("toolbar", "1") }
        if _allowsResizing == true { append("resizable", "1") }
        if noOpener == true { append("noopener", "1") }
        if noReferrer == true { append("noreferrer", "1") }

        if let x = _x { append("left", "\(x)") }
        if let y = _y { append("top", "\(y)") }
        if let width = _width { append("width", "\(width)") }
        if let height = _height { append("height", "\(height)") }

        return result
    }

}

struct TargetWindowName: RawRepresentable {
    let rawValue: String

    static let blank = TargetWindowName(rawValue: "_blank")
    static let `self` = TargetWindowName(rawValue: "_self")
    static let parent = TargetWindowName(rawValue: "_parent")
    static let top = TargetWindowName(rawValue: "_top")

}
