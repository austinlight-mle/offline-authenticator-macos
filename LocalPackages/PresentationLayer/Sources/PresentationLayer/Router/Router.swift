//
// Router.swift
// Altosec Authenticator - Created on 10/02/2025.
// Copyright (c) 2025 Proton Technologies AG
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

// periphery:ignore:all

import Models
import SwiftUI

enum RouterDestination: Hashable {
    case backup
    case iCloudSync
}

public enum SheetDestination: Hashable, Identifiable {
    public var id: Self {
        self
    }

    case createEditEntry(EntryUiModel?, groupId: String? = nil)
    case settings
    case groups
    case entryIcon(EntryUiModel)
}

public enum FullScreenDestination: Hashable, Identifiable {
    public var id: Self {
        self
    }

    #if os(iOS)
    case qrCodeScanner
    #else
    /// Placeholder so the enum is inhabited on platforms without a camera scanner.
    case none
    #endif
}

@Observable
final class Router {
    var path = NavigationPath()

    var presentedSheet: SheetDestination?
    var presentedFullscreenSheet: FullScreenDestination?

    var noSheetDisplayed: Bool {
        presentedSheet == nil && presentedFullscreenSheet == nil
    }

    func navigate(to: RouterDestination) {
        path.append(to)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    func back(to numberOfScreen: Int = 1) {
        path.removeLast(numberOfScreen)
    }
}

struct RouterEmbeded: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: RouterDestination.self) { destination in
                switch destination {
                case .backup:
                    BackUpView()

                case .iCloudSync:
                    ICloudSyncView()
                }
            }
    }
}

public extension View {
    var routingProvided: some View {
        modifier(RouterEmbeded())
    }

    func sheetDestinations(_ item: Binding<SheetDestination?>) -> some View {
        sheet(item: item) { destination in
            switch destination {
            case let .createEditEntry(entry, groupId):
                CreateEditEntryView(entry: entry, initialGroupId: groupId)
                    .resizableSheet()

            case .settings:
                SettingsView()
                    .resizableSheet()

            case .groups:
                GroupsView()
                    .resizableSheet()

            case let .entryIcon(entry):
                EntryIconPickerSheet(entry: entry)
                    .resizableSheet()
            }
        }
    }

    #if os(iOS)
    func fullScreenDestination(_ item: Binding<FullScreenDestination?>) -> some View {
        fullScreenCover(item: item) { destination in
            switch destination {
            case .qrCodeScanner:
                ScannerView()
            }
        }
    }
    #endif
}
