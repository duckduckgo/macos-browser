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
                     completedUnitCount: Int64 = 0,
                     fileOperationKind: FileOperationKind? = nil,
                     kind: ProgressKind? = nil,
                     isPausable: Bool = false,
                     isCancellable: Bool = false,
                     fileURL: URL? = nil,
                     sourceURL: URL? = nil) {
        self.init(totalUnitCount: totalUnitCount)

        self.completedUnitCount = completedUnitCount
        self.fileOperationKind = fileOperationKind
        self.kind = kind
        self.isPausable = isPausable
        self.isCancellable = isCancellable
        self.fileURL = fileURL
        self.fileDownloadingSourceURL = sourceURL
    }

    convenience init(copy progress: Progress) {
        self.init(totalUnitCount: progress.totalUnitCount)

        self.completedUnitCount = progress.completedUnitCount
        self.fileOperationKind = progress.fileOperationKind
        self.kind = progress.kind
        self.isPausable = progress.isPausable
        self.isCancellable = progress.isCancellable
        self.fileURL = progress.fileURL
        self.fileDownloadingSourceURL = progress.fileDownloadingSourceURL
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

    var fileIcon: NSImage? {
        get {
            self.userInfo[.fileIconKey] as? NSImage
        }
        set {
            self.setUserInfoObject(newValue, forKey: .fileIconKey)
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

    var startTime: Date? {
        get {
            self.userInfo[.startTimeKey] as? Date
        }
        set {
            self.setUserInfoObject(newValue, forKey: .startTimeKey)
        }
    }

    /// Initialize a new Progress that publishes the progress of a file operation.
    ///
    /// Primarily this is used to show a bounce if the file is in a location on the user's dock (e.g. Downloads)
    /// - Parameters:
    ///   - url: The URL of the file to observe.
    ///   - block: A closure used to perform an operation on the file at the specified `url`.
    static func withPublishedProgress(url: URL, block: () throws -> Void) throws {
        let progress = Progress(
            totalUnitCount: 1,
            fileOperationKind: .downloading,
            kind: .file,
            isPausable: false,
            isCancellable: false,
            fileURL: url
        )

        defer { progress.unpublish() }
        progress.publish()

        do {
            try block()
            progress.completedUnitCount = progress.totalUnitCount
        } catch {
            throw error
        }
    }

}

extension ProgressUserInfoKey {
    static let fileDownloadingSourceURLKey = ProgressUserInfoKey(rawValue: "NSProgressFileDownloadingSourceURL")
    static let fileLocationCanChangeKey = ProgressUserInfoKey(rawValue: "NSProgressFileLocationCanChangeKey")
    static let flyToImageKey = ProgressUserInfoKey(rawValue: "NSProgressFlyToImageKey")
    static let fileIconKey = ProgressUserInfoKey(rawValue: "NSProgressFileIconKey")
    static let fileIconOriginalRectKey = ProgressUserInfoKey(rawValue: "NSProgressFileAnimationImageOriginalRectKey")

    fileprivate static let startTimeKey = ProgressUserInfoKey(rawValue: "startTimeKey")
}
