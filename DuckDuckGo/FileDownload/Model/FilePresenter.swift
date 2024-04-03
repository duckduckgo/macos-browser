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

private protocol FilePresenterDelegate: AnyObject {
    var logger: FilePresenterLogger { get }
    var url: URL? { get }
    func presentedItemDidMove(to newURL: URL)
    func accommodatePresentedItemDeletion() throws
    func accommodatePresentedItemEviction() throws
}

protocol FilePresenterLogger {
    func log(_ message: @autoclosure () -> String)
}

extension OSLog: FilePresenterLogger {
    func log(_ message: @autoclosure () -> String) {
        os_log(.debug, log: self, message())
    }
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
        final var shouldBeRemovedTwice = false

        init(presentedItemOperationQueue: OperationQueue) {
            self.presentedItemOperationQueue = presentedItemOperationQueue
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
            assert(delegate != nil)
            delegate?.presentedItemDidMove(to: newURL)
        }

        func accommodatePresentedItemDeletion(completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
            assert(delegate != nil)
            do {
                try delegate?.accommodatePresentedItemDeletion()
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }

        func accommodatePresentedItemEviction(completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
            assert(delegate != nil)
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

        init(primaryPresentedItemURL: URL?, presentedItemOperationQueue: OperationQueue) {
            self.primaryPresentedItemURL = primaryPresentedItemURL
            super.init(presentedItemOperationQueue: presentedItemOperationQueue)
        }

    }

    fileprivate let lock = NSLock()
    private var innerPresenter: DelegatingFilePresenter?
    private var dispatchSourceCancellable: AnyCancellable?

    fileprivate let logger: any FilePresenterLogger

    private var _url: URL?
    final var url: URL? {
        lock.withLock {
            _url
        }
    }
    private func setURL(_ newURL: URL?) {
        guard let oldValue = lock.withLock({ () -> URL?? in
            let oldValue = _url
            guard oldValue != newURL else { return URL??.none }
            _url = newURL
            return oldValue
        }) else { return }

        didSetURL(newURL, oldValue: oldValue)
    }

    private var urlSubject = PassthroughSubject<URL?, Never>()
    final var urlPublisher: AnyPublisher<URL?, Never> {
        urlSubject.prepend(url).eraseToAnyPublisher()
    }

    init(url: URL, primaryItemURL: URL? = nil, logger: FilePresenterLogger = OSLog.disabled, createIfNeededCallback: ((URL) throws -> URL)? = nil) throws {
        self._url = url
        self.logger = logger

        do {
            try setupInnerPresenter(for: url, primaryItemURL: primaryItemURL, createIfNeededCallback: createIfNeededCallback)
            logger.log("🗄️  added file presenter for \"\(url.path)\"\(primaryItemURL != nil ? " primary item: \"\(primaryItemURL!.path)\"" : "")")
        } catch {
            removeFilePresenter()
            throw error
        }
    }

    private func setupInnerPresenter(for url: URL, primaryItemURL: URL?, createIfNeededCallback: ((URL) throws -> URL)?) throws {
        let innerPresenter = if let primaryItemURL {
            DelegatingRelatedFilePresenter(primaryPresentedItemURL: primaryItemURL, presentedItemOperationQueue: FilePresenter.presentedItemOperationQueue)
        } else {
            DelegatingFilePresenter(presentedItemOperationQueue: FilePresenter.presentedItemOperationQueue)
        }
        innerPresenter.delegate = self
        self.innerPresenter = innerPresenter

        // even though we will call `addFilePresenter` again for a non-existent file,
        // we still must call this `addFilePresenter` to get access to the secondary item
        // (when primaryPresentedItemURL is provided).
        NSFileCoordinator.addFilePresenter(innerPresenter)

        if !FileManager.default.fileExists(atPath: url.path) {
            guard let createFile = createIfNeededCallback else {
                throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
            }
            logger.log("🗄️💥 creating file for presenter at \"\(url.path)\"")
            self._url = try coordinateWrite(at: url, using: createFile)
            // add the File Presenter once again after the file was created.
            // otherwise, file move events may not be received (looks like an API bug).
            NSFileCoordinator.addFilePresenter(innerPresenter)
            // need to balance sandbox extension release for secondary item presenters added twice
            innerPresenter.shouldBeRemovedTwice = (primaryItemURL != nil)
        }
        try coordinateRead(at: url, with: .withoutChanges) { url in
            addFSODispatchSource(for: url)
        }
    }

    private func addFSODispatchSource(for url: URL) {
        let fileDescriptor = open(url.path, O_EVTONLY)

        guard fileDescriptor != -1 else {
            let err = errno
            logger.log("🗄️❌ error opening \(url.path): \(err) – \(String(cString: strerror(err)))")
            return
        }

        // FilePresenter doesn‘t observe `rm` calls
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .delete, queue: .main)

        dispatchSource.setEventHandler { [weak self] in
            guard let self, let url = self.url else { return }
            self.logger.log("🗄️⚠️ file delete event handler: \"\(url.path)\"")
            var resolvedBookmarkData: URL? {
                var isStale = false
                guard let presenter = self as? SandboxFilePresenter,
                      let bookmarkData = presenter.fileBookmarkData,
                      let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) else {
                    if FileManager().fileExists(atPath: url.path) { return url } // file still exists but with different letter case ?
                    return nil
                }
                return url
            }
            if let existingUrl = resolvedBookmarkData {
                self.logger.log("🗄️⚠️ ignoring file delete event handler as file exists: \"\(url.path)\"")
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

    private func removeFilePresenter() {
        if let innerPresenter {
            logger.log("🗄️  removing file presenter for \"\(url?.path ?? "<nil>")\"")
            for _ in 1...(innerPresenter.shouldBeRemovedTwice ? 2 : 1) { // if secondary item presenter was added twice - remove it twice
                NSFileCoordinator.removeFilePresenter(innerPresenter)
            }
            self.innerPresenter = nil
        }
    }

    fileprivate func didSetURL(_ newValue: URL?, oldValue: URL?) {
        assert(newValue != oldValue)
        logger.log("🗄️  did update url from \"\(oldValue?.path ?? "<nil>")\" to \"\(newValue?.path ?? "<nil>")\"")
        urlSubject.send(newValue)
    }

    deinit {
        // innerPresenter delegate won‘t be available at this point, so set the final url here to remove the presenter
        innerPresenter?.fallbackPresentedItemURL = _url
        removeFilePresenter()
    }

}
extension FilePresenter: FilePresenterDelegate {

    func presentedItemDidMove(to newURL: URL) {
        logger.log("🗄️  presented item did move to \"\(newURL.path)\"")
        setURL(newURL)
    }

    func accommodatePresentedItemDeletion() throws {
        logger.log("🗄️  accommodatePresentedItemDeletion (\"\(url?.path ?? "<nil>")\")")
        setURL(nil)
        removeFilePresenter()
    }

    func accommodatePresentedItemEviction() throws {
        logger.log("🗄️  accommodatePresentedItemEviction (\"\(url?.path ?? "<nil>")\")")
        try accommodatePresentedItemDeletion()
    }

}

/// Maintains File Bookmark Data for presented resource URL
/// and manages its sandbox security scope access calling `stopAccessingSecurityScopedResource` on deinit
/// balanced with preceding `startAccessingSecurityScopedResource`
final class SandboxFilePresenter: FilePresenter {

    private let securityScopedURL: URL?

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
    /// - Parameter primaryItemURL: URL to a main file resource access to which has been granted.
    ///   Used to grant out-of-sandbox access to `url` representing a “secondary” resource like “download.duckload” where the `primaryItemURL` would point to “download.zip”.
    /// - Note: the secondary (“duckload”) file extension should be registered in the Info.plist with `NSIsRelatedItemType` flag set to `true`.
    /// - Parameter consumeUnbalancedStartAccessingResource: assume the `url` is already accessible (e.g. after choosing the file using Open Panel).
    ///   would cause an unbalanced `stopAccessingSecurityScopedResource` call on the File Presenter deallocation.
    init(url: URL, primaryItemURL: URL? = nil, consumeUnbalancedStartAccessingResource: Bool = false, logger: FilePresenterLogger = OSLog.disabled, createIfNeededCallback: ((URL) throws -> URL)? = nil) throws {

        if consumeUnbalancedStartAccessingResource || url.startAccessingSecurityScopedResource() == true {
            self.securityScopedURL = url
            logger.log("🏝️ \(consumeUnbalancedStartAccessingResource ? "consuming unbalanced startAccessingResource for" : "started resource access for") \"\(url.path)\"")
        } else {
            self.securityScopedURL = nil
            logger.log("🏖️ didn‘t start resource access for \"\(url.path)\"")
        }

        try super.init(url: url, primaryItemURL: primaryItemURL, logger: logger, createIfNeededCallback: createIfNeededCallback)

        do {
            try self.coordinateRead(at: url, with: .withoutChanges) { url in
                logger.log("📒 updating bookmark data for \"\(url.path)\"")
                self._fileBookmarkData = try url.bookmarkData(options: .withSecurityScope)
            }
        } catch {
            logger.log("📕 bookmark data retreival failed for \"\(url.path)\": \(error)")
            throw error
        }
    }

    init(fileBookmarkData: Data, logger: FilePresenterLogger = OSLog.disabled) throws {
        self._fileBookmarkData = fileBookmarkData

        var isStale = false
        logger.log("📒 resolving url from bookmark data")
        let url = try URL(resolvingBookmarkData: fileBookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
        if url.startAccessingSecurityScopedResource() == true {
            self.securityScopedURL = url
            logger.log("🏝️ started resource access for \"\(url.path)\"\(isStale ? " (stale)" : "")")
        } else {
            self.securityScopedURL = nil
            logger.log("🏖️ didn‘t start resource access for \"\(url.path)\"\(isStale ? " (stale)" : "")")
        }

        try super.init(url: url, logger: logger)

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
        logger.log("📒 updateFileBookmarkData for \"\(url?.path ?? "<nil>")\"")

        var fileBookmarkData: Data?
        do {
            fileBookmarkData = try url?.bookmarkData(options: .withSecurityScope)
        } catch {
            logger.log("📕 updateFileBookmarkData failed with \(error)")
        }

        guard lock.withLock({
            guard _fileBookmarkData != fileBookmarkData else { return false }
            _fileBookmarkData = fileBookmarkData
            return true
        }) else { return }

        fileBookmarkDataSubject.send(fileBookmarkData)
    }

    deinit {
        if let securityScopedURL {
            logger.log("🗄️  stopAccessingSecurityScopedResource \"\(securityScopedURL.path)\"")
            securityScopedURL.stopAccessingSecurityScopedResource()
        }
    }

}

extension FilePresenter {

    func coordinateRead<T>(at url: URL? = nil, with options: NSFileCoordinator.ReadingOptions = [], using reader: (URL) throws -> T) throws -> T {
        guard let innerPresenter, let url = url ?? self.url else { throw CocoaError(.fileNoSuchFile) }

        return try NSFileCoordinator(filePresenter: innerPresenter).coordinateRead(at: url, with: options, using: reader)
    }

    func coordinateWrite<T>(at url: URL? = nil, with options: NSFileCoordinator.WritingOptions = [], using writer: (URL) throws -> T) throws -> T {
        guard let innerPresenter, let url = url ?? self.url else { throw CocoaError(.fileNoSuchFile) }

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
        guard let innerPresenter, let url = url ?? self.url else { throw CocoaError(.fileNoSuchFile) }

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

#if DEBUG
extension NSURL {

    private static var stopAccessingSecurityScopedResourceCallback: ((URL) -> Void)?

    private static let originalStopAccessingSecurityScopedResource = {
        class_getInstanceMethod(NSURL.self, #selector(NSURL.stopAccessingSecurityScopedResource))!
    }()
    private static let swizzledStopAccessingSecurityScopedResource = {
        class_getInstanceMethod(NSURL.self, #selector(NSURL.swizzled_stopAccessingSecurityScopedResource))!
    }()
    private static let swizzleStopAccessingSecurityScopedResourceOnce: Void = {
        method_exchangeImplementations(originalStopAccessingSecurityScopedResource, swizzledStopAccessingSecurityScopedResource)
    }()

    static func swizzleStopAccessingSecurityScopedResource(with stopAccessingSecurityScopedResourceCallback: ((URL) -> Void)?) {
        _=swizzleStopAccessingSecurityScopedResourceOnce
        self.stopAccessingSecurityScopedResourceCallback = stopAccessingSecurityScopedResourceCallback
    }

    @objc private dynamic func swizzled_stopAccessingSecurityScopedResource() {
        if let stopAccessingSecurityScopedResourceCallback = Self.stopAccessingSecurityScopedResourceCallback {
            stopAccessingSecurityScopedResourceCallback(self as URL)
        }
        self.swizzled_stopAccessingSecurityScopedResource() // call original
    }

}
#endif
