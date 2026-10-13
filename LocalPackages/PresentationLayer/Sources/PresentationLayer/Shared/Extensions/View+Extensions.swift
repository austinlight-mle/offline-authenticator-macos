//
// View+Extensions.swift
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

import CommonUtilities
import SwiftUI
#if canImport(UIKit)
import UIKit

public typealias PlatformTextStyle = UIFont.TextStyle
#elseif canImport(AppKit)
import AppKit

public typealias PlatformTextStyle = NSFont.TextStyle
#endif

// MARK: - View builder functions

public extension View {
    /// Applies the given transform if the given value is not nil.
    /// - Parameters:
    ///   - value: The optional value.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the value is not nil.
    @ViewBuilder
    func `if`<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }

    @ViewBuilder
    func ifNoLiquidGlass(transform: (Self) -> some View) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self
        } else {
            transform(self)
        }
    }

    @ViewBuilder
    func resizableSheet() -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            presentationSizing(.form.sticky())
        }
        #else
        self
        #endif
    }

    // periphery:ignore
    /// Show as confirmation dialog on iPhone, as alert on iPad because iPad doesn't support confirmation dialog
    @ViewBuilder
    func adaptiveConfirmationDialog(_ title: LocalizedStringKey,
                                    isPresented: Binding<Bool>,
                                    @ViewBuilder actions: () -> some View) -> some View {
        if AppConstants.isPhone {
            confirmationDialog(title, isPresented: isPresented, actions: actions)
        } else {
            alert(title, isPresented: isPresented, actions: actions)
        }
    }

    func errorMessageAlert(_ message: Binding<String?>) -> some View {
        alert(Text("An error occurred", bundle: .module),
              isPresented: message.mappedToBool(),
              actions: {},
              message: { Text(verbatim: message.wrappedValue ?? "") })
    }

    @ViewBuilder
    func adaptiveSheet(isPresented: Binding<Bool>,
                       isFullScreen: Bool,
                       @ViewBuilder content: @escaping () -> some View) -> some View {
        #if os(iOS)
        if isFullScreen {
            fullScreenCover(isPresented: isPresented, content: content)
        } else {
            sheet(isPresented: isPresented, content: content)
        }
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }

    @ViewBuilder
    func glassButtonStyleIfLiquidGlass() -> some View {
        if #available(iOS 26, macOS 26, *) {
            buttonStyle(.glass)
        } else {
            self
        }
    }
}

// MARK: - Common UI modification tools

public extension View {
    func plainListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
    }

    // periphery:ignore
    func disableAnimations() -> some View {
        transaction { $0.animation = nil }
    }

    func mainBackground() -> some View {
        modifier(MainBackgroundColor())
    }

    func fullScreenMainBackground() -> some View {
        ZStack {
            if #available(iOS 26, macOS 26, *) {
                Color.background
                    .ignoresSafeArea()
            } else {
                Color.clear
                    .mainBackground()
                    .ignoresSafeArea()
            }
            self
        }
    }

    func navigationStackEmbeded() -> some View {
        NavigationStack {
            self
        }
    }

    func textShadow() -> some View {
        shadow(color: .textShadow, radius: 1, x: 0, y: 2)
    }

    func dynamicFont(size: CGFloat = 14,
                     textStyle: PlatformTextStyle = .body,
                     weight: Font.Weight = .regular) -> some View {
        modifier(DynamicFontModifier(size: size, textStyle: textStyle, weight: weight))
    }

    /// Scales every `dynamicFont` below this view with the available width, so the narrow macOS
    /// window and its sheets keep text on one line. iOS keeps Dynamic Type and a scale of 1.
    func fontScaled(referenceWidth: CGFloat = FontScale.referenceWidth) -> some View {
        modifier(FontScaleModifier(referenceWidth: referenceWidth))
    }
}

// MARK: - Non exposed extension

extension View {
    func coloredBackgroundButton(_ shape: some Shape) -> some View {
        background(shape
            .fill(.shadow(.inner(color: .white.opacity(0.25), radius: 2, x: 0, y: 1)))
            .foregroundStyle(LinearGradient(stops:
                [
                    Gradient.Stop(color: Color(red: 0.45, green: 0.31, blue: 1), location: 0.00),
                    Gradient.Stop(color: Color(red: 0.27, green: 0.19, blue: 0.6), location: 1.00)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5, y: 1))))
            .clipShape(shape)
            .shadow(color: Color(red: 0.6, green: 0.37, blue: 1).opacity(0.25), radius: 12, x: 0, y: 1)
            .overlay(shape.stroke(Color.buttonShadowBorder, lineWidth: 0.5))
    }

