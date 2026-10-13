//
// EntryCustomizationTests.swift
// Altosec Authenticator - Created on 12/10/2026.
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

import Foundation
import Models
import Testing

struct EntryCustomizationTests {
    private func makeUiModel(customization: EntryCustomization?) -> EntryUiModel {
        let entry = Entry(id: "id", name: "name", uri: "otpauth://totp/Test?secret=ABCDEFGH",
                          period: 30, issuer: "Issuer", secret: "ABCDEFGH", type: .totp, note: nil)
        let ordered = OrderedEntry(entry: entry, keyId: nil, remoteId: nil, order: 0,
                                   modifiedTime: 1, revision: 0, contentFormatVersion: 1)
        return EntryUiModel(orderedEntry: ordered,
                            code: Code(current: "123456", next: "654321", entry: entry),
                            issuerInfo: nil,
                            customization: customization)
    }

    @Test("Empty customization is normalised to nil")
    func emptyCustomizationIsDropped() {
        let model = makeUiModel(customization: EntryCustomization())
        #expect(model.customization == nil)
        #expect(model.groupId == nil)
        #expect(model.iconOverride == nil)
    }

    @Test("Customization survives code, order and remote updates")
    func customizationIsPreserved() {
        let customization = EntryCustomization(groupId: "work",
                                               icon: .symbol(name: "briefcase.fill", colorHex: "6D4AFF"))
        var model = makeUiModel(customization: customization)
        model = model.updateCode(Code(current: "000000", next: "111111", entry: model.orderedEntry.entry))
        model = model.updateOrder(4)
        model = model.updateRemoteInfos("remote")
        #expect(model.groupId == "work")
        #expect(model.iconOverride == .symbol(name: "briefcase.fill", colorHex: "6D4AFF"))
    }

    @Test("Icon overrides round trip through JSON")
    func iconCodable() throws {
        let icons: [EntryIcon] = [
            .brand("google"),
            .symbol(name: "star.fill", colorHex: nil),
            .image(Data([0x89, 0x50, 0x4E, 0x47]))
        ]
        for icon in icons {
            let data = try JSONEncoder().encode(icon)
            let decoded = try JSONDecoder().decode(EntryIcon.self, from: data)
            #expect(decoded == icon)
        }
    }

    @Test("Decoding an EntryUiModel without customization keeps backwards compatibility")
    func decodingWithoutCustomization() throws {
        let model = makeUiModel(customization: nil)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Any] ?? [:]
        json.removeValue(forKey: "customization")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(EntryUiModel.self, from: data)
        #expect(decoded.customization == nil)
        #expect(decoded.id == model.id)
    }

    @Test("Groups sort by order then name")
    func groupSorting() {
        let groups = [
            EntryGroup(id: "c", name: "Zeta", order: 1),
            EntryGroup(id: "a", name: "beta", order: 0),
            EntryGroup(id: "b", name: "Alpha", order: 1)
        ]
        #expect(groups.sortedByOrder.map(\.id) == ["a", "b", "c"])
    }

    @Test("Brand matching key strips punctuation and case")
    func brandMatchingKey() {
        #expect("Proton Mail".brandMatchingKey == "protonmail")
        #expect("x.com".brandMatchingKey == "xcom")
        #expect("  GitHub-Enterprise ".brandMatchingKey == "githubenterprise")
    }
}
