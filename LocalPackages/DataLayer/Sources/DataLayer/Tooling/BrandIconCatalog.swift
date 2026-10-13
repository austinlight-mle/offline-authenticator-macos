//
// BrandIconCatalog.swift
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

public protocol BrandIconCataloging: Sendable {
    /// All bundled brand icons, sorted by title.
    var icons: [BrandIcon] { get }
    func icon(id: String) -> BrandIcon?
    /// Finds the bundled brand icon best matching a TOTP issuer, optionally helped by the
    /// domain resolved by the Rust issuer mapper.
    func match(issuer: String, domain: String?) -> BrandIcon?
    /// Case insensitive search on title and aliases, used by the icon picker.
    func search(_ query: String) -> [BrandIcon]
}

/// Loads `BrandIcons.json` bundled with the data layer and resolves issuers to brand icons.
public final class BrandIconCatalog: BrandIconCataloging {
    public let icons: [BrandIcon]
    private let iconsById: [String: BrandIcon]
    private let iconsByKey: [String: BrandIcon]

    private struct Catalog: Decodable {
        let icons: [BrandIcon]
    }

    /// Loads the catalog from `bundle`, defaulting to the data layer's resource bundle.
    public convenience init(bundle: Bundle? = nil) {
        var icons: [BrandIcon] = []
        let bundle = bundle ?? Bundle.module
        if let url = bundle.url(forResource: "BrandIcons", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let catalog = try? JSONDecoder().decode(Catalog.self, from: data) {
            icons = catalog.icons
        }
        self.init(icons: icons)
    }

    public init(icons: [BrandIcon]) {
        let sorted = icons.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        self.icons = sorted
        iconsById = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var byKey = [String: BrandIcon]()
        // Ids and titles win over aliases when several brands share a key.
        for icon in sorted {
            for key in [icon.id.brandMatchingKey, icon.title.brandMatchingKey] where !key.isEmpty {
                byKey[key] = byKey[key] ?? icon
            }
        }
        for icon in sorted {
            for alias in icon.aliases {
                let key = alias.brandMatchingKey
                guard !key.isEmpty else { continue }
                byKey[key] = byKey[key] ?? icon
            }
        }
        iconsByKey = byKey
    }

    public func icon(id: String) -> BrandIcon? {
        iconsById[id]
    }

    public func match(issuer: String, domain: String?) -> BrandIcon? {
        let issuerKey = issuer.brandMatchingKey
        if !issuerKey.isEmpty, let icon = iconsByKey[issuerKey] {
            return icon
        }

        if let domain, let icon = matchDomain(domain) {
            return icon
        }

        // Multi word issuers such as "Amazon Web Services": try meaningful words.
        let tokens = issuer.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for token in tokens {
            let key = String(token).brandMatchingKey
            guard key.count >= 4, let icon = iconsByKey[key] else { continue }
            return icon
        }
        return nil
    }

    public func search(_ query: String) -> [BrandIcon] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return icons }
        let key = trimmed.brandMatchingKey
        return icons.filter { icon in
            icon.title.localizedCaseInsensitiveContains(trimmed)
                || icon.id.contains(key)
                || icon.aliases.contains { $0.brandMatchingKey.contains(key) }
        }
    }

    private func matchDomain(_ domain: String) -> BrandIcon? {
        let fullKey = domain.brandMatchingKey
        if !fullKey.isEmpty, let icon = iconsByKey[fullKey] {
            return icon
        }
        if let label = Self.registrableLabel(of: domain) {
            return iconsByKey[label.brandMatchingKey]
        }
        return nil
    }

    private static let secondLevelSuffixes: Set<String> = ["co", "com", "net", "org", "gov", "edu", "ac", "or", "ne"]

    /// `accounts.google.com` → `google`, `example.co.uk` → `example`.
    static func registrableLabel(of domain: String) -> String? {
        var host = domain.lowercased()
        if let url = URL(string: host.contains("://") ? host : "https://\(host)"), let urlHost = url.host {
            host = urlHost
        }
        let labels = host.split(separator: ".").map(String.init).filter { !$0.isEmpty }
        guard labels.count >= 2 else { return labels.first }
        let secondToLast = labels[labels.count - 2]
        if labels.count >= 3, secondLevelSuffixes.contains(secondToLast), labels[labels.count - 1].count == 2 {
            return labels[labels.count - 3]
        }
        return secondToLast
    }
}
