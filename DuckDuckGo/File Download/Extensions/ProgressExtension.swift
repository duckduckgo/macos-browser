//
//  ProgressExtension.swift
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

extension Progress {

    convenience init(
        totalUnitCount: Int64,
        fileOperationKind: FileOperationKind,
        kind: ProgressKind,
        isPausable: Bool,
        isCancellable: Bool,
        fileURL: URL) {
        self.init(totalUnitCount: totalUnitCount)

        self.fileOperationKind = fileOperationKind
        self.kind = kind
        self.isPausable = isPausable
        self.isCancellable = isCancellable
        self.fileURL = fileURL
    }

    var fileDownloadingSourceURL: URL? {
        get {
            userInfo[.fileDownloadingSourceURLKey] as? URL
        }
        set {
            setUserInfoObject(newValue, forKey: .fileDownloadingSourceURLKey)
        }
    }

    var fileURL: URL? {
        get {
            userInfo[.fileURLKey] as? URL
        }
        set {
            if newValue != self.fileURL {
                setUserInfoObject(newValue, forKey: .fileURLKey)
            }
        }
    }

    var flyToImage: NSImage? {
        get {
            userInfo[.flyToImageKey] as? NSImage
        }
        set {
            setUserInfoObject(newValue, forKey: .flyToImageKey)
        }
    }

    var fileIconOriginalRect: NSRect? {
        get {
            (userInfo[.fileIconOriginalRectKey] as? NSValue)?.rectValue
        }
        set {
            setUserInfoObject(newValue.map(NSValue.init(rect:)), forKey: .fileIconOriginalRectKey)
        }
    }

    var isPublished: Bool {
        get {
            userInfo[.isPublishedKey] as? Bool ?? false
        }
        set {
            setUserInfoObject(newValue, forKey: .isPublishedKey)
        }
    }

    var isUnpublished: Bool {
        get {
            userInfo[.isUnpublishedKey] as? Bool ?? false
        }
        set {
            setUserInfoObject(newValue, forKey: .isUnpublishedKey)
        }
    }

    func publishIfNotPublished() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isPublished else { return }
        isPublished = true

        publish()
    }

    func unpublishIfNeeded() {
        guard
            isPublished,
            !isUnpublished
        else { return }
        isUnpublished = true

        unpublish()
    }

}

extension ProgressUserInfoKey {
    static let fileDownloadingSourceURLKey = ProgressUserInfoKey(rawValue: "NSProgressFileDownloadingSourceURL")
    static let fileLocationCanChangeKey = ProgressUserInfoKey(rawValue: "NSProgressFileLocationCanChangeKey")
    static let flyToImageKey = ProgressUserInfoKey(rawValue: "NSProgressFlyToImageKey")
    static let fileIconOriginalRectKey = ProgressUserInfoKey(rawValue: "NSProgressFileAnimationImageOriginalRectKey")

    fileprivate static let isPublishedKey = ProgressUserInfoKey(rawValue: "isPublishedKey")
    fileprivate static let isUnpublishedKey = ProgressUserInfoKey(rawValue: "isUnpublishedKey")
}
