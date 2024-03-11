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
import UniformTypeIdentifiers

final class DownloadsCellView: NSTableCellView {

    enum DownloadError: Error {
        case urlNotSet
        case fileRemoved
        case downloadFailed(FileDownloadError)

        var isCancelled: Bool {
            guard case .downloadFailed(let error) = self, error.isCancelled else { return false }
            return true
        }

        var isRetryable: Bool {
            guard case .downloadFailed(let error) = self, error.isRetryable else { return false }
            return true
        }
    }

    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var detailLabel: NSTextField!
    @IBOutlet var progressView: CircularProgressView!
    @IBOutlet var cancelButton: MouseOverButton!
    @IBOutlet var revealButton: MouseOverButton!
    @IBOutlet var restartButton: MouseOverButton!
    @IBOutlet var separator: NSBox!

    private var buttonOverCancellables = Set<AnyCancellable>()
    private var cancellables = Set<AnyCancellable>()
    private var progressCancellable: AnyCancellable?

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.isAdaptive = true
        formatter.allowsNonnumericFormatting = false
        formatter.zeroPadsFractionDigits = true
        return formatter
    }()

    private static let estimatedMinutesRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = false
        formatter.includesTimeRemainingPhrase = true
        return formatter
    }()

    private static let estimatedSecondsRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.second]
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = false
        formatter.includesTimeRemainingPhrase = true
        return formatter
    }()

    var isSelected: Bool = false {
        didSet {
            separator.isHidden = isSelected
        }
    }

    override func awakeFromNib() {
        cancelButton.$isMouseOver.sink { [weak self] isMouseOver in
            self?.onButtonMouseOverChange?(isMouseOver)
        }.store(in: &buttonOverCancellables)
        revealButton.$isMouseOver.sink { [weak self] isMouseOver in
            self?.onButtonMouseOverChange?(isMouseOver)
        }.store(in: &buttonOverCancellables)
        restartButton.$isMouseOver.sink { [weak self] isMouseOver in
            self?.onButtonMouseOverChange?(isMouseOver)
        }.store(in: &buttonOverCancellables)
    }

    override var objectValue: Any? {
        didSet {
            assert(objectValue is DownloadViewModel?)
            guard let viewModel = objectValue as? DownloadViewModel else {
                unsubscribe()
                return
            }

            // animate progress appearance if needed
            subscribeToViewModel(viewModel)
            // reset `shouldAnimate` flag
            viewModel.didAppear()
        }
    }

    // called on cell appearance
    private func subscribeToViewModel(_ viewModel: DownloadViewModel) {
        viewModel.$filename
            .map { filename in
                let utType = UTType(filenameExtension: filename.pathExtension) ?? .data
                return NSWorkspace.shared.icon(for: utType)
            }
            .assign(to: \.image, on: imageView!)
            .store(in: &cancellables)

        viewModel.$filename
            .combineLatest(viewModel.$state)
            .sink { [weak self] filename, state in
                self?.updateFilename(filename, state: state)
            }
            .store(in: &cancellables)

        // only animate progress appearance when download is added
        if case .downloading(let progress, shouldAnimateOnAppear: false /* progress was already displayed once */) = viewModel.state {
            let progressValue = progress.totalUnitCount == -1 ? -1 : Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            // set progress without animation
            progressView.setProgress(progressValue, animated: false)
        }

        self.subscribeToStateProgressUpdates(viewModel)
    }

    private func subscribeToStateProgressUpdates(_ viewModel: DownloadViewModel) {
        viewModel.$state
            .map { state -> AnyPublisher<Double?, Never> in
                guard case .downloading(let progress, _) = state else {
                    return Just(.none).eraseToAnyPublisher()
                }

                return progress.publisher(for: \.totalUnitCount)
                    .combineLatest(progress.publisher(for: \.completedUnitCount))
                    .map { (total, completed) -> Double? in
                        guard total > 0 else { return -1 /* indeterminate */ }
                        return Double(completed) / Double(total)
                    }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [weak self] progress in
                guard let self else { return }

                // don‘t hide progress on completion - it will be animated out in `updateFilename(_:state:)`
                if progressView.progress != nil && progress == nil { return }

                progressView.setProgress(progress, animated: true)
            }
            .store(in: &cancellables)
    }

    private static let fileRemovedTitleAttributes: [NSAttributedString.Key: Any] = [.strikethroughStyle: 1,
                                                                                    .foregroundColor: NSColor.disabledControlTextColor]

    private func updateFilename(_ filename: String, state: DownloadViewModel.State) {
        // hide progress with animation on completion/failure
        if state.progress == nil, progressView.progress != nil {
            progressView.setProgress(nil, animated: true) { [weak self, viewModel=(objectValue as? DownloadViewModel)] _ in
                guard let self, objectValue as? DownloadViewModel === viewModel else { return }

                updateButtons(for: state, animated: true)
            }
        } else {
            updateButtons(for: state, animated: false)
        }

        var attributes: [NSAttributedString.Key: Any]?
        switch state {
        case .downloading(let progress, _):
            subscribe(to: progress)

        case .complete(.some(let url)):
            guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                updateDownloadFailed(with: .fileRemoved)
                attributes = Self.fileRemovedTitleAttributes
                break
            }

            updateCompletedFile(fileSize: fileSize)

        case .complete(.none):
            updateDownloadFailed(with: .urlNotSet)

        case .failed(let error):
            updateDownloadFailed(with: .downloadFailed(error))
        }

        titleLabel.attributedStringValue = NSAttributedString(string: filename, attributes: attributes)
        titleLabel.toolTip = filename
    }

    private var onButtonMouseOverChange: ((Bool) -> Void)?

    private func updateDetails(with progress: Progress, isMouseOver: Bool) {
        self.detailLabel.toolTip = nil

        var details: String
        var estimatedTime: String = ""
        if isMouseOver {
            details = UserText.cancelDownloadToolTip
        } else {
            if progress.completedUnitCount == 0 {
                details = UserText.downloadStarting
            } else if progress.fractionCompleted == 1.0 {
                details = UserText.downloadFinishing
            } else if progress.totalUnitCount > 0 {
                let completed = Self.byteFormatter.string(fromByteCount: progress.completedUnitCount)
                let total = Self.byteFormatter.string(fromByteCount: progress.totalUnitCount)
                details = String(format: UserText.downloadBytesLoadedFormat, completed, total)
            } else {
                details = Self.byteFormatter.string(fromByteCount: progress.completedUnitCount)
            }

            if progress.completedUnitCount > 0, progress.fractionCompleted < 1,
               let throughput = progress.throughput {
                let speed = Self.byteFormatter.string(fromByteCount: Int64(throughput))
                details += " (\(String(format: UserText.downloadSpeedFormat, speed)))"
            }

            if let estimatedTimeRemaining = progress.estimatedTimeRemaining,
               // only set estimated time if already present or more than 10 seconds remaining to avoid blinking
               self.detailLabel.stringValue.contains("–") || estimatedTimeRemaining > 10,
               let estimatedTimeStr = {
                switch estimatedTimeRemaining {
                case ..<60:
                    Self.estimatedSecondsRemainingFormatter.string(from: estimatedTimeRemaining)
                default:
                    Self.estimatedMinutesRemainingFormatter.string(from: estimatedTimeRemaining)
                }
            }() {
                estimatedTime = estimatedTimeStr
            }
        }

        self.detailLabel.stringValue = details + (estimatedTime.isEmpty ? "" : " – " + estimatedTime)
    }

    private func subscribe(to progress: Progress) {
        progressCancellable = progress.publisher(for: \.completedUnitCount)
            .throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self else { return }
                updateDetails(with: progress, isMouseOver: cancelButton.isMouseOver)
        }

        imageView?.alphaValue = 1.0

        onButtonMouseOverChange = { [weak self] isMouseOver in
            self?.updateDetails(with: progress, isMouseOver: isMouseOver)
        }
        onButtonMouseOverChange!(cancelButton.isMouseOver)
    }

    private func updateCompletedFile(fileSize: Int) {
        progressCancellable = nil

        imageView?.alphaValue = 1.0

        onButtonMouseOverChange = { [weak self] isMouseOver in
            guard let self else { return }
            if isMouseOver {
                detailLabel.stringValue = UserText.revealToolTip
            } else {
                detailLabel.stringValue = Self.byteFormatter.string(fromByteCount: Int64(fileSize))
            }
            detailLabel.toolTip = nil
        }
        onButtonMouseOverChange!(revealButton.isMouseOver)
    }

    private func updateDownloadFailed(with error: DownloadError) {
        progressCancellable = nil

        imageView?.animator().alphaValue = if case .fileRemoved = error { 0.3 } else { 1.0 }

        onButtonMouseOverChange = { [weak self] isMouseOver in
            guard let self else { return }
            if isMouseOver {
                if case .fileRemoved = error {
                    detailLabel.stringValue = UserText.redownloadToolTip
                } else {
                    detailLabel.stringValue = UserText.restartDownloadToolTip
                }
                detailLabel.toolTip = nil
            } else {
                detailLabel.stringValue = error.shortDescription
                detailLabel.toolTip = error.localizedDescription
            }
        }
        onButtonMouseOverChange!(restartButton.isMouseOver)
    }

    private func updateButtons(for state: DownloadViewModel.State, animated: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            if !animated {
                context.duration = 0
            }

            progressView.isHidden = (state.progress == nil)
            cancelButton.animator().isHidden = (state.progress == nil)
            restartButton.animator().isHidden = (state.error?.isRetryable != true)
            revealButton.animator().isHidden = (state.progress != nil || state.error != nil)
        }
    }

    private func unsubscribe() {
        cancellables.removeAll()
        progressCancellable = nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        unsubscribe()
        progressView.prepareForReuse()
        detailLabel.stringValue = ""
        titleLabel.stringValue = ""
    }

}

extension DownloadsCellView.DownloadError: LocalizedError {

    var shortDescription: String {
        switch self {
        case .urlNotSet:
            return ""
        case .fileRemoved:
            return UserText.downloadedFileRemoved
        case .downloadFailed(.failedToMoveFileToDownloads):
            return UserText.downloadFailedToMoveFileToDownloads
        case .downloadFailed(let error) where error.isCancelled:
            return UserText.downloadCanceled
        case .downloadFailed(.failedToCompleteDownloadTask):
            return UserText.downloadFailed
        }
    }

    var errorDescription: String? {
        guard case .downloadFailed(.failedToCompleteDownloadTask(underlyingError: let error, resumeData: _, _)) = self else {
            return shortDescription
        }
        return error?.localizedDescription
    }

}
