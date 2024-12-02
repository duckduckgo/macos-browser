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

    fileprivate enum Constants {
        static let width: CGFloat = 420
        static let height: CGFloat = 60
    }

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

    private let fileIconView = NSImageView()
    private let titleLabel = NSTextField()
    private let detailLabel = NSTextField()

    private let progressView = CircularProgressView()
    private let cancelButton = MouseOverButton(image: .cancelDownload,
                                               target: nil,
                                               action: #selector(DownloadsViewController.cancelDownloadAction))
    private let revealButton = MouseOverButton(image: .revealDownload,
                                               target: nil,
                                               action: #selector(DownloadsViewController.revealDownloadAction))
    private let restartButton = MouseOverButton(image: .restartDownload,
                                                target: nil,
                                                action: #selector(DownloadsViewController.restartDownloadAction))

    private let separator = NSBox()

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

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: CGRect(x: 0, y: 0, width: Constants.width, height: Constants.height))
        self.identifier = identifier

        setupUI()
        subscribeToMouseOverEvents()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    private func setupUI() {
        self.imageView = fileIconView
        self.wantsLayer = true

        addSubview(fileIconView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(cancelButton)
        addSubview(revealButton)
        addSubview(restartButton)
        addSubview(progressView)
        addSubview(separator)

        fileIconView.translatesAutoresizingMaskIntoConstraints = false
        fileIconView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        fileIconView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)
        fileIconView.imageScaling = .scaleProportionallyDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .controlTextColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        titleLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailLabel.isEditable = false
        detailLabel.isBordered = false
        detailLabel.isSelectable = false
        detailLabel.drawsBackground = false
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byClipping
        detailLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        detailLabel.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)

        progressView.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        cancelButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        cancelButton.bezelStyle = .shadowlessSquare
        cancelButton.isBordered = false
        cancelButton.imagePosition = .imageOnly
        cancelButton.imageScaling = .scaleProportionallyDown
        cancelButton.cornerRadius = 4
        cancelButton.backgroundInset = CGPoint(x: 2, y: 2)
        cancelButton.mouseDownColor = .buttonMouseDown
        cancelButton.mouseOverColor = .buttonMouseOver

        revealButton.translatesAutoresizingMaskIntoConstraints = false
        revealButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        revealButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        revealButton.alignment = .center
        revealButton.bezelStyle = .shadowlessSquare
        revealButton.isBordered = false
        revealButton.imagePosition = .imageOnly
        revealButton.imageScaling = .scaleProportionallyDown
        revealButton.cornerRadius = 4
        revealButton.backgroundInset = CGPoint(x: 2, y: 2)
        revealButton.mouseDownColor = .buttonMouseDown
        revealButton.mouseOverColor = .buttonMouseOver

        restartButton.translatesAutoresizingMaskIntoConstraints = false
        restartButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        restartButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        restartButton.alignment = .center
        restartButton.bezelStyle = .shadowlessSquare
        restartButton.isBordered = false
        restartButton.imagePosition = .imageOnly
        restartButton.imageScaling = .scaleProportionallyDown
        restartButton.cornerRadius = 4
        restartButton.backgroundInset = CGPoint(x: 2, y: 2)
        restartButton.mouseDownColor = .buttonMouseDown
        restartButton.mouseOverColor = .buttonMouseOver

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        setupLayout()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            fileIconView.heightAnchor.constraint(equalToConstant: 32),
            fileIconView.widthAnchor.constraint(equalToConstant: 32),
            fileIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            fileIconView.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.heightAnchor.constraint(equalToConstant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: 6),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            cancelButton.heightAnchor.constraint(equalToConstant: 32),
            cancelButton.widthAnchor.constraint(equalToConstant: 32),
            cancelButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            cancelButton.leadingAnchor.constraint(equalTo: detailLabel.trailingAnchor, constant: 8),
            cancelButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 4),

            revealButton.widthAnchor.constraint(equalToConstant: 32),
            revealButton.heightAnchor.constraint(equalToConstant: 32),
            revealButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            revealButton.centerXAnchor.constraint(equalTo: cancelButton.centerXAnchor),

            restartButton.widthAnchor.constraint(equalToConstant: 32),
            restartButton.heightAnchor.constraint(equalToConstant: 32),
            restartButton.centerXAnchor.constraint(equalTo: revealButton.centerXAnchor),
            restartButton.centerYAnchor.constraint(equalTo: revealButton.centerYAnchor),

            progressView.widthAnchor.constraint(equalToConstant: 27),
            progressView.heightAnchor.constraint(equalToConstant: 27),
            progressView.centerXAnchor.constraint(equalTo: cancelButton.centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),

            separator.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: separator.trailingAnchor),
            bottomAnchor.constraint(equalTo: separator.bottomAnchor),
        ])
    }

    private func subscribeToMouseOverEvents() {
        cancelButton.publisher(for: \.isMouseOver).sink { [weak self] isMouseOver in
            self?.onButtonMouseOverChange?(isMouseOver)
        }.store(in: &buttonOverCancellables)
        revealButton.publisher(for: \.isMouseOver).sink { [weak self] isMouseOver in
            self?.onButtonMouseOverChange?(isMouseOver)
        }.store(in: &buttonOverCancellables)
        restartButton.publisher(for: \.isMouseOver).sink { [weak self] isMouseOver in
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

    private static let fileRemovedTitleAttributes: [NSAttributedString.Key: Any] = [
        .strikethroughStyle: 1,
        .foregroundColor: NSColor.disabledControlTextColor
    ]

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

#if DEBUG
@available(macOS 14.0, *)
#Preview {
    DownloadsCellView.PreviewView()
}
@available(macOS 14.0, *)
let previewDownloadListItems: [DownloadListItem] = [
    DownloadListItem(identifier: .init(), added: .now, modified: .now, downloadURL: .empty, websiteURL: nil, fileName: "Indefinite progress download with long filename for clipping.zip", progress: Progress(totalUnitCount: -1), fireWindowSession: nil, destinationURL: URL(fileURLWithPath: "\(#file)"), destinationFileBookmarkData: nil, tempURL: URL(fileURLWithPath: "\(#file)"), tempFileBookmarkData: nil, error: nil),
    DownloadListItem(identifier: .init(), added: .now, modified: .now, downloadURL: .empty, websiteURL: nil, fileName: "Active download.pdf", progress: Progress(totalUnitCount: 100, completedUnitCount: 42), fireWindowSession: nil, destinationURL: URL(fileURLWithPath: "\(#file)"), destinationFileBookmarkData: nil, tempURL: URL(fileURLWithPath: "\(#file)"), tempFileBookmarkData: nil, error: nil),
    DownloadListItem(identifier: .init(), added: .now, modified: .now, downloadURL: .empty, websiteURL: nil, fileName: "Completed download.dmg", progress: nil, fireWindowSession: nil, destinationURL: URL(fileURLWithPath: "\(#file)"), destinationFileBookmarkData: nil, tempURL: nil, tempFileBookmarkData: nil, error: nil),
    DownloadListItem(identifier: .init(), added: .now, modified: .now, downloadURL: .empty, websiteURL: nil, fileName: "Non-retryable download.txt", progress: nil, fireWindowSession: nil, destinationURL: URL(fileURLWithPath: "\(#file)"), destinationFileBookmarkData: nil, tempURL: URL(fileURLWithPath: "\(#file)"), tempFileBookmarkData: nil, error: nil),
    DownloadListItem(identifier: .init(), added: .now, modified: .now, downloadURL: .empty, websiteURL: nil, fileName: "Retryable download.rtf", progress: nil, fireWindowSession: nil, destinationURL: URL(fileURLWithPath: "\(#file)"), destinationFileBookmarkData: nil, tempURL: URL(fileURLWithPath: "\(#file)"), tempFileBookmarkData: nil, error: FileDownloadError(URLError(.networkConnectionLost, userInfo: ["isRetryable": true]) as NSError)),
]
@available(macOS 14.0, *)
extension DownloadsCellView {
    final class PreviewView: NSView {

        init() {
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = true

            let cells = [
                DownloadsCellView(identifier: .init("")),
                DownloadsCellView(identifier: .init("")),
                DownloadsCellView(identifier: .init("")),
                DownloadsCellView(identifier: .init("")),
                DownloadsCellView(identifier: .init("")),
            ]

            for (idx, cell) in cells.enumerated() {
                cell.widthAnchor.constraint(equalToConstant: 420).isActive = true
                cell.heightAnchor.constraint(equalToConstant: 60).isActive = true
                let item = previewDownloadListItems[idx]
                cell.objectValue = DownloadViewModel(item: item)
            }

            let stackView = NSStackView(views: cells as [NSView])
            stackView.orientation = .vertical
            stackView.spacing = 1
            addAndLayout(stackView)

            widthAnchor.constraint(equalToConstant: 420).isActive = true
            heightAnchor.constraint(equalToConstant: CGFloat((60 + 1) * cells.count)).isActive = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    }
}
#endif
