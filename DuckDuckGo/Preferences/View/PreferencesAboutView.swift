//
//  PreferencesAboutView.swift
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

import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions

fileprivate extension Font {
    static let companyName: Font = .title
    static let privacySimplified: Font = .title3.weight(.semibold)
}

extension Preferences {

    struct AboutView: View {
        @ObservedObject var model: AboutPreferences
        @State private var areAutomaticUpdatesEnabled: Bool = true

        var body: some View {
            PreferencePane {
                VStack(alignment: .leading) {
                    TextMenuTitle(UserText.aboutDuckDuckGo)

                    if !model.isCurrentOsReceivingUpdates {
                        UnsupportedDeviceInfoBox(wide: true)
                            .padding(.top, 10)
                            .padding(.leading, -20)
                    }

                    AboutContentSection(model: model)

#if SPARKLE
                    UpdatesSection(areAutomaticUpdatesEnabled: $areAutomaticUpdatesEnabled, model: model)
#endif
                }
            }
        }
    }

    struct AboutContentSection: View {
        @ObservedObject var model: AboutPreferences

        var body: some View {
            PreferencePaneSection {
                if #available(macOS 13.0, *) {
                    ViewThatFits(in: .horizontal) {
                        horizontalPageLogo
                        verticalPageLogo
                    }
                } else {
                    horizontalPageLogo
                }

                TextButton(UserText.moreAt(url: model.displayableAboutURL)) {
                    model.openNewTab(with: .aboutDuckDuckGo)
                }

                TextButton(UserText.privacyPolicy) {
                    model.openNewTab(with: .privacyPolicy)
                }

                #if FEEDBACK
                Button(UserText.sendFeedback) {
                    model.openFeedbackForm()
                }
                .padding(.top, 4)
                #endif
            }
            #if SPARKLE
            .onAppear {
                model.subscribeToUpdateInfoIfNeeded()
            }
            #endif
        }

        private var rightColumnContent: some View {
            Group {
                #if APPSTORE
                Text(UserText.duckDuckGoForMacAppStore).font(.companyName)

                Text(UserText.duckduckgoTagline).font(.privacySimplified)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Text(UserText.versionLabel(version: model.appVersion.versionNumber, build: model.appVersion.buildNumber))
                    .contextMenu(ContextMenu(menuItems: {
                        Button(UserText.copy, action: {
                            model.copy(UserText.versionLabel(version: model.appVersion.versionNumber, build: model.appVersion.buildNumber))
                        })
                    }))
                #else
                Text(UserText.duckDuckGo).font(.companyName)

                Text(UserText.duckduckgoTagline).font(.privacySimplified)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack {
                    statusIcon.frame(width: 16, height: 16)
                    VStack(alignment: .leading) {
                        versionText
                        lastCheckedText
                    }
                }
                .padding(.bottom, 4)

                updateButton
                #endif
            }
        }

        private var horizontalPageLogo: some View {
            HStack(alignment: .top) {
                Image(.aboutPageLogo)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 8) {
                    rightColumnContent
                }
                .padding(.top, 10)
            }
            .padding(.bottom, 8)
        }

        private var verticalPageLogo: some View {
            VStack(alignment: .leading) {
                Image(.aboutPageLogo)
                VStack(alignment: .leading, spacing: 8) {
                    rightColumnContent
                }
                .padding(.top, 10)
            }
            .padding(.bottom, 8)
        }

#if SPARKLE
        private var hasPendingUpdate: Bool {
            model.updateController?.hasPendingUpdate == true
        }
        private var hasCriticalUpdate: Bool {
            model.updateController?.latestUpdate?.type == .critical
        }
#endif

        @ViewBuilder
        private var versionText: some View {
            HStack(spacing: 0) {
                Text(UserText.versionLabel(version: model.appVersion.versionNumber, build: model.appVersion.buildNumber))
                    .contextMenu(ContextMenu(menuItems: {
                        Button(UserText.copy, action: {
                            model.copy(UserText .versionLabel(version: model.appVersion.versionNumber, build: model.appVersion.buildNumber))
                        })
                    }))
#if SPARKLE
                switch model.updateState {
                case .upToDate:
                    Text(" — " + UserText.upToDate)
                case .updateCycle(let progress):
                    if hasPendingUpdate {
                        if hasCriticalUpdate {
                            Text(" — " + UserText.newerCriticalUpdateAvailable)
                        } else {
                            Text(" — " + UserText.newerVersionAvailable)
                        }
                    } else {
                        text(for: progress)
                    }
                }
#endif
            }
        }

