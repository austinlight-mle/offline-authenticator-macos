//
// EntriesToolbarContent.swift
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

struct EntriesToolbarContent: ToolbarContent {
    let sortOption: SortOption
    let setSortOption: (SortOption) -> Void
    @Binding var presentedSheet: SheetDestination?
    let searchBarAlignment: VerticalAlignment
    let noEntries: Bool
    let handleAddNewCode: () -> Void

    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: titlePlacement) {
            Text(verbatim: "Altosec Authenticator")
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 28, textStyle: .title1, weight: .bold)
                .minimumScaleFactor(0.75)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu(content: {
                sortOptions
            }, label: {
                Group {
                    if #available(iOS 26, macOS 26, *) {
                        Image(systemName: "line.3.horizontal.decrease")
                    } else {
                        Image(.sortButton)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                    }
                }
                .impactHaptic()
                .accessibilityLabel("Sort options")
            })
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presentedSheet = .settings
            } label: {
                if #available(iOS 26, macOS 26, *) {
                    Image(systemName: "gearshape.fill")
                } else {
                    Image(.settingsGear)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
            .adaptiveButtonStyle()
            .impactHaptic()
            .accessibilityLabel("Settings")
        }
        #else
        // Native macOS: the window title carries the app name, so the toolbar only holds actions.
        ToolbarItemGroup(placement: .primaryAction) {
            Menu(content: {
                sortOptions
            }, label: {
                Image(systemName: "line.3.horizontal.decrease")
            })
            .help(Text("Sort options", bundle: .module))
            .accessibilityLabel("Sort options")

            Button {
                presentedSheet = .groups
            } label: {
                Image(systemName: "folder.badge.gearshape")
            }
            .help(Text("Manage groups", bundle: .module))
            .accessibilityLabel("Manage groups")

            Button(action: handleAddNewCode) {
                Image(systemName: "plus")
            }
            .help(Text("Create new code", bundle: .module))
            .accessibilityLabel("Create new code")
            .keyboardShortcut("n")

            Button {
                presentedSheet = .settings
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .help(Text("Settings", bundle: .module))
            .accessibilityLabel("Settings")
            .keyboardShortcut(",")
        }
        #endif

        #if os(iOS)
        if #available(iOS 26, *),
           !noEntries,
           AppConstants.adjustableSearchBarPosition {
            if searchBarAlignment == .bottom {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button(action: handleAddNewCode) {
                        Label("Create new code", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Create new code")
                    .buttonStyle(.glassProminent)
                    .impactHaptic()
                }
            } else {
                DefaultToolbarItem(kind: .search)
            }
        }
        #endif
    }

    @ViewBuilder
    private var sortOptions: some View {
        ForEach(SortOption.allCases, id: \.self) { option in
            Button(action: {
                setSortOption(option)
            }, label: {
                Toggle(isOn: .constant(option == sortOption)) {
                    Text(option.description, bundle: .module)
                }
            })

            switch option {
            case .creationDateDesc, .issuerDesc, .manual:
                Divider()

            default:
                EmptyView()
            }
        }
    }

    #if os(iOS)
    private var titlePlacement: ToolbarItemPlacement {
        if #available(iOS 26, macOS 26, *) {
            .principal
        } else {
            ProcessInfo.processInfo.isiOSAppOnMac ? .topBarLeading : .principal
        }
    }
    #endif
}
