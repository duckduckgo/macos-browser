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

import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions

struct VPNLocationView: View {
    @StateObject var model: VPNLocationViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(UserText.vpnLocationListTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    VStack(alignment: .leading, spacing: 20) {
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
            .onDisappear {
                Task {
                    await model.onViewDisappered()
                }
            }
        }
        .frame(width: 624, height: 640, alignment: .top)
    }

    @ViewBuilder
    private var nearestSection: some View {
        PreferencePaneSection {
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
                Image(.location16Solid)
                    .padding(4)
                    .foregroundColor(Color(.blackWhite100).opacity(0.9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(UserText.vpnLocationNearestAvailable)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Text(UserText.vpnLocationNearestAvailableSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        )
        .roundedBorder()
    }

    @ViewBuilder
    private var countriesSection: some View {
        PreferencePaneSection {
            Text(UserText.vpnLocationCustomSectionTitle)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            switch model.state {
            case .loading:
                listLoadingView
            case .loaded(let countryItems):
                countriesList(countries: countryItems)
            }
        }
    }

    private var listLoadingView: some View {
        ZStack(alignment: .center) {
            EmptyView()
        }
        .frame(height: 370)
        .frame(idealWidth: .infinity, maxWidth: .infinity)
        .roundedBorder()
    }

    private func countriesList(countries: [VPNCountryItemModel]) -> some View {
        VStack(spacing: 0) {
            ForEach(countries) { country in
                if !country.isFirstItem {
                    Rectangle()
                        .fill(Color(.blackWhite10))
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
                Text(itemModel.emoji)
                    .font(.system(size: 16))
                    .padding(4)
                labels
                if itemModel.shouldShowPicker {
                    Spacer()
                    picker
                }
            }
        )
        .frame(idealWidth: .infinity, maxWidth: .infinity)
        .background(Color(.blackWhite1))
    }

    @ViewBuilder
    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(itemModel.title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .background(Color.clear)
            if let subtitle = itemModel.subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
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
        .foregroundColor(.accentColor)
        .pickerStyle(.menu)
        .frame(width: 120)
        .background(Color.clear)
    }
}

private struct ChecklistItem<Content>: View where Content: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .if(!isSelected) {
                        $0.hidden()
                    }
                label()
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .frame(height: 52)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

private struct VPNLocationViewButtons: View {
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.blackWhite10))
                .frame(height: 1)
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
            .background(Color.blackWhite1)
        }
    }

    @ViewBuilder
    func button(text: String, action: @escaping () -> Void) -> some View {
        Button(text) {
            action()
        }
    }

}
