//
// CreateEditEntryViewModel.swift
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
//

import AuthenticatorRustCore
import CommonUtilities
import FactoryKit
import Foundation
import Macro
import Models

@Observable
final class CreateEditEntryViewModel {
    var name = ""
    var secret = ""
    var issuer = ""
    var period: Int = 30
    var digits: Int = 6
    var algo: TotpAlgorithm = .sha1
    var type: TotpType = .totp
    var note = ""
    var shouldDismiss = false
    var errorMessage: String?
    var saving = false
    var groupId: String?
    var icon: EntryIcon?

    var supportedDigits: [Int] = AppConstants.EntryOptions.supportedDigits
    var supportedPeriod: [Int] = AppConstants.EntryOptions.supportedPeriod

    var canSave: Bool {
        !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    var alertService

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.totpIssuerMapper)
    private var totpIssuerMapper

    @ObservationIgnored
    private let entry: EntryUiModel?

    var isEditing: Bool {
        entry != nil
    }

    var groups: [EntryGroup] {
        entryDataService.groups
    }

    var selectedGroup: EntryGroup? {
        guard let groupId else { return nil }
        return groups.first { $0.id == groupId }
    }

    /// Issuer information matching what is currently typed, used to preview the automatic icon.
    var previewIssuerInfo: AuthIssuerInfo? {
        let trimmedIssuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIssuer.isEmpty else { return nil }
        return totpIssuerMapper.lookup(issuer: trimmedIssuer)
    }

    var previewLetter: String {
        let source = issuer.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
        return source.first?.uppercased() ?? "-"
    }

    init(entry: EntryUiModel?, initialGroupId: String? = nil) {
        self.entry = entry
        groupId = initialGroupId
        setUp(entry: entry)
    }

    func trimInputs() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() {
        trimInputs()
        guard canSave else { return }

        let params: EntryParameters = if type == .totp {
            .totp(TotpParams(name: name,
                             secret: secret,
                             issuer: issuer,
                             period: period,
                             digits: digits,
                             algorithm: algo,
                             note: note.nilIfEmpty))
        } else {
            .steam(SteamParams(name: name, secret: secret, note: note.nilIfEmpty))
        }
        let customization = EntryCustomization(groupId: groupId, icon: icon)
        Task { [weak self] in
            guard let self else { return }

            defer { saving = false }
            do {
                saving = true
                if let entry {
                    try await entryDataService.updateAndRefreshEntry(for: entry.id,
                                                                     with: params,
                                                                     customization: customization)
                } else {
                    try await entryDataService.insertAndRefreshEntry(from: params, customization: customization)
                }
                shouldDismiss = true
            } catch {
                if let authError = error as? AuthenticatorRustCore.AuthenticatorError {
                    switch authError {
                    case .InvalidSecret:
                        errorMessage = #localized("Invalid secret: %@", bundle: .module, authError.message)

                    default:
                        errorMessage = authError.message
                    }
                } else {
                    handle(error)
                }
            }
        }
    }
}

private extension CreateEditEntryViewModel {
    func setUp(entry: EntryUiModel?) {
        guard let uiEntry = entry else { return }

        groupId = uiEntry.groupId
        icon = uiEntry.iconOverride

        switch uiEntry.orderedEntry.entry.type {
        case .steam:
            name = uiEntry.orderedEntry.entry.name
            secret = uiEntry.orderedEntry.entry.secret
            type = .steam

        case .totp:
            if let params = try? entryDataService.getTotpParams(entry: uiEntry.orderedEntry.entry) {
                name = params.name
                secret = params.secret
                issuer = params.issuer
                if let newPeriod = params.period {
                    period = newPeriod
                    supportedPeriod.appendIfNotExists(newPeriod)
                    supportedPeriod.sort()
                }

                if let newDigits = params.digits {
                    digits = newDigits
                    supportedDigits.appendIfNotExists(newDigits)
                    supportedDigits.sort()
                }
                algo = params.algorithm ?? .sha1
                note = params.note ?? ""
            }
        }
    }

    func handle(_ error: Error) {
        alertService.showError(error, mainDisplay: false, action: nil)
    }
}

extension AuthenticatorError {
    var message: String {
        switch self {
        case let .CodeGenerationError(msg),
             let .ImportBadContent(msg),
             let .ImportBadPassword(msg),
             let .ImportDecryptionFailed(msg),
             let .ImportMissingPassword(msg),
             let .InvalidName(msg),
             let .InvalidSecret(msg),
             let .NoEntries(msg),
             let .ParseError(msg),
             let .SerializationError(msg),
             let .Unknown(msg),
             let .UnsupportedUri(msg):
            msg
        }
    }
}
