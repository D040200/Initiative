import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "bB" asset catalog image resource.
    static let bB = DeveloperToolsSupport.ImageResource(name: "bB", bundle: resourceBundle)

    /// The "bK" asset catalog image resource.
    static let bK = DeveloperToolsSupport.ImageResource(name: "bK", bundle: resourceBundle)

    /// The "bN" asset catalog image resource.
    static let bN = DeveloperToolsSupport.ImageResource(name: "bN", bundle: resourceBundle)

    /// The "bP" asset catalog image resource.
    static let bP = DeveloperToolsSupport.ImageResource(name: "bP", bundle: resourceBundle)

    /// The "bQ" asset catalog image resource.
    static let bQ = DeveloperToolsSupport.ImageResource(name: "bQ", bundle: resourceBundle)

    /// The "bR" asset catalog image resource.
    static let bR = DeveloperToolsSupport.ImageResource(name: "bR", bundle: resourceBundle)

    /// The "wB" asset catalog image resource.
    static let wB = DeveloperToolsSupport.ImageResource(name: "wB", bundle: resourceBundle)

    /// The "wK" asset catalog image resource.
    static let wK = DeveloperToolsSupport.ImageResource(name: "wK", bundle: resourceBundle)

    /// The "wN" asset catalog image resource.
    static let wN = DeveloperToolsSupport.ImageResource(name: "wN", bundle: resourceBundle)

    /// The "wP" asset catalog image resource.
    static let wP = DeveloperToolsSupport.ImageResource(name: "wP", bundle: resourceBundle)

    /// The "wQ" asset catalog image resource.
    static let wQ = DeveloperToolsSupport.ImageResource(name: "wQ", bundle: resourceBundle)

    /// The "wR" asset catalog image resource.
    static let wR = DeveloperToolsSupport.ImageResource(name: "wR", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "bB" asset catalog image.
    static var bB: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bB)
#else
        .init()
#endif
    }

    /// The "bK" asset catalog image.
    static var bK: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bK)
#else
        .init()
#endif
    }

    /// The "bN" asset catalog image.
    static var bN: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bN)
#else
        .init()
#endif
    }

    /// The "bP" asset catalog image.
    static var bP: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bP)
#else
        .init()
#endif
    }

    /// The "bQ" asset catalog image.
    static var bQ: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bQ)
#else
        .init()
#endif
    }

    /// The "bR" asset catalog image.
    static var bR: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bR)
#else
        .init()
#endif
    }

    /// The "wB" asset catalog image.
    static var wB: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .wB)
#else
        .init()
#endif
    }

    /// The "wK" asset catalog image.
    static var wK: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .wK)
#else
        .init()
#endif
    }

    /// The "wN" asset catalog image.
    static var wN: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .wN)
#else
        .init()
#endif
    }

    /// The "wP" asset catalog image.
    static var wP: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .wP)
#else
        .init()
#endif
    }

    /// The "wQ" asset catalog image.
    static var wQ: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .wQ)
#else
        .init()
#endif
    }

    /// The "wR" asset catalog image.
    static var wR: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .wR)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "bB" asset catalog image.
    static var bB: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bB)
#else
        .init()
#endif
    }

    /// The "bK" asset catalog image.
    static var bK: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bK)
#else
        .init()
#endif
    }

    /// The "bN" asset catalog image.
    static var bN: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bN)
#else
        .init()
#endif
    }

    /// The "bP" asset catalog image.
    static var bP: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bP)
#else
        .init()
#endif
    }

    /// The "bQ" asset catalog image.
    static var bQ: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bQ)
#else
        .init()
#endif
    }

    /// The "bR" asset catalog image.
    static var bR: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bR)
#else
        .init()
#endif
    }

    /// The "wB" asset catalog image.
    static var wB: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .wB)
#else
        .init()
#endif
    }

    /// The "wK" asset catalog image.
    static var wK: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .wK)
#else
        .init()
#endif
    }

    /// The "wN" asset catalog image.
    static var wN: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .wN)
#else
        .init()
#endif
    }

    /// The "wP" asset catalog image.
    static var wP: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .wP)
#else
        .init()
#endif
    }

    /// The "wQ" asset catalog image.
    static var wQ: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .wQ)
#else
        .init()
#endif
    }

    /// The "wR" asset catalog image.
    static var wR: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .wR)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