#if SPARKLE
        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 0
            return formatter
        }

        @ViewBuilder
        private func text(for progress: UpdateCycleProgress) -> some View {
            switch progress {
            case .updateCycleDidStart:
                Text(" — " + UserText.checkingForUpdate)
            case .downloadDidStart:
                Text(" — " + String(format: UserText.downloadingUpdate, ""))
            case .downloading(let percentage):
                Text(" — " + String(format: UserText.downloadingUpdate,
                                    formatter.string(from: NSNumber(value: percentage)) ?? ""))
            case .extractionDidStart, .extracting, .readyToInstallAndRelaunch, .installationDidStart, .installing:
                Text(" — " + UserText.preparingUpdate)
            case .updaterError:
                Text(" — " + UserText.updateFailed)
            case .updateCycleNotStarted, .updateCycleDone:
                EmptyView()
            }
        }

        @ViewBuilder
        private var statusIcon: some View {
            switch model.updateState {
            case .upToDate:
                Image(nsImage: .check)
                    .foregroundColor(.green)
            case .updateCycle(let progress):
                if hasPendingUpdate {
                    if hasCriticalUpdate {
                        Image(nsImage: .criticalUpdateNotificationInfo)
                            .foregroundColor(.red)
                    } else {
                        Image(nsImage: .updateNotificationInfo)
                            .foregroundColor(.blue)
                    }
                } else if progress.isFailed {
                    Image(nsImage: .criticalUpdateNotificationInfo)
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
        }

        private var lastCheckedText: some View {
            let lastChecked = model.updateController?.updateProgress.isIdle == true ? lastCheckedFormattedDate(model.lastUpdateCheckDate) : "-"
            return Text("\(UserText.lastChecked): \(lastChecked)")
                .foregroundColor(.secondary)
        }

        private func lastCheckedFormattedDate(_ date: Date?) -> String {
            guard let date = date else { return "-" }

            let relativeDateFormatter = RelativeDateTimeFormatter()
            relativeDateFormatter.dateTimeStyle = .named

            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short

            let relativeDate = relativeDateFormatter.localizedString(for: date, relativeTo: Date())

            return relativeDate
        }

        @ViewBuilder
        private var updateButton: some View {
            switch model.updateState {
            case .upToDate:
                Button(UserText.checkForUpdate) {
                    model.checkForUpdate()
                }
                .buttonStyle(UpdateButtonStyle(enabled: true))
            case .updateCycle(let progress):
                if hasPendingUpdate {
                    Button(model.areAutomaticUpdatesEnabled ? UserText.restartToUpdate : UserText.runUpdate) {
                        model.runUpdate()
                    }
                    .buttonStyle(UpdateButtonStyle(enabled: true))
                } else if progress.isFailed {
                    Button(UserText.retryUpdate) {
                        model.checkForUpdate()
                    }
                    .buttonStyle(UpdateButtonStyle(enabled: true))
                } else {
                    Button(UserText.checkForUpdate) {
                        model.checkForUpdate()
                    }
                    .buttonStyle(UpdateButtonStyle(enabled: false))
                    .disabled(true)
                }
            }
        }
#endif
    }

#if SPARKLE
    struct UpdatesSection: View {
        @Binding var areAutomaticUpdatesEnabled: Bool
        @ObservedObject var model: AboutPreferences

        var body: some View {
            PreferencePaneSection(UserText.browserUpdatesTitle) {
                PreferencePaneSubSection {
                    Picker(selection: $areAutomaticUpdatesEnabled, content: {
                        Text(UserText.automaticUpdates).tag(true)
                            .padding(.bottom, 4).accessibilityIdentifier("PreferencesAboutView.automaticUpdatesPicker.automatically")
                        Text(UserText.manualUpdates).tag(false)
                            .accessibilityIdentifier("PreferencesAboutView.automaticUpdatesPicker.manually")
                    }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: PreferencesUI_macOS.Const.pickerHorizontalOffset)
                    .accessibilityIdentifier("PreferencesAboutView.automaticUpdatesPicker")
                    .onChange(of: areAutomaticUpdatesEnabled) { newValue in
                        model.areAutomaticUpdatesEnabled = newValue
                    }
                    .onAppear {
                        areAutomaticUpdatesEnabled = model.areAutomaticUpdatesEnabled
                    }
                }
            }
        }
    }
#endif

    struct UnsupportedDeviceInfoBox: View {

        static let softwareUpdateURL = URL(string: "x-apple.systempreferences:com.apple.preferences.softwareupdate")!

        var wide: Bool

        var width: CGFloat {
            return wide ? 510 : 320
        }

        var height: CGFloat {
            return wide ? 130 : 200
        }

        var osVersion: String {
            return "\(ProcessInfo.processInfo.operatingSystemVersion)"
        }

        var combinedText: String {
            return UserText.aboutUnsupportedDeviceInfo2(version: versionString)
        }

        var versionString: String {
            return "\(SupportedOSChecker.SupportedVersion.major).\(SupportedOSChecker.SupportedVersion.minor)"
        }

        var body: some View {
            let image = Image(.alertColor16)
                .resizable()
                .frame(width: 16, height: 16)
                .padding(.trailing, 4)

            let versionText = Text(UserText.aboutUnsupportedDeviceInfo1)

            let narrowContentView = Text(combinedText)

            let wideContentView: some View = VStack(alignment: .leading, spacing: 0) {
                if #available(macOS 12.0, *) {
                    Text(aboutUnsupportedDeviceInfo2Attributed)
                } else {
                    aboutUnsupportedDeviceInfo2DeprecatedView()
                }
            }

            return HStack(alignment: .top) {
                image
                VStack(alignment: .leading, spacing: 12) {
                    versionText
                    if wide {
                        wideContentView
                    } else {
                        narrowContentView
                    }
                }
            }
            .padding()
            .background(Color.unsupportedOSWarning)
            .cornerRadius(8)
            .frame(width: width, height: height)
        }

        @available(macOS 12, *)
        private var aboutUnsupportedDeviceInfo2Attributed: AttributedString {
            let baseString = UserText.aboutUnsupportedDeviceInfo2(version: versionString)
            var instructions = AttributedString(baseString)
            if let range = instructions.range(of: "macOS \(versionString)") {
                instructions[range].link = Self.softwareUpdateURL
            }
            return instructions
        }

        @ViewBuilder
        private func aboutUnsupportedDeviceInfo2DeprecatedView() -> some View {
            HStack(alignment: .center, spacing: 0) {
                Text(verbatim: UserText.aboutUnsupportedDeviceInfo2Part1 + " ")
                Button(action: {
                    NSWorkspace.shared.open(Self.softwareUpdateURL)
                }) {
                    Text(verbatim: UserText.aboutUnsupportedDeviceInfo2Part2(version: versionString) + " ")
                        .foregroundColor(Color.blue)
                        .underline()
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
                Text(verbatim: UserText.aboutUnsupportedDeviceInfo2Part3)
            }
            Text(verbatim: UserText.aboutUnsupportedDeviceInfo2Part4)
        }
    }
}

#if SPARKLE
struct UpdateButtonStyle: ButtonStyle {

    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public func makeBody(configuration: Self.Configuration) -> some View {

        let enabledBackgroundColor = configuration.isPressed ? Color(NSColor.controlAccentColor).opacity(0.5) : Color(NSColor.controlAccentColor)
        let disabledBackgroundColor = Color.gray.opacity(0.1)
        let labelColor = enabled ? Color.white : Color.primary.opacity(0.3)

        configuration.label
            .lineLimit(1)
            .frame(height: 28)
            .padding(.horizontal, 24)
            .background(enabled ? enabledBackgroundColor : disabledBackgroundColor)
            .foregroundColor(labelColor)
            .cornerRadius(8)
    }

}
#endif