    /// Dim the background and show a spinner in the middle of the view
    /// - Parameters:
    ///   - isShowing: Whether to show the spinner or not
    ///   - disableWhenShowing: Whether to disable the view while showing the spinner or not
    ///   - size: The size of the spinner
    func showSpinner(_ isShowing: Bool,
                     disableWhenShowing: Bool = true,
                     size: ControlSize = .large) -> some View {
        overlay {
            if isShowing {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .controlSize(size)
            }
        }
        .disabled(disableWhenShowing && isShowing)
        .animation(.default, value: isShowing)
    }

    /// Applies `.searchFocused` modifier only on iOS 18+
    @ViewBuilder
    func searchFocusable(_ isFocused: FocusState<Bool>.Binding) -> some View {
        if #available(iOS 18, macOS 15.0, visionOS 2.0, *) {
            searchFocused(isFocused)
        } else {
            self
        }
    }

    func toggleAccessibilityLabel(_ label: String, _ state: String) -> some View {
        accessibilityHint("You can toggle this option by clicking on the toggle button to the right of the row.")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label + state)
    }
}

extension View {
    /// `textInputAutocapitalization(.never)` on iOS, no-op on macOS where the modifier does not exist.
    @ViewBuilder
    func disableAutocapitalization() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    /// `textInputAutocapitalization(.characters)` on iOS, no-op on macOS.
    @ViewBuilder
    func capitalizeCharacters() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.characters)
        #else
        self
        #endif
    }

    /// Inset grouped list on iOS, inset list on macOS (where `insetGrouped` does not exist).
    @ViewBuilder
    func groupedListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        listStyle(.inset)
        #endif
    }

    /// Shows the sheet grabber on iOS; macOS sheets have none.
    @ViewBuilder
    func sheetDragIndicator() -> some View {
        #if os(iOS)
        presentationDragIndicator(.visible)
        #else
        self
        #endif
    }

    @ViewBuilder
    func asciiCapableKeyboard() -> some View {
        #if os(iOS)
        if AppConstants.isMobile {
            keyboardType(.asciiCapable)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func paddingIfNotLiquidGlass(_ edges: Edge.Set = [.all],
                                 _ appliedPadding: CGFloat = DesignConstant.padding) -> some View {
        if #unavailable(iOS 26, macOS 26) {
            padding(edges, appliedPadding)
        } else {
            self
        }
    }
}

extension ToolbarItemPlacement {
    /// Leading "close" placement: navigation bar on iOS, cancellation slot on macOS.
    static var leadingBarItem: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .cancellationAction
        #endif
    }

    /// Trailing action placement: navigation bar on iOS, primary action slot on macOS.
    static var trailingBarItem: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}

// MARK: - Width based font scaling

public enum FontScale {
    /// Width at which the native sizes apply unchanged.
    public static let referenceWidth: CGFloat = 320
    public static let minimum: CGFloat = 0.9
    public static let maximum: CGFloat = 1.0

    public static func scale(forWidth width: CGFloat, referenceWidth: CGFloat = referenceWidth) -> CGFloat {
        guard width > 0 else { return 1 }
        return min(maximum, max(minimum, width / referenceWidth))
    }
}

private struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

public extension EnvironmentValues {
    /// Multiplier applied to `dynamicFont` sizes (macOS only; see `fontScaled`).
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

private struct DynamicFontModifier: ViewModifier {
    @Environment(\.fontScale) private var fontScale
    let size: CGFloat
    let textStyle: PlatformTextStyle
    let weight: Font.Weight

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content.font(.system(size: UIFontMetrics(forTextStyle: textStyle).scaledValue(for: size), weight: weight))
        #else
        // macOS: the iPhone design size is far too big for a desktop window, so use the
        // size AppKit assigns to the text style (title1 22, title3 15, body 13, footnote 10...).
        let nativeSize = NSFont.preferredFont(forTextStyle: textStyle).pointSize
        content.font(.system(size: (nativeSize * fontScale).rounded(), weight: weight))
        #endif
    }
}

private struct FontScaleModifier: ViewModifier {
    let referenceWidth: CGFloat
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .environment(\.fontScale, scale)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
                let newScale = FontScale.scale(forWidth: width, referenceWidth: referenceWidth)
                if abs(newScale - scale) > 0.01 {
                    scale = newScale
                }
            }
        #else
        content
        #endif
    }
}
