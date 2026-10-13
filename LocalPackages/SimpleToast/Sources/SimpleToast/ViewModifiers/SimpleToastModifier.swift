//
//  SimpleToastModifier.swift
//  
//
//  Created by Martin Lukacs on 09/07/2023.
//

import SwiftUI

public struct SimpleToastModifier: ViewModifier {
    @State private var workItem: DispatchWorkItem?
    @State private var tapToDismiss: Bool = true
    @Binding private var toast: SimpleToast?

    ///Completion block returns `true` after dismiss
    private let onTap: (() -> ())?
    private let completion: (() -> ())?

    init(toast: Binding<SimpleToast?>,
         tapToDismiss: Bool = true,
         onTap: (() -> Void)? = nil,
         completion: (() -> Void)? = nil) {
        self._toast = toast
        // Vendored fix: assign the State wrapper so Swift 6.4 accepts the initialiser order.
        self._tapToDismiss = State(initialValue: tapToDismiss)
        self.onTap = onTap
        self.completion = completion
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: toast?.displayMode.alignment ?? .bottom) {
                mainContainer
                    .animation(.easeInOut, value: toast)
                    .onTapGesture {
                        onTap?()
                        if tapToDismiss {
                            dismissAlert()
                        }
                    }
                    .onDisappear {
                        completion?()
                    }
            }
            .onChange(of: toast) {
              showToast()
            }
    }
}

private extension SimpleToastModifier {
    @ViewBuilder
    var mainContainer: some View {
        if let toast {
            toast.body
                .offset(y: toast.offsetY)
                .transition(toast.displayMode.transition)
        }
    }

    func showToast() {
        guard let toast, workItem == nil else {
            return
        }

        if toast.configuration.hapticFeedback {
            hapticFeedback()
        }

        if toast.configuration.type == .loading {
            tapToDismiss = false
        }
        
        guard toast.configuration.duration > 0 else {
            return
        }

        workItem?.cancel()
        
        let task = DispatchWorkItem {
            dismissAlert()
        }
        workItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + toast.configuration.duration, execute: task)
    }

    func dismissAlert() {
        withAnimation {
            toast = nil
        }
        workItem?.cancel()
        workItem = nil
    }

    func hapticFeedback() {
#if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #elseif os(iOS)
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()
#endif
    }
}
