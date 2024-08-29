//
//  FilePresenter.swift
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

import Combine
import Common
import Foundation
import os.log

private protocol FilePresenterDelegate: AnyObject {
    var url: URL? { get }
    func presentedItemDidMove(to newURL: URL)
    func accommodatePresentedItemDeletion() throws
    func accommodatePresentedItemEviction() throws
}

internal class FilePresenter {

    private static let dispatchSourceQueue = DispatchQueue(label: "CoordinatedFile.dispatchSourceQueue")
    private static let presentedItemOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.underlyingQueue = dispatchSourceQueue
        queue.name = "CoordinatedFile.presentedItemOperationQueue"
        queue.maxConcurrentOperationCount = 1
        queue.isSuspended = false
        return queue
    }()

    /// NSFilePresenter needs to be removed from NSFileCoordinator before its deallocation, that‘s why we‘re using the wrapper
    private class DelegatingFilePresenter: NSObject, NSFilePresenter {

        final let presentedItemOperationQueue: OperationQueue
        fileprivate final weak var delegate: FilePresenterDelegate?

        init(presentedItemOperationQueue: OperationQueue, delegate: FilePresenterDelegate) {
            self.presentedItemOperationQueue = presentedItemOperationQueue
            self.delegate = delegate
        }

        final var fallbackPresentedItemURL: URL?
        final var presentedItemURL: URL? {
            guard let delegate else { return fallbackPresentedItemURL }
            FilePresenter.dispatchSourceQueue.async {
                // prevent owning FilePresenter deallocation inside the presentedItemURL getter
                withExtendedLifetime(delegate) {}
            }
            let url = delegate.url
            return url
        }

        final func presentedItemDidMove(to newURL: URL) {
            delegate?.presentedItemDidMove(to: newURL)
        }

        func accommodatePresentedItemDeletion(completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
            do {
                try delegate?.accommodatePresentedItemDeletion()
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }

        func accommodatePresentedItemEviction(completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
            do {
                try delegate?.accommodatePresentedItemEviction()
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }

    }

    final private class DelegatingRelatedFilePresenter: DelegatingFilePresenter {

        let primaryPresentedItemURL: URL?

        init(primaryPresentedItemURL: URL?, presentedItemOperationQueue: OperationQueue, delegate: FilePresenterDelegate) {
            self.primaryPresentedItemURL = primaryPresentedItemURL
            super.init(presentedItemOperationQueue: presentedItemOperationQueue, delegate: delegate)
        }

    }

    fileprivate let lock = NSLock()
    private var innerPresenters = [DelegatingFilePresenter]()
    private var dispatchSourceCancellable: AnyCancellable?

    private var urlController: SecurityScopedFileURLController?
    final var url: URL? {
        lock.withLock {
            urlController?.url
        }
    }
    private func setURL(_ newURL: URL?) {
        guard let oldValue = lock.withLock({ _setURL(newURL) }) else { return }

        didSetURL(newURL, oldValue: oldValue)
    }

    // inside locked scope
    private func _setURL(_ newURL: URL?) -> URL?? /* returns old value (URL?) if new value was updated */ {
        let oldValue = urlController?.url
        guard oldValue != newURL else { return URL??.none }
        guard let newURL else {
            urlController = nil
            return newURL
        }

        // if the new url is pointing to the same path (only letter case has changed) - keep its sandbox extension in a new Controller
        if let urlController, let oldValue,
           oldValue.resolvingSymlinksInPath().path == newURL.resolvingSymlinksInPath().path,
           urlController.isManagingSecurityScope {
            urlController.updateUrlKeepingSandboxExtensionRetainCount(newURL)
        } else {
            urlController = SecurityScopedFileURLController(url: newURL)
        }

        return oldValue
    }

    private var urlSubject = PassthroughSubject<URL?, Never>()
    final var urlPublisher: AnyPublisher<URL?, Never> {
        urlSubject.prepend(url).eraseToAnyPublisher()
    }

    /// - Parameter url: represented file URL access to which is coordinated by the File Presenter.
    /// - Parameter consumeUnbalancedStartAccessingResource: assume the `url` is already accessible (e.g. after choosing the file using Open Panel).
    ///   would cause an unbalanced `stopAccessingSecurityScopedResource` call on the File Presenter deallocation.
    /// - Note: see https://stackoverflow.com/questions/25627628/sandboxed-mac-app-exhausting-security-scoped-url-resources
    init(url: URL, consumeUnbalancedStartAccessingResource: Bool = false, createIfNeededCallback: ((URL) throws -> URL)? = nil) throws {
        self.urlController = SecurityScopedFileURLController(url: url, manageSecurityScope: consumeUnbalancedStartAccessingResource)

        do {
            try setupInnerPresenter(for: url, primaryItemURL: nil, createIfNeededCallback: createIfNeededCallback)
            Logger.fileDownload.debug("🗄️  added file presenter for \"\(url.path)\"")
        } catch {
            removeFilePresenters()
            throw error
        }
    }

    /// - Parameter url: represented file URL access to which is coordinated by the File Presenter.
    /// - Parameter primaryItemURL: URL to a main file resource access to which has been granted.
    ///   Used to grant out-of-sandbox access to `url` representing a “related” resource like “download.duckload” where the `primaryItemURL` would point to “download.zip”.
    /// - Note: the related (“duckload”) file extension should be registered in the Info.plist with `NSIsRelatedItemType` flag set to `true`.
    /// - Note: when presenting a related item the security scoped resource access will always be stopped on the File Presenter deallocation
    /// - Parameter consumeUnbalancedStartAccessingResource: assume the `url` is already accessible (e.g. after choosing the file using Open Panel).
    ///   would cause an unbalanced `stopAccessingSecurityScopedResource` call on the File Presenter deallocation.
    init(url: URL, primaryItemURL: URL, createIfNeededCallback: ((URL) throws -> URL)? = nil) throws {
        self.urlController = SecurityScopedFileURLController(url: url)

        do {
            try setupInnerPresenter(for: url, primaryItemURL: primaryItemURL, createIfNeededCallback: createIfNeededCallback)
            Logger.fileDownload.debug("🗄️  added file presenter for \"\(url.path) primary item: \"\(primaryItemURL.path)\"")
        } catch {
            removeFilePresenters()
            throw error
        }
    }

    private func setupInnerPresenter(for url: URL, primaryItemURL: URL?, createIfNeededCallback: ((URL) throws -> URL)?) throws {
        let innerPresenter = if let primaryItemURL {
            DelegatingRelatedFilePresenter(primaryPresentedItemURL: primaryItemURL, presentedItemOperationQueue: FilePresenter.presentedItemOperationQueue, delegate: self)
        } else {
            DelegatingFilePresenter(presentedItemOperationQueue: FilePresenter.presentedItemOperationQueue, delegate: self)
        }
        self.innerPresenters = [innerPresenter]

        NSFileCoordinator.addFilePresenter(innerPresenter)

        if !FileManager.default.fileExists(atPath: url.path) {
            guard let createFile = createIfNeededCallback else {
                throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
            }
            Logger.fileDownload.debug("🗄️💥 creating file for presenter at \"\(url.path)\"")
            // create new file at the presented URL using the provided callback and update URL if needed
            _=self._setURL(
                try coordinateWrite(at: url, using: createFile)
            )

            if primaryItemURL == nil {
                // Remove and re-add the file presenter for regular item presenters.
                NSFileCoordinator.removeFilePresenter(innerPresenter)
                NSFileCoordinator.addFilePresenter(innerPresenter)
            }
        }
        // to correctly handle file move events for a “related” item presenters we need to use a secondary presenter
        if primaryItemURL != nil {
            // set permanent original url without tracking file movements
            // to correctly release the sandbox extension when the “related” presenter is removed
            innerPresenter.fallbackPresentedItemURL = url
            innerPresenter.delegate = nil

            let innerPresenter2 = DelegatingFilePresenter(presentedItemOperationQueue: FilePresenter.presentedItemOperationQueue, delegate: self)
            NSFileCoordinator.addFilePresenter(innerPresenter2)
            innerPresenters.append(innerPresenter2)
        }

        try coordinateRead(at: url, with: .withoutChanges) { url in
            addFSODispatchSource(for: url)
        }
    }

    private func addFSODispatchSource(for url: URL) {
        let fileDescriptor = open(url.path, O_EVTONLY)

        guard fileDescriptor != -1 else {
            let err = errno
            Logger.fileDownload.debug("🗄️❌ error opening \(url.path): \(err) – \(String(cString: strerror(err)))")
            return
        }

        // FilePresenter doesn‘t observe `rm` calls
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .delete, queue: .main)

        dispatchSource.setEventHandler { [weak self] in
            guard let self, let url = self.url else { return }
            Logger.fileDownload.debug("🗄️⚠️ file delete event handler: \"\(url.path)\"")
            var resolvedBookmarkData: URL? {
                var isStale = false
                guard let presenter = self as? BookmarkFilePresenter,
                      let bookmarkData = presenter.fileBookmarkData,
                      let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) else {
                    if FileManager().fileExists(atPath: url.path) { return url } // file still exists but with different letter case ?
                    return nil
                }
                return url
            }
            if let existingUrl = resolvedBookmarkData {
                Logger.fileDownload.debug("🗄️⚠️ ignoring file delete event handler as file exists: \"\(url.path)\"")
                presentedItemDidMove(to: existingUrl)
                return
            }

            try? accommodatePresentedItemDeletion()
            self.dispatchSourceCancellable = nil
        }

        self.dispatchSourceCancellable = AnyCancellable {
            dispatchSource.cancel()
            close(fileDescriptor)
        }
        dispatchSource.resume()
    }

    private func removeFilePresenters() {
        for (idx, innerPresenter) in innerPresenters.enumerated() {
            // innerPresenter delegate won‘t be available at this point when called from `deinit`,
            // so set the final url here to correctly remove the presenter.
            if innerPresenter.fallbackPresentedItemURL == nil {
                innerPresenter.fallbackPresentedItemURL = urlController?.url
            }
            Logger.fileDownload.debug("🗄️  removing file presenter \(idx) for \"\(innerPresenter.presentedItemURL?.path ?? "<nil>")\"")
            NSFileCoordinator.removeFilePresenter(innerPresenter)
        }
        if innerPresenters.count > 1 {
            // ”related” item File Presenters make an unbalanced sandbox extension retain,
            // release the actual file URL sandbox extension by calling an extra `stopAccessingSecurityScopedResource`
            urlController?.url.consumeUnbalancedStartAccessingSecurityScopedResource()
        }
        innerPresenters = []
    }

    fileprivate func didSetURL(_ newValue: URL?, oldValue: URL?) {
        assert(newValue == nil || newValue != oldValue)
        Logger.fileDownload.debug("🗄️  did update url from \"\(oldValue?.path ?? "<nil>")\" to \"\(newValue?.path ?? "<nil>")\"")
        urlSubject.send(newValue)
    }

    deinit {
        removeFilePresenters()
    }

}

