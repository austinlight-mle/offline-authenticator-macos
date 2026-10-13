//
// EntriesEmptyStateView.swift
// Altosec Authenticator - Created on 17/02/2026.
// Copyright (c) 2026 Proton Technologies AG
//
// This file is part of Altosec Authenticator.
//
// Altosec Authenticator is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Altosec Authenticator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Altosec Authenticator. If not, see https://www.gnu.org/licenses/.

import CommonUtilities
import Models
import SwiftUI

struct EntriesEmptyStateView: View {
    let dataState: DataState<[EntryUiModel]>
    let query: String
    let entriesEmpty: Bool
    var selectedGroupName: String?
    let handleAddNewCode: () -> Void
    @Binding var showImportOptions: Bool
    let reloadData: () -> Void
    var clearGroupFilter: () -> Void = {}

    var body: some View {
        switch dataState {
        case .loading:
            ProgressView()

        case let .loaded(entries):
            if entries.isEmpty {
                noCodesView
            } else if entriesEmpty, !query.isEmpty {
                noSearchResultsView
            } else if entriesEmpty, let selectedGroupName {
                noGroupEntriesView(groupName: selectedGroupName)
            }

        case let .failed(error):
            RetryableErrorView(tintColor: .danger, error: error, onRetry: reloadData)
        }
    }

    private var noCodesView: some View {
        ContentUnavailableView {
            Image(.noCodes)
                .resizable()
                .scaledToFit()
                .frame(width: 210, height: 120)
                .padding(.bottom, 16)
                .accessibilityHidden(true)
        } description: {
            VStack(spacing: 8) {
                Text("No codes yet", bundle: .module)
                    .dynamicFont(size: 24, textStyle: .title2, weight: .semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .opacity(0.9)
                Text("Protect your accounts with an extra layer of security.", bundle: .module)
                    .dynamicFont(size: 18, textStyle: .title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.textWeak)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)

                VStack(spacing: 16) {
                    let maxWidth: CGFloat = AppConstants.isPhone ? .infinity : 450
                    CapsuleButton(title: "Create new code",
                                  textColor: .white,
                                  style: .borderedFilled,
                                  maxWidth: maxWidth,
                                  action: handleAddNewCode)
                        .impactHaptic()
                    CapsuleButton(title: "Import codes",
                                  textColor: .textNorm,
                                  style: .bordered,
                                  maxWidth: maxWidth,
                                  action: { showImportOptions.toggle() })
                        .impactHaptic()
                }
                .frame(minWidth: 262, maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
        } actions: {}
            .refreshable { reloadData() }
            .importingService($showImportOptions, context: .homepage)
    }

    private func noGroupEntriesView(groupName: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundStyle(.textWeak)
            Text("No codes in \"\(groupName)\" yet", bundle: .module)
                .dynamicFont(size: 22, textStyle: .title2, weight: .semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.textNorm)
            Text("Add a code from this group or move existing codes here from their menu.", bundle: .module)
                .dynamicFont(size: 16, textStyle: .body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.textWeak)
            CapsuleButton(title: "Create new code",
                          textColor: .white,
                          style: .borderedFilled,
                          maxWidth: 260,
                          action: handleAddNewCode)
            CapsuleButton(title: "Show all codes",
                          textColor: .textNorm,
                          style: .bordered,
                          maxWidth: 260,
                          action: clearGroupFilter)
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, DesignConstant.padding * 2)
    }

    private var noSearchResultsView: some View {
        VStack {
            Spacer()
            Text("Couldn't find any entries corresponding to your search criteria \"\(query)\"",
                 bundle: .module)
                .dynamicFont(size: 24, textStyle: .title2, weight: .semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.textNorm)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Try searching using different spelling or keywords", bundle: .module)
                .dynamicFont(size: 18, textStyle: .title3)
                .foregroundStyle(.textWeak)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
    }
}
