//
//  DraggingInfoMock.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser

final class DraggingInfoMock: NSObject, NSDraggingInfo {
    private let pasteboard: NSPasteboard

    var animatesToDestination: Bool = false
    var numberOfValidItemsForDrop: Int = 0
    var draggingFormation: NSDraggingFormation = .none
    var springLoadingHighlight: NSSpringLoadingHighlight = .none

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
        super.init()
    }

    var draggingLocation: NSPoint {
        return NSPoint(x: 50, y: 50)
    }

    var draggingPasteboard: NSPasteboard {
        return pasteboard
    }

    var draggingSequenceNumber: Int {
        return 0
    }

    var draggingSource: Any? {
        return nil
    }

    var draggingSourceOperationMask: NSDragOperation {
        return .every
    }

    var draggingDestinationWindow: NSWindow? {
        return nil
    }

    var draggedImage: NSImage? {
        return nil
    }

    var draggedImageLocation: NSPoint {
        return .zero
    }

    func slideDraggedImage(to aPoint: NSPoint) {}

    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}

    func resetSpringLoading() {}
}

extension DraggingInfoMock {

    static func with(bookmarkEntity: BaseBookmarkEntity, pasteboardName: StaticString = #function) -> DraggingInfoMock {
        DraggingInfoMock(pasteboard: NSPasteboard.with(bookmarkEntity: bookmarkEntity, name: pasteboardName))
    }

}

extension NSPasteboard {

    static func with(bookmarkEntity: BaseBookmarkEntity, name: StaticString = #function) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(String(name)))
        pasteboard.clearContents()
        pasteboard.writeObjects([bookmarkEntity.pasteboardWriter])
        return pasteboard
    }

}