extension FilePresenter: FilePresenterDelegate {

    func presentedItemDidMove(to newURL: URL) {
        Logger.fileDownload.debug("🗄️  presented item did move to \"\(newURL.path)\"")
        setURL(newURL)
    }

    func accommodatePresentedItemDeletion() throws {
        Logger.fileDownload.debug("🗄️  accommodatePresentedItemDeletion (\"\(self.url?.path ?? "<nil>")\")")
        // should go before resetting the URL to correctly remove File Presenter
        removeFilePresenters()
        setURL(nil)
    }

    func accommodatePresentedItemEviction() throws {
        Logger.fileDownload.debug("🗄️  accommodatePresentedItemEviction (\"\(self.url?.path ?? "<nil>")\")")
        try accommodatePresentedItemDeletion()
    }

}

/// Maintains File Bookmark Data for presented resource URL
/// and manages its sandbox security scope access calling `stopAccessingSecurityScopedResource` on deinit
/// balanced with preceding `startAccessingSecurityScopedResource`
final class BookmarkFilePresenter: FilePresenter {

    private var _fileBookmarkData: Data?
    final var fileBookmarkData: Data? {
        lock.withLock {
            _fileBookmarkData
        }
    }

    private var fileBookmarkDataSubject = PassthroughSubject<Data?, Never>()
    final var fileBookmarkDataPublisher: AnyPublisher<Data?, Never> {
        fileBookmarkDataSubject.prepend(fileBookmarkData).eraseToAnyPublisher()
    }

