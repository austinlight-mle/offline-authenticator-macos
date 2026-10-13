import SwiftUI

public struct ToastConfiguration: Equatable {
    public let type: ToastType
    public let duration: TimeInterval
    public let hapticFeedback: Bool
    public let style: ToastDisplayStyle
    
    public init(type: ToastType = .regular, duration: TimeInterval = 2, hapticFeedback: Bool = true, style: ToastDisplayStyle = .default) {
        self.type = type
        self.duration = duration
        self.hapticFeedback = hapticFeedback
        self.style = style
    }
    
    public static var `default`: ToastConfiguration {
        .init()
    }
}

public struct SimpleToast: Equatable, Identifiable {
    
    public let id: String
    
    ///The display mode
    /// - `top`
    /// - `center`
    /// - `bottom`
    let displayMode: DisplayMode

    ///The title of the alert (`Optional(String)`)
    let title: String?

    ///The subtitle of the alert (`Optional(String)`)
    let subTitle: String?

    
    let configuration: ToastConfiguration
    
    var offsetY: CGFloat {
        configuration.style.offsetY
    }

    ///Full init
    public init(id: String = UUID().uuidString,
                displayMode: DisplayMode = .bottom(.pop),
                configuration: ToastConfiguration = .default,
                title: String? = nil,
                subTitle: String? = nil) {
        self.id = id
        self.displayMode = displayMode
        self.title = title
        self.subTitle = subTitle
        self.configuration = configuration
    }

    ///Body init determine by `displayMode`
    @MainActor
    public var body: some View {
        container
            .multilineTextAlignment(.center)
            .padding(16)
            .background(AnyShapeStyle(configuration.style.backgroundColor))
            .clipShape(AnyShape(configuration.style.shape))
            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 1)
    }
}

@MainActor
private extension SimpleToast {
    @ViewBuilder
    var container: some View {
        switch displayMode {
        case .top, .bottom:
            HStack {
                imageDisplay
                textDisplay
            }
        case .center:
            VStack {
                imageDisplay
                textDisplay
            }
        }
    }
    
    @ViewBuilder
    var imageDisplay: some View {
        switch configuration.type {
        case let.complete(color):
            Image(systemName: "checkmark")
                .resizable()
                .scaledToFit()
                .font(configuration.style.titleFont)
                .frame(maxWidth: 20, maxHeight: 20, alignment: .center)
                .foregroundStyle(color)
        case let .error(color):
            Image(systemName: "xmark")
                .resizable()
                .frame(width: 20, height: 20, alignment: .center)
                .scaledToFit()
                .foregroundStyle(color)
        case let .image(image):
            image
        case .loading:
            ProgressView()
        case .regular:
            EmptyView()
        }
    }
    
    var textDisplay: some View {
        VStack(spacing: configuration.type == .regular ? 8 : 2) {
            if let title {
                Text(LocalizedStringKey(title))
                    .font(configuration.style.titleFont)
                    .textColor(configuration.style.titleColor)
            }
            if let subTitle {
                Text(LocalizedStringKey(subTitle))
                    .font(configuration.style.subTitleFont)
                    .opacity(0.7)
                    .textColor(configuration.style.subtitleColor)
            }
        }
    }
}
