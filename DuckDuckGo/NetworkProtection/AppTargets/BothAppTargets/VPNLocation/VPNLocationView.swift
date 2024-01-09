//
//  VPNLocationView.swift
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

#if NETWORK_PROTECTION

import SwiftUI
import SwiftUIExtensions

struct VPNLocationView: View {
    @StateObject var model = VPNLocationViewModel()
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(UserText.vpnLocationListTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    VStack(alignment: .leading, spacing: 16) {
                        nearestSection
                        countriesSection
                    }
                    .padding(0)
                }
                .padding(.horizontal, 56)
                .padding(.top, 32)
                .padding(.bottom, 20)
            }
            VPNLocationViewButtons(
                onDone: {
                    model.onSubmit()
                    isPresented = false
                }, onCancel: {
                    isPresented = false
                }
            )
            .onAppear {
                Task {
                    await model.onViewAppeared()
                }
            }
        }
        .frame(minWidth: 624, maxWidth: .infinity, minHeight: 514, maxHeight: 514, alignment: .top)
    }

    @ViewBuilder
    private var nearestSection: some View {
        PreferencePaneSection(verticalPadding: 12) {
            Text(UserText.vpnLocationRecommendedSectionTitle)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            nearestItem
        }
    }

    @ViewBuilder
    private var nearestItem: some View {
        ChecklistItem(
            isSelected: model.isNearestSelected,
            action: {
                Task {
                    await model.onNearestItemSelection()
                }
            }, label: {
                Image(systemName: "location.fill")
                    .resizable()
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text(UserText.vpnLocationNearestAvailable)
                        .foregroundColor(.primary)
                    Text(UserText.vpnLocationNearestAvailableSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        )
        .frame(idealWidth: .infinity, maxWidth: .infinity, maxHeight: 52)
        .padding(10)
        .background(Color("BlackWhite1"))
        .roundedBorder()
    }

    @ViewBuilder
    private var countriesSection: some View {
        switch model.state {
        case .loading:
            EmptyView()
                .listRowBackground(Color.clear)
        case .loaded(let countryItems):
            PreferencePaneSection(verticalPadding: 12) {
                Text(UserText.vpnLocationCustomSectionTitle)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                countriesList(countries: countryItems)
            }
        }
    }

    private func countriesList(countries: [VPNCountryItemModel]) -> some View {
        VStack(spacing: 0) {
            if countries.isEmpty {
                ProgressView()
                    .padding()
            }

            ForEach(countries) { country in
                if !country.isFirstItem {
                    Rectangle()
                        .fill(Color("BlackWhite10"))
                        .frame(height: 1)
                        .padding(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
                }

                CountryItem(
                    itemModel: country,
                    action: {
                        Task {
                            await model.onCountryItemSelection(id: country.id)
                        }
                    },
                    cityPickerAction: { selection in
                        Task {
                            await model.onCountryItemSelection(id: country.id, cityId: selection)
                        }
                    }
                )
            }
        }
        .roundedBorder()
    }
}

private struct CountryItem: View {
    let itemModel: VPNCountryItemModel
    let action: () -> Void
    let cityPickerAction: (String?) -> Void

    private var selectedCityItemBinding: Binding<VPNCityItemModel> {
        Binding {
            itemModel.selectedCityItem
        } set: { city in
            cityPickerAction(city.id)
        }
    }

    init(itemModel: VPNCountryItemModel, action: @escaping () -> Void, cityPickerAction: @escaping (String?) -> Void) {
        self.itemModel = itemModel
        self.action = action
        self.cityPickerAction = cityPickerAction
    }

    var body: some View {
        ChecklistItem(
            isSelected: itemModel.isSelected,
            action: action,
            label: {
                Text(itemModel.emoji).background(Color.clear)
                labels
                if itemModel.shouldShowPicker {
                    Spacer()
                    picker
                }
            }
        )
        .frame(idealWidth: .infinity, maxWidth: .infinity)
        .if(itemModel.shouldShowPicker) {
            $0.padding(10)
        }
        .if(!itemModel.shouldShowPicker) {
            $0.padding(18)
        }
        .background(Color("BlackWhite1"))
    }

    @ViewBuilder
    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(itemModel.title)
                .foregroundColor(.primary)
                .background(Color.clear)
            if let subtitle = itemModel.subtitle {
                Text(subtitle)
                    .foregroundColor(.secondary)
                    .background(Color.clear)
            }
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private var picker: some View {
        Picker("", selection: selectedCityItemBinding) {
            Text(itemModel.nearestCityPickerItem.name)
                .tag(itemModel.nearestCityPickerItem)
            Divider()
            ForEach(itemModel.cityPickerItems) { cityItem in
                Text(cityItem.name)
                    .tag(cityItem)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 90)
        .background(Color.clear)
    }
}

private struct ChecklistItem<Content>: View where Content: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark")
                .foregroundColor(Color.accentColor)
                .if(!isSelected) {
                    $0.hidden()
                }
            label()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .background(Color.clear)
        .onTapGesture {
            action()
        }
    }
}

private struct VPNLocationViewButtons: View {
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Spacer()
            button(text: UserText.vpnLocationCancelButtonTitle, action: onCancel)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(DismissActionButtonStyle())

            button(text: UserText.vpnLocationSubmitButtonTitle, action: onDone)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color.secondary.opacity(0.18))
    }

    @ViewBuilder
    func button(text: String, action: @escaping () -> Void) -> some View {
        Button(text) {
            action()
        }
    }

}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#endif