    /// - Parameter url: represented file URL access to which is coordinated by the File Presenter.
    /// - Parameter consumeUnbalancedStartAccessingResource: assume the `url` is already accessible (e.g. after choosing the file using Open Panel).
    ///   would cause an unbalanced `stopAccessingSecurityScopedResource` call on the File Presenter deallocation.
    override init(url: URL, consumeUnbalancedStartAccessingResource: Bool = false, createIfNeededCallback: ((URL) throws -> URL)? = nil) throws {

        try super.init(url: url, consumeUnbalancedStartAccessingResource: consumeUnbalancedStartAccessingResource, createIfNeededCallback: createIfNeededCallback)

        do {
            try self.coordinateRead(at: url, with: .withoutChanges) { url in
                Logger.fileDownload.debug("📒 updating bookmark data for \"\(url.path)\"")
                self._fileBookmarkData = try url.bookmarkData(options: .withSecurityScope)
            }
        } catch {
            Logger.fileDownload.debug("📕 bookmark data retreival failed for \"\(url.path)\": \(error)")
            throw error
        }
    }

    /// - Parameter url: represented file URL access to which is coordinated by the File Presenter.
    /// - Parameter primaryItemURL: URL to a main file resource access to which has been granted.
    ///   Used to grant out-of-sandbox access to `url` representing a “related” resource like “download.duckload” where the `primaryItemURL` would point to “download.zip”.
    /// - Note: the related (“duckload”) file extension should be registered in the Info.plist with `NSIsRelatedItemType` flag set to `true`.
    /// - Note: when presenting a related item the security scoped resource access will always be stopped on the File Presenter deallocation
    /// - Parameter consumeUnbalancedStartAccessingResource: assume the `url` is already accessible (e.g. after choosing the file using Open Panel).
    ///   would cause an unbalanced `stopAccessingSecurityScopedResource` call on the File Presenter deallocation.
    override init(url: URL, primaryItemURL: URL, createIfNeededCallback: ((URL) throws -> URL)? = nil) throws {
        try super.init(url: url, primaryItemURL: primaryItemURL, createIfNeededCallback: createIfNeededCallback)

        do {
            try self.coordinateRead(at: url, with: .withoutChanges) { url in
                Logger.fileDownload.debug("📒 updating bookmark data for \"\(url.path)\"")
                self._fileBookmarkData = try url.bookmarkData(options: .withSecurityScope)
            }
        } catch {
            Logger.fileDownload.debug("📕 bookmark data retreival failed for \"\(url.path)\": \(error)")
            throw error
        }
    }

