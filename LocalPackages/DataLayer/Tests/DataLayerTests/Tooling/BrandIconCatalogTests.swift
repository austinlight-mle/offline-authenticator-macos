//
// BrandIconCatalogTests.swift
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

@testable import DataLayer
import Models
import Testing

struct BrandIconCatalogTests {
    private let catalog = BrandIconCatalog(icons: [
        BrandIcon(id: "google", title: "Google", hex: "4285F4", aliases: ["gmail"], image: "brand_google"),
        BrandIcon(id: "x", title: "X", hex: "000000", aliases: ["twitter"], image: "brand_x"),
        BrandIcon(id: "amazon", title: "Amazon", hex: "FF9900", aliases: ["aws"], monogram: "a"),
        BrandIcon(id: "protonmail", title: "Proton Mail", hex: "6D4AFF", image: "brand_protonmail")
    ])

    @Test("Matches issuer by title, id and alias ignoring case and punctuation")
    func matchesIssuer() {
        #expect(catalog.match(issuer: "Google", domain: nil)?.id == "google")
        #expect(catalog.match(issuer: "GMAIL", domain: nil)?.id == "google")
        #expect(catalog.match(issuer: "Proton-Mail", domain: nil)?.id == "protonmail")
        #expect(catalog.match(issuer: "Twitter", domain: nil)?.id == "x")
    }

    @Test("Falls back to the resolved domain")
    func matchesDomain() {
        #expect(catalog.match(issuer: "Some unknown name", domain: "accounts.google.com")?.id == "google")
        #expect(catalog.match(issuer: "Unknown", domain: "https://www.amazon.co.uk")?.id == "amazon")
        #expect(catalog.match(issuer: "Unknown", domain: "example.org") == nil)
    }

    @Test("Multi word issuers match on a meaningful word but short words never match")
    func matchesTokens() {
        #expect(catalog.match(issuer: "Amazon Web Services", domain: nil)?.id == "amazon")
        #expect(catalog.match(issuer: "Project X", domain: nil) == nil)
    }

    @Test("Search filters on title and aliases")
    func search() {
        #expect(catalog.search("").count == 4)
        #expect(catalog.search("prot").map(\.id) == ["protonmail"])
        #expect(catalog.search("twit").map(\.id) == ["x"])
    }

    @Test("Bundled catalog loads and contains well known brands")
    func bundledCatalog() {
        let bundled = BrandIconCatalog()
        #expect(bundled.icons.count > 200)
        #expect(bundled.icon(id: "google")?.hasVectorImage == true)
        #expect(bundled.icon(id: "github")?.hasVectorImage == true)
        #expect(bundled.icon(id: "microsoft") != nil)
        #expect(bundled.match(issuer: "Microsoft", domain: "login.microsoftonline.com")?.id == "microsoft")
    }
}
