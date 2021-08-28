//
//  DownloadsCellView.swift
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
import Combine

final class DownloadsCellView: NSTableCellView {

    enum DownloadError: Error {
        case urlNotSet
        case fileRemoved
        case downloadFailed(FileDownloadError)
    }

    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var detailLabel: NSTextField!
    @IBOutlet var progressView: CircularProgressView!
    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var revealButton: NSButton!
    @IBOutlet var restartButton: NSButton!

    private var cancellables = Set<AnyCancellable>()
    private var progressCancellable: AnyCancellable?

    private static let byteFormatter = ByteCountFormatter()

    override var objectValue: Any? {
        didSet {
            assert(objectValue is DownloadListItem?)
            guard let object = objectValue as? DownloadListItem else {
                unsubscribe()
                return
            }
            subscribe(to: object)
        }
    }

    private func subscribe(to object: DownloadListItem) {
        object.$fileType.combineLatest(object.$filename) { fileType, filename in
            var fileType = fileType ?? .data
            if fileType.fileExtension?.isEmpty ?? true {
                fileType = UTType(fileExtension: (filename as NSString).pathExtension) ?? .data
            }
            return fileType.icon
        }
            .assign(to: \.image, on: imageView!)
            .store(in: &cancellables)
        object.$filename.assign(to: \.stringValue, on: titleLabel!)
            .store(in: &cancellables)
        object.$state.sink { [weak self] state in
            self?.updateState(state)
        }.store(in: &cancellables)

        object.$state.map {
            $0.progress?.publisher(for: \.fractionCompleted).map { .some($0) }.eraseToAnyPublisher() ?? Just(.none).eraseToAnyPublisher()
        }
            .switchToLatest()
            .assign(to: \.progress, on: progressView)
            .store(in: &cancellables)
    }

    private func updateState(_ state: DownloadListItem.State) {
        switch state {
        case .downloading(let progress):
            subscribe(to: progress)

        case .complete(let url):
            updateCompletedFile(at: url)

        case .failed(error: let error, resumeData: _):
            updateDownloadFailed(with: .downloadFailed(error))
        }
    }

    private func subscribe(to progress: Progress) {
        self.progressView.isHidden = false
        progressCancellable = progress.publisher(for: \.completedUnitCount)
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self = self else { return }

                self.detailLabel.stringValue = progress.localizedAdditionalDescription
                self.detailLabel.toolTip = progress.localizedDescription
        }

        self.detailLabel.stringValue = progress.localizedAdditionalDescription
        self.detailLabel.toolTip = progress.localizedDescription

        self.cancelButton.isHidden = false
        self.restartButton.isHidden = true
        self.revealButton.isHidden = true
    }

    private func updateCompletedFile(at url: URL?) {
        guard let fileSize = try? url?.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            updateDownloadFailed(with: url == nil ? .urlNotSet : .fileRemoved)
            return
        }

        progressCancellable = nil
        self.progressView.isHidden = true

        self.detailLabel.stringValue = Self.byteFormatter.string(fromByteCount: Int64(fileSize))
        self.detailLabel.toolTip = nil

        self.cancelButton.isHidden = true
        self.restartButton.isHidden = true
        self.revealButton.isHidden = false
    }

    private func updateDownloadFailed(with error: DownloadError) {
        progressCancellable = nil
        self.progressView.isHidden = true

        self.detailLabel.stringValue = error.shortDescription
        self.detailLabel.toolTip = error.localizedDescription

        self.cancelButton.isHidden = true
        self.restartButton.isHidden = false
        self.revealButton.isHidden = true
    }

    private func unsubscribe() {
        cancellables.removeAll()
        progressCancellable = nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        unsubscribe()
    }

}

extension DownloadsCellView.DownloadError: LocalizedError {

    var shortDescription: String {
        switch self {
        case .urlNotSet:
            return ""
        case .fileRemoved:
            return UserText.downloadedFileRemoved
        case .downloadFailed(.cancelled):
            return UserText.downloadCanceled
        case .downloadFailed(.failedToMoveFileToDownloads):
            return UserText.downloadFailedToMoveFileToDownloads
        case .downloadFailed(.failedToCompleteDownloadTask(underlyingError: _, resumeData: _)):
            return UserText.downloadFailed
        }
    }

    var errorDescription: String? {
        guard case .downloadFailed(.failedToCompleteDownloadTask(underlyingError: let error, resumeData: _)) = self else {
            return shortDescription
        }
        return error.localizedDescription
    }

}