    init(fileBookmarkData: Data) throws {
        self._fileBookmarkData = fileBookmarkData

        var isStale = false
        Logger.fileDownload.debug("📒 resolving url from bookmark data")
        let url = try URL(resolvingBookmarkData: fileBookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale)

        try super.init(url: url, consumeUnbalancedStartAccessingResource: true)

        if isStale {
            DispatchQueue.global().async { [weak self] in
                self?.updateFileBookmarkData(for: url)
            }
        }
    }

    override func didSetURL(_ newValue: URL?, oldValue: URL?) {
        super.didSetURL(newValue, oldValue: oldValue)
        updateFileBookmarkData(for: newValue)
    }

    fileprivate func updateFileBookmarkData(for url: URL?) {
        Logger.fileDownload.debug("📒 updateFileBookmarkData for \"\(url?.path ?? "<nil>")\"")

        var fileBookmarkData: Data?
        do {
            fileBookmarkData = try url?.bookmarkData(options: .withSecurityScope)
        } catch {
            Logger.fileDownload.debug("📕 updateFileBookmarkData failed with \(error)")
        }

        guard lock.withLock({
            guard _fileBookmarkData != fileBookmarkData else { return false }
            _fileBookmarkData = fileBookmarkData
            return true
        }) else { return }

        fileBookmarkDataSubject.send(fileBookmarkData)
    }

}

