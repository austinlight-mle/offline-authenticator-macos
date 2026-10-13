//
//  View+Extensions.swift
//  
//
//  Created by Martin Lukacs on 08/07/2023.
//

import SwiftUI

public extension View {

        /// Present `AlertToast`.
        /// - Parameters:
        ///   - toast: Binding<SimpleToast>
        /// - Returns: A toast
        func toast(toast: Binding<SimpleToast?>,
                   tapToDismiss: Bool = true,
                   onTap: (() -> ())? = nil,
                   completion: (() -> ())? = nil) -> some View {
            modifier(SimpleToastModifier(toast: toast,
                                         tapToDismiss: tapToDismiss,
                                         onTap: onTap,
                                         completion: completion))
        }
}

extension View {

    /// Choose the alert background
    /// - Parameter color: Some Color, if `nil` return `.black`/`.white` depends on system theme
    /// - Returns: some View
     func textColor(_ color: Color? = nil) -> some View{
        modifier(TextForegroundModifier(color: color))
    }
}
