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

    convenience init(totalUnitCount: Int64,
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
            self.userInfo[.fileDownloadingSourceURLKey] as? URL
        }
        set {
            self.setUserInfoObject(newValue, forKey: .fileDownloadingSourceURLKey)
        }
    }

    var fileURL: URL? {
        get {
            self.userInfo[.fileURLKey] as? URL
        }
        set {
            if newValue != self.fileURL {
                self.setUserInfoObject(newValue, forKey: .fileURLKey)
            }
        }
    }

    var flyToImage: NSImage? {
        get {
            self.userInfo[.flyToImageKey] as? NSImage
        }
        set {
            self.setUserInfoObject(newValue, forKey: .flyToImageKey)
        }
    }

    var fileIconOriginalRect: NSRect? {
        get {
            (self.userInfo[.fileIconOriginalRectKey] as? NSValue)?.rectValue
        }
        set {
            self.setUserInfoObject(newValue.map(NSValue.init(rect:)), forKey: .fileIconOriginalRectKey)
        }
    }

    var isPublished: Bool {
        get {
            self.userInfo[.isPublishedKey] as? Bool ?? false
        }
        set {
            self.setUserInfoObject(newValue, forKey: .isPublishedKey)
        }
    }

    var isUnpublished: Bool {
        get {
            self.userInfo[.isUnpublishedKey] as? Bool ?? false
        }
        set {
            self.setUserInfoObject(newValue, forKey: .isUnpublishedKey)
        }
    }

    func publishIfNotPublished() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !self.isPublished else { return }
        self.isPublished = true

        self.publish()
    }

    func unpublishIfNeeded() {
        guard self.isPublished,
              !self.isUnpublished
        else { return }
        self.isUnpublished = true

        self.unpublish()
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