extension FilePresenter {

    func coordinateRead<T>(at url: URL? = nil, with options: NSFileCoordinator.ReadingOptions = [], using reader: (URL) throws -> T) throws -> T {
        guard let innerPresenter = innerPresenters.last, let url = url ?? self.url else { throw CocoaError(.fileNoSuchFile) }

        return try NSFileCoordinator(filePresenter: innerPresenter).coordinateRead(at: url, with: options, using: reader)
    }

    func coordinateWrite<T>(at url: URL? = nil, with options: NSFileCoordinator.WritingOptions = [], using writer: (URL) throws -> T) throws -> T {
        guard let innerPresenter = innerPresenters.last, let url = url ?? self.url else { throw CocoaError(.fileNoSuchFile) }

        // temporarily disable DispatchSource file removal events
        dispatchSourceCancellable?.cancel()
        defer {
            if FileManager.default.fileExists(atPath: url.path) {
                addFSODispatchSource(for: url)
            }
        }
        return try NSFileCoordinator(filePresenter: innerPresenter).coordinateWrite(at: url, with: options, using: writer)
    }

    public func coordinateMove<T>(from url: URL? = nil, to: URL, with options2: NSFileCoordinator.WritingOptions = .forReplacing, using move: (URL, URL) throws -> T) throws -> T {
        guard let innerPresenter = innerPresenters.last, let url = url ?? self.url else { throw CocoaError(.fileNoSuchFile) }

        return try NSFileCoordinator(filePresenter: innerPresenter).coordinateMove(from: url, to: to, with: options2, using: move)
    }

}

extension NSFileCoordinator {

    func coordinateRead<T>(at url: URL, with options: NSFileCoordinator.ReadingOptions = [], using reader: (URL) throws -> T) throws -> T {
        var result: Result<T, Error>!
        var error: NSError?
        coordinate(readingItemAt: url, options: options, error: &error) { url in
            result = Result {
                try reader(url)
            }
        }

        if let error { throw error }
        return try result.get()
    }

    func coordinateWrite<T>(at url: URL, with options: NSFileCoordinator.WritingOptions = [], using writer: (URL) throws -> T) throws -> T {
        var result: Result<T, Error>!
        var error: NSError?
        coordinate(writingItemAt: url, options: options, error: &error) { url in
            result = Result {
                try writer(url)
            }
        }

        if let error { throw error }
        return try result.get()
    }

    public func coordinateMove<T>(from url: URL, to: URL, with options2: NSFileCoordinator.WritingOptions = .forReplacing, using move: (URL, URL) throws -> T) throws -> T {
        var result: Result<T, Error>!
        var error: NSError?
        coordinate(writingItemAt: url, options: .forMoving, writingItemAt: to, options: options2, error: &error) { from, to in
            result = Result {
                try move(from, to)
            }
        }
        if let error { throw error }
        return try result.get()
    }

}
