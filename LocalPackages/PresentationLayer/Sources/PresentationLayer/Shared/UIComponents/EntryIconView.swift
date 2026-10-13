//
// EntryIconView.swift
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

import DataLayer
import FactoryKit
import Models
import SDWebImageSwiftUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What should be drawn for an entry, resolved from the user override and the issuer information.
enum ResolvedEntryIcon: Hashable {
    case brand(BrandIcon)
    case symbol(name: String, colorHex: String?)
    case image(Data)
    case remote(URL, fallbackLetter: String)
    case letter(String)

    static func resolve(override: EntryIcon?,
                        issuerInfo: AuthIssuerInfo?,
                        letter: String,
                        catalog: any BrandIconCataloging) -> ResolvedEntryIcon {
        if let override {
            switch override {
            case let .brand(id):
                if let brand = catalog.icon(id: id) {
                    return .brand(brand)
                }

            case let .symbol(name, colorHex):
                return .symbol(name: name, colorHex: colorHex)

            case let .image(data):
                return .image(data)
            }
        }

        // Offline first: a bundled vector icon beats a remote favicon.
        let brand = issuerInfo?.brandIconId.flatMap { catalog.icon(id: $0) }
        if let brand, brand.hasVectorImage {
            return .brand(brand)
        }
        if let iconUrl = issuerInfo?.iconUrl, !iconUrl.isEmpty, let url = URL(string: iconUrl) {
            return .remote(url, fallbackLetter: brand?.displayMonogram ?? letter)
        }
        if let brand {
            return .brand(brand)
        }
        return .letter(letter)
    }
}

/// Square icon tile shared by the entry cells, the icon picker and the group editor.
struct EntryIconView: View, @preconcurrency Equatable {
    @Environment(\.colorScheme) private var colorScheme

    let icon: ResolvedEntryIcon
    var size: CGFloat = 34
    var cornerRadius: CGFloat = 8

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.icon == rhs.icon && lhs.size == rhs.size
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: -0.25)
                .stroke(strokeColor, lineWidth: 0.5))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch icon {
        case let .brand(brand):
            brandTile(brand)

        case let .symbol(name, colorHex):
            let tint = colorHex.flatMap { Color(hex: $0) } ?? Color(hex: IconPalette.default) ?? .accentColor
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .foregroundStyle(tint)
                .padding(size * 0.2)
                .frame(width: size, height: size)
                .background(tileBackground)

        case let .image(data):
            if let image = PlatformImage.image(from: data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .background(.white)
            } else {
                letterTile("?")
            }

        case let .remote(url, fallbackLetter):
            WebImage(url: url) { image in
                image
                    .resizable()
                    .background(.white)
            } placeholder: {
                letterTile(fallbackLetter)
            }
            .transition(.fade(duration: 0.5))
            .frame(width: size, height: size, alignment: .center)

        case let .letter(letter):
            letterTile(letter)
        }
    }

    @ViewBuilder
    private func brandTile(_ brand: BrandIcon) -> some View {
        let brandColor = Color(hex: brand.hex) ?? .accentColor
        let lightBrand = (Color.luminance(hex: brand.hex) ?? 0) > 0.72
        if let imageName = brand.image {
            if brand.multicolor {
                Image(imageName, bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)
                    .frame(width: size, height: size)
                    .background(.white)
            } else {
                Image(imageName, bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(brandColor)
                    .padding(size * 0.18)
                    .frame(width: size, height: size)
                    .background(lightBrand ? Color(red: 0.11, green: 0.1, blue: 0.12) : .white)
            }
        } else {
            Text(verbatim: brand.displayMonogram)
                .font(.system(size: brand.displayMonogram.count > 2 ? size * 0.34 : size * 0.46,
                              weight: .bold,
                              design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(lightBrand ? Color(red: 0.11, green: 0.1, blue: 0.12) : .white)
                .padding(size * 0.1)
                .frame(width: size, height: size)
                .background(brandColor)
        }
    }

    private func letterTile(_ letter: String) -> some View {
        Text(verbatim: letter)
            .font(.system(size: size * 0.68, weight: .medium))
            .minimumScaleFactor(0.5)
            .foregroundStyle(LinearGradient(gradient:
                Gradient(colors: [
                    Color(red: 109 / 255, green: 74 / 255, blue: 255 / 255), // #6D4AFF
                    Color(red: 181 / 255, green: 120 / 255, blue: 217 / 255), // #B578D9
                    Color(red: 249 / 255, green: 175 / 255, blue: 148 / 255), // #F9AF94
                    Color(red: 255 / 255, green: 213 / 255, blue: 128 / 255) // #FFD580
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
            .padding(.horizontal, 3)
            .padding(.vertical, 4)
            .frame(width: size, height: size, alignment: .center)
            .background(tileBackground)
    }

    private var tileBackground: Color {
        colorScheme.isLight ? Color(red: 0.95, green: 0.93, blue: 0.97).opacity(0.8) : .black.opacity(0.3)
    }

    private var strokeColor: Color {
        colorScheme.isLight ? Color(red: 0.32, green: 0.16, blue: 0.47).opacity(0.3) : .black.opacity(0)
    }
}

/// Minimal cross platform bitmap helpers used for user provided icons.
enum PlatformImage {
    static func image(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}
