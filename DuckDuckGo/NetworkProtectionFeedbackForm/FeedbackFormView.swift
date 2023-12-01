//
//  FeedbackFormView.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import SwiftUI

struct FeedbackFormView: View {

    private enum Constants {
        static let headerPadding = 20.0
        static let bodyPadding = 20.0
    }

    struct ViewSize {
        fileprivate(set) var headerHeight: Double = 0.0
        fileprivate(set) var viewHeight: Double = 0.0
        fileprivate(set) var spacerHeight: Double = 0.0
        fileprivate(set) var buttonsHeight: Double = 0.0

        var totalHeight: Double {
            headerHeight + viewHeight + spacerHeight + buttonsHeight + 70
        }
    }

    @EnvironmentObject var viewModel: VPNFeedbackFormViewModel

    let sizeChanged: (CGFloat) -> Void

    @State var viewSize: ViewSize = .init() {
        didSet {
            print("DEBUG: Size changed to \(viewSize.totalHeight)")
            sizeChanged(viewSize.totalHeight)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                Text("Report an Issue")
                    .font(.title2)
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .background(
                GeometryReader { proxy in
                    Color.green.onAppear {
                        viewSize.headerHeight = proxy.size.height
                    }
                }
            )

            Divider()

            Group {
                Picker(selection: $viewModel.selectedFeedbackCategory, content: {
                    ForEach(VPNFeedbackFormViewModel.FeedbackCategory.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }, label: {})
                .controlSize(.large)
                .padding(20)

                switch viewModel.selectedFeedbackCategory {
                case .landingPage:
                    Spacer()
                        .frame(height: 50)
                case .failsToConnect:
                    VPNFeedbackFormIssueDescriptionForm()
                case .tooSlow:
                    VPNFeedbackFormIssueDescriptionForm()
                case .issueWithAppOrWebsite:
                    VPNFeedbackFormIssueDescriptionForm()
                case .cantConnectToLocalDevice:
                    VPNFeedbackFormIssueDescriptionForm()
                case .appCrashesOrFreezes:
                    VPNFeedbackFormIssueDescriptionForm()
                case .featureRequest:
                    VPNFeedbackFormIssueDescriptionForm()
                case .somethingElse:
                    VPNFeedbackFormIssueDescriptionForm()
                }
            }
            .padding([.leading, .trailing, .bottom], 20)
            .background(
                GeometryReader { proxy in
                    Color.red.onAppear {
                        print("DEBUG: Changing body view height")
                        viewSize.viewHeight = proxy.size.height
                    }
                }
            )

            VPNFeedbackFormButtons()
                .padding(20)
                .background(
                    GeometryReader { proxy in
                        Color.blue.onAppear {
                            viewSize.buttonsHeight = proxy.size.height
                        }
                    }
                )
        }
    }

}

private struct VPNFeedbackFormIssueDescriptionForm: View {

    @State var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Please describe what's happening, what you expected to happen, and the steps that led to the issue:")
                .multilineTextAlignment(.leading)
                .lineLimit(nil)

            TextField("Your issue goes here...", text: $text)
                .textFieldStyle(.roundedBorder)
                .lineLimit(10)

            Text("In addition to the details entered into this form, your app issue report will contain:")
            Text("• Bullet one")
            Text("• Bullet two")
            Text("• Bullet three")

            Text("By clicking \"Submit\" I agree that DuckDuckGo may use the information in this report for purposes of improving the app's features.")
        }
    }

}

private struct VPNFeedbackFormButtons: View {

    @EnvironmentObject var viewModel: VPNFeedbackFormViewModel

    var body: some View {
        HStack {
            Button(action: {
                viewModel.process(action: .cancel)
            }, label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            })
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button(action: {
                viewModel.process(action: .submit)
            }, label: {
                Text("Submit")
                    .frame(maxWidth: .infinity)
            })
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
    }

}
